import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'recording_writer.dart';

enum FatigueLevel { none, low, medium, high }

enum ExperimentCondition { withAlerts, withoutAlerts }

extension ConditionValue on ExperimentCondition {
  String get databaseValue =>
      this == ExperimentCondition.withAlerts ? 'with_alerts' : 'without_alerts';
}

FatigueLevel classifyFatigue(double value, FatigueConfig config) {
  if (value >= config.thresholdHigh) return FatigueLevel.high;
  if (value >= config.thresholdMedium) return FatigueLevel.medium;
  if (value >= config.thresholdLow) return FatigueLevel.low;
  return FatigueLevel.none;
}

/// Procesamiento puro: el reloj es el timestamp de la medición, también en replay.
class FatigueProcessor {
  FatigueProcessor(this.config, this.condition) {
    config.validate();
  }
  final FatigueConfig config;
  final ExperimentCondition condition;
  final List<double> _window = [];
  FatigueLevel _level = FatigueLevel.none;
  int? _lastAlertUs;

  ProcessingResult process(MeasurementEvent event) {
    _window.add(event.value);
    if (_window.length > config.movingAverageWindow) _window.removeAt(0);
    final smooth = _window.reduce((a, b) => a + b) / _window.length;
    final level = classifyFatigue(smooth, config);
    final previous = _level;
    final elapsed = _lastAlertUs == null
        ? null
        : event.receptionTimestampUs - _lastAlertUs!;
    final eligible =
        level != FatigueLevel.none &&
        (_lastAlertUs == null ||
            level != previous ||
            elapsed! >= config.cooldown.inMicroseconds);
    if (eligible) _lastAlertUs = event.receptionTimestampUs;
    _level = level;
    return ProcessingResult(
      smoothedValue: smooth,
      fatigueLevel: level.name,
      previousLevel: previous.name,
      alertTriggered: eligible,
      alertShown: false,
      suppressionReason: level == FatigueLevel.none
          ? 'below_threshold'
          : !eligible
          ? 'cooldown'
          : condition == ExperimentCondition.withoutAlerts
          ? 'condition_without_alerts'
          : null,
    );
  }
}
