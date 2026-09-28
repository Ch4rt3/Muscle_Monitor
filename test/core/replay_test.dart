import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:muscle_monitoring/core/acquisition/replay_source.dart';
import 'package:muscle_monitoring/core/acquisition/recording_writer.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';

void main() {
  late Directory dir;
  late File file;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('myosafe_replay');
    file = File('${dir.path}/original.jsonl');
    final writer = RecordingWriter(file.path);
    const config = FatigueConfig(cooldown: Duration(milliseconds: 50));
    final processor = FatigueProcessor(config, ExperimentCondition.withAlerts);
    await writer.start(
      config: config,
      source: MeasurementSourceType.simulation,
    );
    for (var i = 0; i < 12; i++) {
      final e = MeasurementEvent(
        channel: 'fatiga',
        value: i < 4 ? 35 : 80,
        receptionTimestampUs: i * 20000,
        sequence: i,
        source: MeasurementSourceType.simulation,
      );
      writer.writeEvent(e, processingResult: processor.process(e));
    }
    await writer.stop();
  });
  tearDown(() => dir.delete(recursive: true));

  test(
    'grabación real → replay 2 veces: mediciones, niveles y cooldown idénticos',
    () async {
      final original = await RecordingReader.parse(file);
      final unchanged = await file.readAsString();
      final source = ReplayMeasurementSource(original);
      for (final speed in [1.0, 4.0]) {
        source.setSpeed(speed);
        final processor = FatigueProcessor(
          original.config,
          ExperimentCondition.withAlerts,
        );
        final result = <RecordingEventLine>[];
        final sub = source.measurements.listen((e) {
          expect(e.source, MeasurementSourceType.replay);
          result.add(
            RecordingEventLine(
              formatVersion: 1,
              event: e,
              processingResult: processor.process(e),
            ),
          );
        });
        await source.start();
        await Future<void>.delayed(Duration.zero);
        expect(compareRecording(original, result)['match'], true);
        expect(result.map((e) => e.event.sequence).toSet().length, 12);
        await sub.cancel();
      }
      await source.dispose();
      expect(await file.readAsString(), unchanged);
    },
  );
  test('intervalos temporales reales, tolerancia 10ms', () async {
    final source = ReplayMeasurementSource(await RecordingReader.parse(file));
    final watch = Stopwatch()..start();
    final times = <int>[];
    final sub = source.measurements.listen(
      (_) => times.add(watch.elapsedMicroseconds),
    );
    await source.start();
    await Future<void>.delayed(Duration.zero);
    for (var i = 1; i < times.length; i++) {
      expect((times[i] - times[i - 1] - 20000).abs(), lessThan(10000));
    }
    await sub.cancel();
    await source.dispose();
  });
  test(
    'pausar, reanudar y detener resuelven la reproducción sin duplicados',
    () async {
      final source = ReplayMeasurementSource(await RecordingReader.parse(file));
      final received = <int>[];
      final sub = source.measurements.listen((e) => received.add(e.sequence));
      final run = source.start();
      await Future<void>.delayed(const Duration(milliseconds: 35));
      await source.pause();
      final pausedAt = received.length;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received.length, pausedAt);
      await source.resume();
      await run.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(received, List.generate(12, (i) => i));
      final run2 = source.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await source.stop();
      await run2.timeout(const Duration(milliseconds: 100));
      await sub.cancel();
      await source.dispose();
    },
  );
  test(
    'archivo truncado recuperable y cabecera corrupta descriptiva',
    () async {
      final lines = await file.readAsLines();
      await file.writeAsString('${lines.take(5).join('\n')}\n{"v":');
      final recovered = await RecordingReader.parse(file);
      expect(recovered.events.length, 4);
      expect(recovered.isComplete, false);
      expect(recovered.warnings, isNotEmpty);
      await file.writeAsString('[]');
      await expectLater(RecordingReader.parse(file), throwsFormatException);
    },
  );
  test(
    'comparación no declara éxito si faltan resultados originales',
    () async {
      final original = await RecordingReader.parse(file);
      final legacy = ParsedRecording(
        header: original.header,
        events: original.events
            .map((e) => RecordingEventLine(formatVersion: 1, event: e.event))
            .toList(),
        footer: original.footer,
        config: original.config,
        isComplete: true,
        warnings: [],
      );
      final report = compareRecording(legacy, original.events);
      expect(report['match'], false);
      expect(report['missing_original_results'], 12);
    },
  );
}
