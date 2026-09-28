import 'dart:async';
import 'dart:io';
import 'package:muscle_monitoring/core/acquisition/recording_writer.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';

Future<void> main(List<String> args) async {
  await AppLogger.instance.initialize('${args[0]}/logs');
  final writer = RecordingWriter('${args[0]}/killed.jsonl');
  await writer.start(
    config: FatigueConfig.defaultConfig,
    source: MeasurementSourceType.simulation,
    metadata: {'session_id': 's1'},
  );
  for (var i = 0; i < 100; i++) {
    writer.writeEvent(
      MeasurementEvent(
        channel: 'fuerza',
        value: i.toDouble(),
        receptionTimestampUs: i * 40000,
        sequence: i,
        source: MeasurementSourceType.simulation,
      ),
    );
  }
  AppLogger.instance.log(
    LogCategory.app,
    LogLevel.error,
    'critical_before_kill',
  );
  stdout.writeln('READY');
  // El padre mata este proceso. No hay cierre ordenado ni footer.
  await Future<void>.delayed(const Duration(minutes: 2));
}
