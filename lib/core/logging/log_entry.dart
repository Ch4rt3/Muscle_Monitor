/// Entrada de log estructurada y niveles/categorías del sistema de
/// diagnóstico.
library;

/// Categorías de diagnóstico. Cada categoría puede tener un nivel
/// mínimo independiente.
enum LogCategory { ble, measurement, fatigue, sqlite, session, app }

/// Niveles de severidad, ordenados de más a menos detallado.
enum LogLevel { debug, info, warning, error }

/// Entrada individual del log.
class LogEntry {
  final int timestampUs;
  final LogCategory category;
  final LogLevel level;
  final String message;

  /// Datos estructurados adicionales (valores, contadores, etc.)
  /// para análisis programático. Nunca debe contener datos personales
  /// de los participantes.
  final Map<String, dynamic>? data;
  final String? error;
  final String? stackTrace;

  const LogEntry({
    required this.timestampUs,
    required this.category,
    required this.level,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    't': timestampUs,
    'cat': category.name,
    'lvl': level.name,
    'msg': message,
    if (data != null) 'data': data,
    if (error != null) 'err': error,
    if (stackTrace != null) 'st': stackTrace,
  };
}
