/// Utilidades para el manejo de alertas de fatiga muscular
/// Basado en estudios de electromiografía con sensor MyoWare 2.0
library;

import 'package:flutter/material.dart';

/// Niveles de fatiga según umbrales fisiológicos
enum FatigueLevel {
  none, // < 30%
  low, // 30-49%
  medium, // 50-74%
  high, // >= 75%
}

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
    message: 'Nivel de fatiga detectado (30-49%)',
    color: Color(0xFFFFA726), // Naranja claro/amarillo
    icon: Icons.info_outline,
    displayDuration: Duration(seconds: 3),
  );

  static const medium = FatigueAlertConfig(
    title: 'Fatiga Moderada',
    message: 'Fatiga moderada detectada (50-74%)',
    color: Color(0xFFFF6F00), // Naranja intenso
    icon: Icons.warning_amber_rounded,
    shouldVibrate: true,
    displayDuration: Duration(seconds: 4),
  );

  static const high = FatigueAlertConfig(
    title: '⚠️ Riesgo de Sobreesfuerzo',
    message: 'Fatiga severa detectada (≥75%)',
    color: Color(0xFFD32F2F), // Rojo
    icon: Icons.error_outline,
    shouldVibrate: true,
    shouldPlaySound: true,
    displayDuration: Duration(seconds: 5),
  );
}

/// Determina el nivel de fatiga basado en el valor porcentual
FatigueLevel getFatigueLevel(double fatigueValue) {
  if (fatigueValue >= 75) {
    return FatigueLevel.high;
  } else if (fatigueValue >= 50) {
    return FatigueLevel.medium;
  } else if (fatigueValue >= 30) {
    return FatigueLevel.low;
  } else {
    return FatigueLevel.none;
  }
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

/// Convierte el valor EMG (0-255) a porcentaje (0-100)
double emgToPercentage(double emgValue) {
  // El MyoWare 2.0 con ESP32 típicamente envía valores de 0-255
  return (emgValue / 255) * 100;
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
