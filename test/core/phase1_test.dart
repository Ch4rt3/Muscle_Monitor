import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:muscle_monitoring/core/acquisition/measurement_source.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
import 'package:muscle_monitoring/core/acquisition/simulation_source.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';

MeasurementEvent sample(int seq, {double value = 80}) => MeasurementEvent(
  channel: 'fatiga',
  value: value,
  receptionTimestampUs: seq * 1000000,
  sequence: seq,
  source: MeasurementSourceType.simulation,
);

void main() {
  test('payload inmutable y configuración sin pérdida temporal', () {
    final raw = [10];
    final e = MeasurementEvent(
      channel: 'fuerza',
      value: 10,
      receptionTimestampUs: 0,
      sequence: 0,
      source: MeasurementSourceType.ble,
      rawBytes: raw,
    );
    raw[0] = 50;
    expect(e.rawBytes, [10]);
    expect(() => e.rawBytes![0] = 4, throwsUnsupportedError);
    const config = FatigueConfig(cooldown: Duration(milliseconds: 1250));
    expect(FatigueConfig.fromJson(config.toJson()).cooldown, config.cooldown);
  });
  test(
    'logger 10000 entradas y recuperación tras nuevo proceso lógico',
    () async {
      final dir = await Directory.systemTemp.createTemp('myosafe_logs');
      addTearDown(() => dir.delete(recursive: true));
      AppLogger.resetForTesting(capacity: 100);
      await AppLogger.instance.initialize(dir.path);
      for (var i = 0; i < 10000; i++) {
        AppLogger.instance.log(
          LogCategory.measurement,
          LogLevel.info,
          'evento $i',
        );
      }
      expect(AppLogger.instance.getRecent().length, 100);
      AppLogger.instance.log(LogCategory.app, LogLevel.error, 'fallo crítico');
      AppLogger.resetForTesting();
      await AppLogger.instance.initialize(dir.path);
      expect(
        AppLogger.instance.recoveredEntries.join(),
        contains('fallo crítico'),
      );
    },
  );
  test(
    'registro antes de UI, sin listeners, retrasos y fallo del registro',
    () async {
      final bus = MeasurementBus();
      addTearDown(bus.dispose);
      final durable = <int>[];
      bus.begin(
        source: MeasurementSourceType.simulation,
        config: FatigueConfig.defaultConfig,
        condition: ExperimentCondition.withAlerts,
        persist: (line) {
          durable.add(line.event.sequence);
        },
      );
      for (var i = 0; i < 500; i++) {
        bus.emit(sample(i));
      }
      expect(durable.length, 500);
      expect(bus.totalEmitted, 500);
      bus.end();
      Object? failure;
      bus.onFailure = (e, s) => failure = e;
      bus.begin(
        source: MeasurementSourceType.simulation,
        config: FatigueConfig.defaultConfig,
        condition: ExperimentCondition.withAlerts,
        persist: (_) => throw FileSystemException('disco lleno'),
      );
      bus.emit(sample(0));
      expect(bus.totalEmitted, 0);
      expect(bus.rejected, 1);
      expect(failure, isNotNull);
    },
  );
  test('cooldown usa tiempo grabado y condición solo afecta visibilidad', () {
    final a = FatigueProcessor(
      FatigueConfig.defaultConfig,
      ExperimentCondition.withAlerts,
    );
    final b = FatigueProcessor(
      FatigueConfig.defaultConfig,
      ExperimentCondition.withoutAlerts,
    );
    final results = [for (var i = 0; i <= 5; i++) a.process(sample(i))];
    expect(results.map((r) => r.alertTriggered), [
      true,
      false,
      false,
      false,
      false,
      true,
    ]);
    expect(b.process(sample(0)).suppressionReason, 'condition_without_alerts');
    expect(results.first.alertShown, isFalse);
    expect(results.first.shouldDisplay, isTrue);
    expect(
      classifyFatigue(55, const FatigueConfig(thresholdHigh: 60)),
      FatigueLevel.medium,
    );
  });
  test(
    'simulación real emite una secuencia por canal sin duplicación',
    () async {
      final source = SimulationMeasurementSource(intervalMs: 2, seed: 1);
      addTearDown(source.dispose);
      final events = <MeasurementEvent>[];
      final sub = source.measurements.listen(events.add);
      await source.start();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await source.stop();
      await sub.cancel();
      for (final channel in ['fuerza', 'fatiga']) {
        final entries = events.where((e) => e.channel == channel).toList();
        expect(entries.length, greaterThan(5));
        expect(
          entries.map((e) => e.sequence),
          List.generate(entries.length, (i) => i),
        );
      }
    },
  );
}
