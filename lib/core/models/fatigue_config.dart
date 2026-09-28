/// Configuración centralizada de umbrales y procesamiento de fatiga.
///
/// Fuente única de verdad para los parámetros que determinan los niveles
/// de fatiga, el suavizado y el cooldown de alertas. Todos los módulos
/// (procesador, UI, grabación) leen de una instancia de [FatigueConfig],
/// nunca de constantes dispersas.
///
/// La configuración se serializa en `sessions.config_json` al iniciar
/// sesión y no puede modificarse durante la sesión activa.
library;

class FatigueConfig {
  /// Valor a partir del cual se considera fatiga leve (inclusive).
  final double thresholdLow;

  /// Valor a partir del cual se considera fatiga moderada (inclusive).
  final double thresholdMedium;

  /// Valor a partir del cual se considera fatiga severa (inclusive).
  final double thresholdHigh;

  /// Tamaño de la ventana del promedio móvil para suavizar señales.
  final int movingAverageWindow;

  /// Duración mínima entre alertas del mismo nivel.
  final Duration cooldown;

  /// Identificador de versión del algoritmo de procesamiento.
  /// Se guarda junto con los datos para reproducibilidad.
  final String algorithmVersion;

  const FatigueConfig({
    this.thresholdLow = 30.0,
    this.thresholdMedium = 50.0,
    this.thresholdHigh = 75.0,
    this.movingAverageWindow = 3,
    this.cooldown = const Duration(seconds: 5),
    this.algorithmVersion = '1.0.0',
  });

  /// Configuración por defecto utilizada cuando no se especifica otra.
  static const FatigueConfig defaultConfig = FatigueConfig();

  void validate() {
    if (!thresholdLow.isFinite ||
        !thresholdMedium.isFinite ||
        !thresholdHigh.isFinite ||
        thresholdLow < 0 ||
        thresholdLow >= thresholdMedium ||
        thresholdMedium >= thresholdHigh ||
        movingAverageWindow < 1 ||
        cooldown.isNegative) {
      throw ArgumentError('Configuración de fatiga inválida');
    }
  }

  Map<String, dynamic> toJson() => {
    'threshold_low': thresholdLow,
    'threshold_medium': thresholdMedium,
    'threshold_high': thresholdHigh,
    'moving_average_window': movingAverageWindow,
    'cooldown_seconds': cooldown.inSeconds,
    'cooldown_us': cooldown.inMicroseconds,
    'algorithm_version': algorithmVersion,
  };

  factory FatigueConfig.fromJson(Map<String, dynamic> json) {
    return FatigueConfig(
      thresholdLow: (json['threshold_low'] as num?)?.toDouble() ?? 30.0,
      thresholdMedium: (json['threshold_medium'] as num?)?.toDouble() ?? 50.0,
      thresholdHigh: (json['threshold_high'] as num?)?.toDouble() ?? 75.0,
      movingAverageWindow: json['moving_average_window'] as int? ?? 3,
      cooldown: Duration(
        microseconds:
            json['cooldown_us'] as int? ??
            (json['cooldown_seconds'] as int? ?? 5) * 1000000,
      ),
      algorithmVersion: json['algorithm_version'] as String? ?? '1.0.0',
    );
  }

  @override
  String toString() =>
      'FatigueConfig(low=$thresholdLow, med=$thresholdMedium, '
      'high=$thresholdHigh, maW=$movingAverageWindow, '
      'cd=${cooldown.inSeconds}s, v$algorithmVersion)';
}
