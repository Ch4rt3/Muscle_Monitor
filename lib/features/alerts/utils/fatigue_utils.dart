/// Utilidades para el manejo de alertas de fatiga muscular
/// Basado en estudios de electromiografía con sensor MyoWare 2.0
library;

import 'package:flutter/material.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
export 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart'
    show FatigueLevel;

/// Niveles de fatiga según umbrales fisiológicos

/// Clase que define las características de cada nivel de alerta
class FatigueAlertConfig {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final bool shouldVibrate;
  final bool shouldPlaySound;
  final Duration displayDuration;

  const FatigueAlertConfig({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    this.shouldVibrate = false,
    this.shouldPlaySound = false,
    this.displayDuration = const Duration(seconds: 3),
  });
}

/// Configuraciones predefinidas para cada nivel de fatiga
class FatigueAlertConfigs {
  static const low = FatigueAlertConfig(
    title: 'Fatiga Leve',
    message: 'Nivel de fatiga leve detectado',
    color: AppColors.warning,
    icon: Icons.info_outline,
    displayDuration: Duration(seconds: 3),
  );

  static const medium = FatigueAlertConfig(
    title: 'Fatiga Moderada',
    message: 'Fatiga moderada detectada',
    color: AppColors.warning,
    icon: Icons.warning_amber_outlined,
    shouldVibrate: true,
    displayDuration: Duration(seconds: 4),
  );

  static const high = FatigueAlertConfig(
    title: 'Riesgo de Sobreesfuerzo',
    message: 'Fatiga severa detectada',
    color: AppColors.error,
    icon: Icons.error_outline,
    shouldVibrate: true,
    shouldPlaySound: true,
    displayDuration: Duration(seconds: 5),
  );
}

/// Determina el nivel de fatiga basado en el valor porcentual.
///
/// Si se proporciona [config], usa los umbrales configurados.
/// En caso contrario, usa los valores por defecto (30/50/75).
FatigueLevel getFatigueLevel(double fatigueValue, {FatigueConfig? config}) {
  return classifyFatigue(fatigueValue, config ?? FatigueConfig.defaultConfig);
}

/// Obtiene la configuración de alerta según el nivel de fatiga
FatigueAlertConfig? getAlertConfig(FatigueLevel level) {
  switch (level) {
    case FatigueLevel.low:
      return FatigueAlertConfigs.low;
    case FatigueLevel.medium:
      return FatigueAlertConfigs.medium;
    case FatigueLevel.high:
      return FatigueAlertConfigs.high;
    case FatigueLevel.none:
      return null;
  }
}

/// Conserva el valor recibido hasta validar rango y significado del firmware.
double emgToPercentage(double emgValue) {
  return emgValue;
}

/// Calcula un promedio móvil para suavizar los datos y evitar falsos positivos
class MovingAverage {
  final int windowSize;
  final List<double> _values = [];

  MovingAverage({this.windowSize = 5});

  double add(double value) {
    _values.add(value);
    if (_values.length > windowSize) {
      _values.removeAt(0);
    }
    return average;
  }

  double get average {
    if (_values.isEmpty) return 0;
    return _values.reduce((a, b) => a + b) / _values.length;
  }

  void clear() {
    _values.clear();
  }
}
