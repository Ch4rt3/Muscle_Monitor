/// Logger centralizado con ring buffer en memoria.
///
/// Diseñado para no bloquear la recepción BLE: [log] es O(1).
/// En nivel INFO no registra cada medición individual; en DEBUG sí.
/// La exportación a archivo es asíncrona y no interfiere con la
/// adquisición.
library;

import 'dart:convert';
import 'dart:io';

import 'package:muscle_monitoring/core/logging/log_entry.dart';

/// Buffer circular de tamaño fijo. Cuando está lleno, descarta la
/// entrada más antigua.
class RingBuffer<T> {
  final List<T?> _buffer;
  int _head = 0;
  int _count = 0;

  RingBuffer(int capacity) : _buffer = List<T?>.filled(capacity, null);

  int get capacity => _buffer.length;
  int get length => _count;
  bool get isEmpty => _count == 0;

  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
  }

  /// Retorna las entradas en orden cronológico (más antigua primero).
  List<T> toList() {
    if (_count < capacity) {
      return _buffer.sublist(0, _count).cast<T>();
    }
    // El buffer está lleno: head apunta al slot que se sobrescribirá
    // primero, que es el más antiguo.
    return [
      ..._buffer.sublist(_head, capacity).cast<T>(),
      ..._buffer.sublist(0, _head).cast<T>(),
    ];
  }

  void clear() {
    _buffer.fillRange(0, capacity, null);
    _head = 0;
    _count = 0;
  }
}

/// Resumen periódico del estado del logger.
class LogSummary {
  final int totalEntries;
  final int errorCount;
  final int warningCount;
  final Map<LogCategory, int> countByCategory;

  const LogSummary({
    required this.totalEntries,
    required this.errorCount,
    required this.warningCount,
    required this.countByCategory,
  });
}

/// Logger centralizado. Singleton accesible desde cualquier capa.
///
/// No depende de Flutter ni de Riverpod para poder ser usado
/// en isolates futuros si fuera necesario.
class AppLogger {
  AppLogger._({int capacity = 5000}) : _buffer = RingBuffer<LogEntry>(capacity);

  static AppLogger? _instance;

  /// Acceso al singleton. La primera llamada lo crea con la capacidad
  /// indicada; las siguientes ignoran el parámetro.
  static AppLogger get instance => _instance ??= AppLogger._();

  /// Solo para tests: reinicia el singleton.
  static void resetForTesting({int capacity = 5000}) {
    _instance = AppLogger._(capacity: capacity);
  }

  final RingBuffer<LogEntry> _buffer;
  File? _criticalFile;
  List<String> recoveredEntries = const [];
  String? persistenceError;

  Future<void> initialize(String directory) async {
    await Directory(directory).create(recursive: true);
    _criticalFile = File('$directory/critical.jsonl');
    if (await _criticalFile!.exists()) {
      recoveredEntries = await _criticalFile!.readAsLines();
    }
    log(
      LogCategory.app,
      LogLevel.warning,
      'Application started',
      data: {'previous_entries': recoveredEntries.length},
    );
  }

  /// Niveles mínimos por categoría. Entradas por debajo del nivel
  /// configurado se ignoran silenciosamente.
  final Map<LogCategory, LogLevel> _levels = {
    for (final c in LogCategory.values) c: LogLevel.info,
  };

  /// Cantidad total de entradas registradas (incluyendo las descartadas
  /// por el ring buffer).
  int _totalLogged = 0;
  int get totalLogged => _totalLogged;

  // Contadores rápidos para el resumen.
  int _errorCount = 0;
  int _warningCount = 0;
  final Map<LogCategory, int> _countByCategory = {
    for (final c in LogCategory.values) c: 0,
  };

  /// Cambia el nivel mínimo de una categoría.
  void setLevel(LogCategory category, LogLevel level) {
    _levels[category] = level;
  }

  /// Activa DEBUG para todas las categorías.
  void enableDebug() {
    for (final c in LogCategory.values) {
      _levels[c] = LogLevel.debug;
    }
  }

  /// Restaura INFO para todas las categorías.
  void disableDebug() {
    for (final c in LogCategory.values) {
      _levels[c] = LogLevel.info;
    }
  }

  /// Registra una entrada. O(1).
  void log(
    LogCategory category,
    LogLevel level,
    String message, {
    Map<String, dynamic>? data,
    String? error,
    String? stackTrace,
  }) {
    final minLevel = _levels[category] ?? LogLevel.info;
    if (level.index < minLevel.index) return;

    final entry = LogEntry(
      timestampUs: DateTime.now().toUtc().microsecondsSinceEpoch,
      category: category,
      level: level,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    _buffer.add(entry);
    // Eventos críticos y ciclo de sesión sobreviven a un cierre inesperado.
    if (_criticalFile != null &&
        (level.index >= LogLevel.warning.index ||
            category == LogCategory.session)) {
      try {
        _criticalFile!.writeAsStringSync(
          '${jsonEncode(entry.toJson())}\n',
          mode: FileMode.append,
          flush: true,
        );
      } on FileSystemException catch (e) {
        persistenceError = e.toString();
      }
    }
    _totalLogged++;
    _countByCategory[category] = (_countByCategory[category] ?? 0) + 1;
    if (level == LogLevel.error) _errorCount++;
    if (level == LogLevel.warning) _warningCount++;
  }

  /// Obtiene las últimas [n] entradas (o todas si n > length).
  List<LogEntry> getRecent([int? n]) {
    final all = _buffer.toList();
    if (n == null || n >= all.length) return all;
    return all.sublist(all.length - n);
  }

  /// Filtra por categoría y/o nivel.
  List<LogEntry> filter({LogCategory? category, LogLevel? minLevel}) {
    var entries = _buffer.toList();
    if (category != null) {
      entries = entries.where((e) => e.category == category).toList();
    }
    if (minLevel != null) {
      entries = entries.where((e) => e.level.index >= minLevel.index).toList();
    }
    return entries;
  }

  LogSummary getSummary() => LogSummary(
    totalEntries: _totalLogged,
    errorCount: _errorCount,
    warningCount: _warningCount,
    countByCategory: Map.unmodifiable(_countByCategory),
  );

  /// Exporta las entradas actuales a un archivo JSON Lines.
  /// Retorna el [File] creado.
  Future<File> export(String directoryPath) async {
    await Directory(directoryPath).create(recursive: true);
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .split('.')
        .first;
    final file = File('$directoryPath/logs_$timestamp.jsonl');
    final sink = file.openWrite();

    for (final line in recoveredEntries) {
      sink.writeln(line);
    }

    for (final entry in _buffer.toList()) {
      sink.writeln(jsonEncode(entry.toJson()));
    }

    await sink.flush();
    await sink.close();
    return file;
  }

  void clear() {
    _buffer.clear();
    _totalLogged = 0;
    _errorCount = 0;
    _warningCount = 0;
    for (final c in LogCategory.values) {
      _countByCategory[c] = 0;
    }
  }
}
