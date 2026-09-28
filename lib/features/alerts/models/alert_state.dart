/// Modelo de estado para las alertas de fatiga
library;

import 'package:muscle_monitoring/features/alerts/utils/fatigue_utils.dart';

/// Estado de una alerta de fatiga
class FatigueAlertState {
  final FatigueLevel currentLevel;
  final double currentValue;
  final bool isAlertActive;
  final DateTime? lastAlertTime;
  final FatigueLevel? lastAlertLevel;
  final int? alertSequence;

  const FatigueAlertState({
    this.currentLevel = FatigueLevel.none,
    this.currentValue = 0.0,
    this.isAlertActive = false,
    this.lastAlertTime,
    this.lastAlertLevel,
    this.alertSequence,
  });

  FatigueAlertState copyWith({
    FatigueLevel? currentLevel,
    double? currentValue,
    bool? isAlertActive,
    DateTime? lastAlertTime,
    FatigueLevel? lastAlertLevel,
    int? alertSequence,
  }) {
    return FatigueAlertState(
      currentLevel: currentLevel ?? this.currentLevel,
      currentValue: currentValue ?? this.currentValue,
      isAlertActive: isAlertActive ?? this.isAlertActive,
      lastAlertTime: lastAlertTime ?? this.lastAlertTime,
      lastAlertLevel: lastAlertLevel ?? this.lastAlertLevel,
      alertSequence: alertSequence ?? this.alertSequence,
    );
  }

  @override
  String toString() {
    return 'FatigueAlertState(level: $currentLevel, value: ${currentValue.toStringAsFixed(1)}%, active: $isAlertActive)';
  }
}
