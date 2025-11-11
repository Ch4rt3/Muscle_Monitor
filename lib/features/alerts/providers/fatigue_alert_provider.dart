/// Provider para el manejo de alertas de fatiga muscular
/// Se suscribe al stream de datos BLE y evalúa los niveles de fatiga
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/features/alerts/models/alert_state.dart';
import 'package:muscle_monitoring/features/alerts/utils/fatigue_utils.dart';
import 'package:muscle_monitoring/presentation/providers/ble_provider.dart';

/// Provider que escucha los datos de fatiga y genera alertas
class FatigueAlertNotifier extends StateNotifier<FatigueAlertState> {
  final Ref ref;
  final MovingAverage _movingAverage = MovingAverage(
    windowSize: 3,
  ); // Reducido de 5 a 3 para mayor sensibilidad

  FatigueAlertNotifier(this.ref) : super(const FatigueAlertState()) {
    // Suscribirse a los cambios en los datos BLE
    _listenToFatigueData();
  }

  /// Escucha los cambios en los datos de fatiga del provider BLE
  void _listenToFatigueData() {
    ref.listen<BleState>(bleProvider, (previous, next) {
      // Solo procesar si hay datos de fatiga
      if (next.dataFatiga.isEmpty) return;

      // Obtener el último valor de fatiga
      final latestDataPoint = next.dataFatiga.last;
      final rawValue = latestDataPoint.y;

      // Convertir a porcentaje (0-100)
      final percentage = emgToPercentage(rawValue);

      // Aplicar promedio móvil para suavizar y evitar falsos positivos
      final smoothedValue = _movingAverage.add(percentage);

      // Determinar el nivel de fatiga
      final newLevel = getFatigueLevel(smoothedValue);

      // Actualizar el estado
      _updateAlertState(newLevel, smoothedValue);
    });
  }

  /// Actualiza el estado de la alerta según el nuevo nivel detectado
  void _updateAlertState(FatigueLevel newLevel, double value) {
    final shouldShow = state.shouldShowAlert(newLevel);

    if (shouldShow && newLevel != FatigueLevel.none) {
      // Activar alerta
      state = state.copyWith(
        currentLevel: newLevel,
        currentValue: value,
        isAlertActive: true,
        lastAlertTime: DateTime.now(),
        lastAlertLevel: newLevel,
      );
    } else if (newLevel == FatigueLevel.none) {
      // Desactivar alerta cuando el nivel vuelve a normal
      state = state.copyWith(
        currentLevel: FatigueLevel.none,
        currentValue: value,
        isAlertActive: false,
      );
    } else {
      // Actualizar valor sin cambiar el estado de alerta
      state = state.copyWith(currentLevel: newLevel, currentValue: value);
    }
  }

  /// Cierra manualmente una alerta activa
  void dismissAlert() {
    state = state.copyWith(isAlertActive: false);
  }

  /// Resetea el sistema de alertas
  void reset() {
    _movingAverage.clear();
    state = const FatigueAlertState();
  }

  @override
  void dispose() {
    _movingAverage.clear();
    super.dispose();
  }
}

/// Provider principal de alertas de fatiga
final fatigueAlertProvider =
    StateNotifierProvider<FatigueAlertNotifier, FatigueAlertState>((ref) {
      return FatigueAlertNotifier(ref);
    });

/// Provider de solo lectura para saber si hay una alerta activa
final hasActiveAlertProvider = Provider<bool>((ref) {
  return ref.watch(fatigueAlertProvider).isAlertActive;
});

/// Provider de solo lectura para obtener el nivel actual de fatiga
final currentFatigueLevelProvider = Provider<FatigueLevel>((ref) {
  return ref.watch(fatigueAlertProvider).currentLevel;
});
