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

  const FatigueAlertState({
    this.currentLevel = FatigueLevel.none,
    this.currentValue = 0.0,
    this.isAlertActive = false,
    this.lastAlertTime,
    this.lastAlertLevel,
  });

  FatigueAlertState copyWith({
    FatigueLevel? currentLevel,
    double? currentValue,
    bool? isAlertActive,
    DateTime? lastAlertTime,
    FatigueLevel? lastAlertLevel,
  }) {
    return FatigueAlertState(
      currentLevel: currentLevel ?? this.currentLevel,
      currentValue: currentValue ?? this.currentValue,
      isAlertActive: isAlertActive ?? this.isAlertActive,
      lastAlertTime: lastAlertTime ?? this.lastAlertTime,
      lastAlertLevel: lastAlertLevel ?? this.lastAlertLevel,
    );
  }

  /// Verifica si debe mostrar una nueva alerta
  /// Aplica cooldown de 5 segundos para evitar spam
  bool shouldShowAlert(FatigueLevel newLevel) {
    // No mostrar si el nivel es none
    if (newLevel == FatigueLevel.none) return false;

    // Si no hay alerta activa, mostrar
    if (!isAlertActive) return true;

    // Si el nivel es diferente al actual, mostrar
    if (newLevel != currentLevel) return true;

    // Aplicar cooldown de 5 segundos
    if (lastAlertTime != null) {
      final elapsed = DateTime.now().difference(lastAlertTime!);
      if (elapsed.inSeconds < 5) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() {
    return 'FatigueAlertState(level: $currentLevel, value: ${currentValue.toStringAsFixed(1)}%, active: $isAlertActive)';
  }
}
