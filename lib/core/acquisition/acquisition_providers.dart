import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'measurement_source.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';

final measurementBusProvider = Provider<MeasurementBus>((ref) {
  final bus = MeasurementBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final fatigueConfigProvider = Provider<FatigueConfig>(
  (ref) => FatigueConfig.defaultConfig,
);
