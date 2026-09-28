import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:muscle_monitoring/data/experiment_database.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/features/session/session_recorder.dart';
import 'package:muscle_monitoring/features/export/export_repository.dart';
import 'package:muscle_monitoring/core/acquisition/measurement_source.dart';
import 'package:muscle_monitoring/core/acquisition/ble_measurement_source.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';

class ManualSource implements MeasurementSource {
  final controller = StreamController<MeasurementEvent>.broadcast();
  @override
  MeasurementSourceStatus status = MeasurementSourceStatus.idle;
  @override
  Stream<MeasurementEvent> get measurements => controller.stream;
  @override
  Future<void> start() async {
    status = MeasurementSourceStatus.running;
  }

  @override
  Future<void> stop() async {
    status = MeasurementSourceStatus.stopped;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await controller.close();
  }

  void emit(
    int sequence, {
    MeasurementSourceType type = MeasurementSourceType.simulation,
  }) {
    controller.add(
      MeasurementEvent(
        channel: 'fatiga',
        value: 80,
        receptionTimestampUs: sequence * 2000,
        sequence: sequence,
        source: type,
      ),
    );
  }
}

void main() {
  late Directory dir;
  late ExperimentDatabase db;
  late ProviderContainer container;
  late SessionController session;
  late ManualSource source;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('myosafe_flow');
    db = await ExperimentDatabase.open(
      '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    await db.addParticipant('P01', alias: 'Álex, "A"');
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(AppServices(dir.path, db, [])),
      ],
    );
    session = container.read(sessionProvider.notifier);
    source = ManualSource();
  });
  tearDown(() async {
    await session.stop();
    container.dispose();
    await source.dispose();
    await db.db.close();
    await dir.delete(recursive: true);
  });
  Future<void> start({
    MeasurementSourceType type = MeasurementSourceType.simulation,
    ExperimentCondition condition = ExperimentCondition.withAlerts,
  }) => session.start(
    participant: 'P01',
    exercise: 'Prueba',
    input: source,
    type: type,
    condition: condition,
    feedbackPolicy: FeedbackPolicy.keepChart,
  );

  test(
    'flujo integrado: decisiones originales, entrega, cierre, replay y comparación',
    () async {
      await start();
      source.emit(0);
      source.emit(1);
      source.emit(2);
      await Future<void>.delayed(Duration.zero);
      session.recordDelivery(0, shown: true);
      session.recordDelivery(0, shown: true, dismissed: true);
      await session.stop();
      expect(container.read(sessionProvider).report?['ok'], true);
      final alert = (await db.db.query(
        'alert_events',
        where: 'sequence=0',
      )).single;
      expect(alert['was_shown'], 1);
      expect(alert['was_dismissed_by_user'], 1);
      final original = File(
        (await db.sessions()).single['recording_path'] as String,
      );
      await session.startReplay(original);
      for (var i = 0; i < 200 && container.read(sessionProvider).active; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final state = container.read(sessionProvider);
      expect(state.active, false);
      expect(state.error, isNull);
      expect((state.report?['comparison'] as Map?)?['match'], true);
      expect((await db.sessions()).length, 2);
    },
  );
  test(
    'exportación por defecto excluye simulación y replay; CSV preserva texto',
    () async {
      await start();
      source.emit(0);
      await Future<void>.delayed(Duration.zero);
      await session.stop();
      var files = await ExportRepository(
        db,
      ).export('${dir.path}/export_default');
      expect(
        (await files
                .firstWhere((f) => f.path.endsWith('/measurements.csv'))
                .readAsLines())
            .length,
        1,
      );
      source = ManualSource();
      await start(type: MeasurementSourceType.ble);
      source.emit(0, type: MeasurementSourceType.ble);
      await Future<void>.delayed(Duration.zero);
      await session.stop();
      files = await ExportRepository(db).export('${dir.path}/export_ble');
      expect(
        (await files
                .firstWhere((f) => f.path.endsWith('/measurements.csv'))
                .readAsLines())
            .length,
        2,
      );
      expect(
        await files
            .firstWhere((f) => f.path.endsWith('/participants.csv'))
            .readAsString(),
        contains('Álex, ""A""'),
      );
      final diagnostic = await ExportRepository(
        db,
      ).export('${dir.path}/all', includeDiagnostics: true);
      expect(
        (await diagnostic
                .firstWhere((f) => f.path.endsWith('/measurements.csv'))
                .readAsLines())
            .length,
        3,
      );
    },
  );
  test('desconexión interrumpe y conserva las mediciones anteriores', () async {
    await start();
    source.emit(0);
    await Future<void>.delayed(Duration.zero);
    source.controller.addError(StateError('desconectado'), StackTrace.current);
    for (var i = 0; i < 100 && container.read(sessionProvider).active; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect((await db.sessions()).single['status'], 'interrupted');
    expect((await db.db.query('measurements')).length, 1);
  });
  test('fallo al guardar entrega durante cierre queda recuperable', () async {
    await start();
    source.emit(0);
    await Future<void>.delayed(Duration.zero);
    await db.db.execute('''CREATE TRIGGER fail_delivery
      BEFORE UPDATE OF was_shown ON alert_events
      BEGIN SELECT RAISE(FAIL, 'delivery unavailable'); END''');
    session.recordDelivery(0, shown: true);
    await session.stop();
    expect(container.read(sessionProvider).error, contains('recuperará'));
    expect((await db.sessions()).single['status'], 'active');
    await db.db.execute('DROP TRIGGER fail_delivery');
    final recovery = await SessionRecorder.recover(db);
    expect(recovery.single['ok'], true);
    expect((await db.sessions()).single['status'], 'interrupted');
    expect((await db.db.query('alert_events')).single['was_shown'], 1);
  });
  test('validación de payload BLE y decisión metodológica pendiente', () async {
    expect(BleMeasurementSource.decode([255]), 255);
    expect(() => BleMeasurementSource.decode([]), throwsFormatException);
    expect(() => BleMeasurementSource.decode([1, 2]), throwsFormatException);
    expect(() => BleMeasurementSource.decode([-1]), throwsFormatException);
    await expectLater(
      session.start(
        participant: 'P01',
        exercise: 'prueba',
        input: source,
        type: MeasurementSourceType.ble,
        condition: ExperimentCondition.withoutAlerts,
        feedbackPolicy: FeedbackPolicy.pending,
      ),
      throwsStateError,
    );
    expect(await db.sessions(), isEmpty);
  });
}
