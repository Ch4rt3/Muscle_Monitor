import 'dart:io';
import 'dart:convert';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:muscle_monitoring/data/experiment_database.dart';
import 'package:muscle_monitoring/features/session/session_recorder.dart';
import 'package:muscle_monitoring/core/acquisition/recording_writer.dart';
import 'package:muscle_monitoring/core/acquisition/measurement_source.dart';
import 'package:muscle_monitoring/core/acquisition/simulation_source.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';

void main() {
  late Directory dir;
  late ExperimentDatabase database;
  late RecordingWriter writer;
  late SessionRecorder recorder;
  late MeasurementBus bus;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('myosafe_db');
    database = await ExperimentDatabase.open(
      '${dir.path}/test.db',
      factory: databaseFactoryFfi,
    );
    await database.addParticipant('P01');
    writer = RecordingWriter('${dir.path}/session.jsonl');
    await database.createSession({
      'id': 's1',
      'participant_id': 'P01',
      'condition': 'without_alerts',
      'exercise': 'test',
      'started_at_us': 1,
      'device_tz_offset_s': -18000,
      'config_json': jsonEncode(FatigueConfig.defaultConfig.toJson()),
      'source': 'simulation',
      'recording_path': writer.filePath,
      'feedback_policy': 'pending',
    });
    await writer.start(
      config: FatigueConfig.defaultConfig,
      source: MeasurementSourceType.simulation,
      metadata: {'session_id': 's1'},
    );
    recorder = SessionRecorder(
      database: database,
      sessionId: 's1',
      condition: 'without_alerts',
      writer: writer,
    );
    bus = MeasurementBus();
    bus.begin(
      source: MeasurementSourceType.simulation,
      config: FatigueConfig.defaultConfig,
      condition: ExperimentCondition.withoutAlerts,
      persist: recorder.accept,
    );
  });
  tearDown(() async {
    bus.dispose();
    await writer.stop();
    await database.db.close();
    await dir.delete(recursive: true);
  });
  MeasurementEvent event(int n) => MeasurementEvent(
    channel: 'fatiga',
    value: 80,
    receptionTimestampUs: n * 40000,
    sequence: n,
    source: MeasurementSourceType.simulation,
  );

  test('SQLite WAL, FK, unicidad y valores de configuración', () async {
    expect(
      (await database.db.rawQuery('PRAGMA foreign_keys')).first.values.first,
      1,
    );
    expect(
      (await database.db.rawQuery('PRAGMA journal_mode')).first.values.first,
      'wal',
    );
    await expectLater(
      database.db.insert('session_evals', {
        'session_id': 'missing',
        'eval_type': 'rpe',
        'value': 5,
        'timestamp_us': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
    bus.emit(event(0));
    await recorder.flush();
    final stored = await database.db.query('alert_events');
    expect(stored.single['was_shown'], 0);
    expect(stored.single['suppression_reason'], 'condition_without_alerts');
    expect(
      (await database.sessions()).single['config_json'],
      jsonEncode(FatigueConfig.defaultConfig.toJson()),
    );
  });
  test(
    'reintento después del commit no duplica mediciones ni alertas',
    () async {
      bus.end();
      var attempts = 0;
      recorder = SessionRecorder(
        database: database,
        sessionId: 's1',
        condition: 'without_alerts',
        writer: writer,
        writeBatch: (rows) async {
          await database.writeBatch('s1', 'without_alerts', rows);
          if (attempts++ == 0) {
            throw const FileSystemException('confirmación perdida');
          }
        },
      );
      bus.begin(
        source: MeasurementSourceType.simulation,
        config: FatigueConfig.defaultConfig,
        condition: ExperimentCondition.withoutAlerts,
        persist: recorder.accept,
      );
      for (var i = 0; i < 50; i++) {
        bus.emit(event(i));
      }
      await recorder.flush();
      expect(recorder.retries, 1);
      expect((await database.db.query('measurements')).length, 50);
      expect((await database.db.query('alert_events')).length, 50);
      expect(recorder.pending, 0);
      expect((await recorder.finish('completed'))['ok'], true);
    },
  );
  test(
    'eventos recibidos durante escritura permanecen hasta confirmarse',
    () async {
      bus.end();
      var first = true;
      recorder = SessionRecorder(
        database: database,
        sessionId: 's1',
        condition: 'without_alerts',
        writer: writer,
        writeBatch: (rows) async {
          if (first) {
            first = false;
            bus.emit(event(1));
          }
          await database.writeBatch('s1', 'without_alerts', rows);
        },
      );
      bus.begin(
        source: MeasurementSourceType.simulation,
        config: FatigueConfig.defaultConfig,
        condition: ExperimentCondition.withoutAlerts,
        persist: recorder.accept,
      );
      bus.emit(event(0));
      await recorder.flush();
      expect(recorder.persisted, 2);
      expect((await recorder.finish('completed'))['ok'], true);
    },
  );
  test(
    'tres fallos de SQLite conservan el lote y permiten recuperarlo',
    () async {
      bus.end();
      var attempts = 0;
      recorder = SessionRecorder(
        database: database,
        sessionId: 's1',
        condition: 'without_alerts',
        writer: writer,
        writeBatch: (_) async {
          attempts++;
          throw const FileSystemException('almacenamiento no disponible');
        },
      );
      bus.begin(
        source: MeasurementSourceType.simulation,
        config: FatigueConfig.defaultConfig,
        condition: ExperimentCondition.withoutAlerts,
        persist: recorder.accept,
      );
      bus.emit(event(0));
      await expectLater(recorder.flush(), throwsA(isA<FileSystemException>()));
      expect(attempts, 3);
      expect(recorder.pending, 1);
      expect(recorder.persisted, 0);
      expect(await database.db.query('measurements'), isEmpty);
      await writer.abort();
      expect((await SessionRecorder.recover(database)).single['ok'], true);
      expect((await database.db.query('measurements')).length, 1);
    },
  );
  test(
    'reinicio recupera journal no volcado a SQLite y marca interrupción',
    () async {
      for (var i = 0; i < 40; i++) {
        bus.emit(event(i));
      }
      // Recuperación mientras el fichero carece de footer: cada evento ya fue fsync.
      final reports = await SessionRecorder.recover(database);
      expect(reports.single['ok'], true);
      expect((await database.db.query('measurements')).length, 40);
      expect((await database.sessions()).single['status'], 'interrupted');
      expect(await SessionRecorder.recover(database), isEmpty);
    },
  );
  test('conflicto de contenido con misma identidad revierte el lote', () async {
    bus.emit(event(0));
    await recorder.flush();
    final conflicting = StoredMeasurement(
      0,
      RecordingEventLine(
        formatVersion: 1,
        event: MeasurementEvent(
          channel: 'fatiga',
          value: 999,
          receptionTimestampUs: 0,
          sequence: 0,
          source: MeasurementSourceType.simulation,
        ),
      ),
    );
    await expectLater(
      database.writeBatch('s1', 'without_alerts', [conflicting]),
      throwsStateError,
    );
    expect((await database.db.query('measurements')).single['value'], 80);
  });
  test('batch de 50 mediciones e integridad de contenido', () async {
    for (var i = 0; i < 50; i++) {
      bus.emit(event(i));
    }
    await recorder.flush();
    expect(database.lastBatchMs, lessThan(50));
    // Métrica de aceptación del plan; la prueba móvil sigue pendiente.
    printOnFailure('Batch SQLite de 50: ${database.lastBatchMs} ms');
    final report = await recorder.finish('completed');
    expect(report['expected'], 50);
    expect(report['expected_sha256'], report['stored_sha256']);
  });
  test(
    'SIGKILL real: recuperación de mediciones y error crítico al reiniciar',
    () async {
      final killedPath = '${dir.path}/killed.jsonl';
      await database.db.update(
        'sessions',
        {'recording_path': killedPath},
        where: 'id = ?',
        whereArgs: ['s1'],
      );
      final child = await Process.start('dart', [
        '--packages=.dart_tool/package_config.json',
        'test/fixtures/crash_writer.dart',
        dir.path,
      ]);
      final stderrFuture = child.stderr.transform(utf8.decoder).join();
      try {
        await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((line) => line == 'READY')
            .timeout(const Duration(seconds: 15));
        expect(child.kill(ProcessSignal.sigkill), true);
        expect(await child.exitCode, isNot(0));
      } finally {
        child.kill();
      }
      expect(await stderrFuture, isEmpty);
      final reports = await SessionRecorder.recover(database);
      expect(reports.single['ok'], true);
      expect(reports.single['stored'], 100);
      AppLogger.resetForTesting();
      await AppLogger.instance.initialize('${dir.path}/logs');
      expect(
        AppLogger.instance.recoveredEntries.join(),
        contains('critical_before_kill'),
      );
      AppLogger.resetForTesting();
    },
  );
  test(
    '60 segundos reales: fuente → bus → journal → SQLite',
    () async {
      final source = SimulationMeasurementSource(seed: 7);
      final subscription = source.measurements.listen(bus.emit);
      await source.start();
      for (var second = 0; second < 60; second++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await recorder.flush();
      }
      await source.stop();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      final emitted = source.sequenceFuerza + source.sequenceFatiga;
      expect(bus.totalEmitted, emitted);
      expect(bus.rejected, 0);
      final report = await recorder.finish('completed');
      expect(report['ok'], true);
      expect(report['stored'], emitted);
      expect(emitted, greaterThan(2500));
      await source.dispose();
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
