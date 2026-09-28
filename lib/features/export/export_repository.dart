import 'dart:io';
import 'package:muscle_monitoring/data/experiment_database.dart';

class ExportRepository {
  const ExportRepository(this.database);
  final ExperimentDatabase database;

  /// Exportación experimental: BLE y sesiones completas. Diagnósticos requieren opt-in.
  Future<List<File>> export(
    String directory, {
    bool includeDiagnostics = false,
  }) async {
    await Directory(directory).create(recursive: true);
    final filter = includeDiagnostics
        ? '1=1'
        : "s.source = 'ble' AND s.status = 'completed'";
    final specs = <String, (List<String>, String)>{
      'sessions': (
        [
          'id',
          'participant_id',
          'condition',
          'exercise',
          'started_at_us',
          'ended_at_us',
          'status',
          'device_name',
          'device_tz_offset_s',
          'config_json',
          'source',
          'feedback_policy',
          'expected_count',
          'stored_count',
          'integrity_json',
          'notes',
        ],
        'SELECT s.* FROM sessions s WHERE $filter ORDER BY s.started_at_us',
      ),
      'participants': (
        [
          'id',
          'alias',
          'age_range',
          'experience_level',
          'notes',
          'created_at_us',
        ],
        'SELECT p.* FROM participants p WHERE p.id IN (SELECT s.participant_id FROM sessions s WHERE $filter) ORDER BY p.id',
      ),
      'measurements': (
        [
          'session_id',
          'ordinal',
          'reception_timestamp_us',
          'channel',
          'value',
          'sequence',
          'firmware_sequence',
          'source',
        ],
        'SELECT m.* FROM measurements m JOIN sessions s ON s.id=m.session_id WHERE $filter ORDER BY s.started_at_us,m.ordinal',
      ),
      'alert_events': (
        [
          'session_id',
          'sequence',
          'timestamp_us',
          'level',
          'trigger_value',
          'smoothed_value',
          'previous_level',
          'triggered',
          'was_shown',
          'suppression_reason',
          'condition',
          'was_dismissed_by_user',
          'dismissed_at_us',
          'shown_at_us',
        ],
        'SELECT a.* FROM alert_events a JOIN sessions s ON s.id=a.session_id WHERE $filter ORDER BY s.started_at_us,a.sequence',
      ),
      'session_evals': (
        ['session_id', 'eval_type', 'value', 'timestamp_us', 'notes'],
        'SELECT e.* FROM session_evals e JOIN sessions s ON s.id=e.session_id WHERE $filter ORDER BY s.started_at_us,e.timestamp_us',
      ),
    };
    final files = <File>[];
    for (final entry in specs.entries) {
      final (columns, sql) = entry.value;
      final rows = await database.db.rawQuery(sql);
      final file = File('$directory/${entry.key}.csv');
      final sink = file.openWrite();
      sink.write('\uFEFF');
      sink.writeln(columns.map(csvCell).join(','));
      for (final row in rows) {
        sink.writeln(columns.map((c) => csvCell(row[c])).join(','));
      }
      await sink.flush();
      await sink.close();
      files.add(file);
    }
    return files;
  }

  static String csvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (value is String && RegExp(r'^[=+@\-\t\r]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
