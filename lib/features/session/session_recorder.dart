import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:muscle_monitoring/core/acquisition/recording_writer.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/data/experiment_database.dart';

typedef BatchWriter = Future<void> Function(List<StoredMeasurement> rows);

class SessionRecorder {
  SessionRecorder({
    required this.database,
    required this.sessionId,
    required this.condition,
    required this.writer,
    BatchWriter? writeBatch,
  }) : _writeBatch =
           writeBatch ??
           ((rows) => database.writeBatch(sessionId, condition, rows));
  final ExperimentDatabase database;
  final String sessionId;
  final String condition;
  final RecordingWriter writer;
  final BatchWriter _writeBatch;
  final List<StoredMeasurement> _pending = [];
  Future<void>? _flushing;
  int accepted = 0;
  int persisted = 0;
  int retries = 0;
  String? lastError;
  int get pending => _pending.length;
  static const maxPending = 10000;

  void accept(RecordingEventLine line) {
    if (_pending.length >= maxPending) {
      throw StateError('SQLite no responde: buffer completo');
    }
    writer.writeEvent(line.event, processingResult: line.processingResult);
    _pending.add(StoredMeasurement(accepted++, line));
  }

  Future<void> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<void> _flush() async {
    while (_pending.isNotEmpty) {
      final batch = List<StoredMeasurement>.of(_pending.take(100));
      for (var attempt = 0; ; attempt++) {
        try {
          await _writeBatch(batch);
          lastError = null;
          break;
        } catch (error, stack) {
          lastError = error.toString();
          AppLogger.instance.log(
            LogCategory.sqlite,
            LogLevel.error,
            'Batch write failed',
            error: error.toString(),
            stackTrace: stack.toString(),
            data: {
              'session': sessionId,
              'attempt': attempt + 1,
              'pending': pending,
            },
          );
          if (attempt == 2) rethrow;
          retries++;
          await Future<void>.delayed(
            Duration(milliseconds: 20 * (attempt + 1)),
          );
        }
      }
      // Se confirma exactamente el prefijo escrito, nunca eventos llegados durante await.
      _pending.removeRange(0, batch.length);
      persisted += batch.length;
      AppLogger.instance.log(
        LogCategory.sqlite,
        LogLevel.info,
        'Batch committed',
        data: {
          'count': batch.length,
          'duration_ms': database.lastBatchMs,
          'pending': pending,
        },
      );
    }
  }

  Future<void> delivery(
    int sequence, {
    required bool shown,
    String? reason,
    bool dismissed = false,
  }) async {
    final record = <String, dynamic>{
      'type': dismissed ? 'dismissal' : 'delivery',
      'seq': sequence,
      'shown': shown,
      'reason': reason,
      'at': DateTime.now().microsecondsSinceEpoch,
    };
    writer.writeRecord(record);
    await flush();
    await database.delivery(sessionId, record);
  }

  Future<Map<String, dynamic>> finish(String status) async {
    await flush();
    await writer.stop(status: status);
    final recovered = await readJournal(File(writer.filePath));
    final report = await database.integrity(sessionId, recovered.rows);
    report['journal_warnings'] = recovered.warnings;
    report['ok'] =
        report['ok'] == true &&
        recovered.warnings.isEmpty &&
        accepted == recovered.rows.length;
    await database.finish(
      sessionId,
      report['ok'] == true ? status : 'interrupted',
      report,
    );
    return report;
  }

  static Future<JournalData> readJournal(File file) async {
    final rows = <StoredMeasurement>[];
    final deliveries = <Map<String, dynamic>>[];
    final warnings = <String>[];
    if (!await file.exists()) {
      return JournalData(rows, deliveries, ['Registro no encontrado']);
    }
    final lines = await file.readAsLines();
    if (lines.isEmpty) return JournalData(rows, deliveries, ['Registro vacío']);
    try {
      final header = jsonDecode(lines.first) as Map<String, dynamic>;
      if (header['type'] != 'header' || header['format_version'] != 1) {
        return JournalData(rows, deliveries, ['Cabecera incompatible']);
      }
    } catch (error) {
      return JournalData(rows, deliveries, ['Cabecera inválida: $error']);
    }
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      try {
        final json = jsonDecode(lines[i]) as Map<String, dynamic>;
        if (json['type'] == 'delivery' || json['type'] == 'dismissal') {
          deliveries.add(json);
        } else if (json['type'] != 'footer') {
          rows.add(
            StoredMeasurement(rows.length, RecordingEventLine.fromJson(json)),
          );
        }
      } catch (e) {
        warnings.add('Línea ${i + 1}: $e');
      }
    }
    return JournalData(rows, deliveries, warnings);
  }

  static Future<List<Map<String, dynamic>>> recover(
    ExperimentDatabase database,
  ) async {
    final sessions = await database.db.query(
      'sessions',
      where: "status = 'active'",
    );
    final reports = <Map<String, dynamic>>[];
    for (final session in sessions) {
      final id = session['id'] as String;
      try {
        final journal = await readJournal(
          File(session['recording_path'] as String),
        );
        for (var start = 0; start < journal.rows.length; start += 100) {
          await database.writeBatch(
            id,
            session['condition'] as String,
            journal.rows.skip(start).take(100).toList(),
          );
        }
        for (final delivery in journal.deliveries) {
          await database.delivery(id, delivery);
        }
        final report = await database.integrity(id, journal.rows);
        report['journal_warnings'] = journal.warnings;
        report['ok'] = report['ok'] == true && journal.warnings.isEmpty;
        await database.finish(id, 'interrupted', report);
        reports.add({'session': id, ...report});
      } catch (error, stack) {
        // Mantener active permite otro intento, sin etiquetar recuperación fallida como exitosa.
        AppLogger.instance.log(
          LogCategory.session,
          LogLevel.error,
          'Recovery failed',
          error: error.toString(),
          stackTrace: stack.toString(),
          data: {'session': id},
        );
        reports.add({'session': id, 'ok': false, 'error': error.toString()});
      }
    }
    return reports;
  }
}

class JournalData {
  const JournalData(this.rows, this.deliveries, this.warnings);
  final List<StoredMeasurement> rows;
  final List<Map<String, dynamic>> deliveries;
  final List<String> warnings;
}
