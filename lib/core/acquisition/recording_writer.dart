/// Escritor incremental de grabaciones de diagnóstico en formato JSONL.
///
/// Cada evento se escribe como una línea JSON independiente.
/// Si la app se cierra inesperadamente, los eventos anteriores
/// ya escritos permanecen intactos (propiedad de JSONL).
///
/// La grabación incluye un header con metadatos y un footer con
/// contadores finales. El header se escribe al iniciar, el footer
/// al finalizar. Si falta el footer, la grabación se considera
/// interrumpida (pero sigue siendo legible).
library;

import 'dart:convert';
import 'dart:io';

import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';

/// Resultado del procesamiento de fatiga para un evento individual.
/// Se guarda junto con el evento para permitir comparación posterior
/// durante la reproducción.
class ProcessingResult {
  final double smoothedValue;
  final String fatigueLevel;
  final bool alertTriggered;
  final bool alertShown;
  final String? suppressionReason;
  final String previousLevel;
  bool get shouldDisplay => alertTriggered && suppressionReason == null;

  const ProcessingResult({
    required this.smoothedValue,
    required this.fatigueLevel,
    required this.alertTriggered,
    required this.alertShown,
    this.suppressionReason,
    this.previousLevel = 'none',
  });

  Map<String, dynamic> toJson() => {
    'smooth': smoothedValue,
    'lvl': fatigueLevel,
    'alert_trig': alertTriggered,
    'alert_shown': alertShown,
    'previous_level': previousLevel,
    if (suppressionReason != null) 'suppr': suppressionReason,
  };

  factory ProcessingResult.fromJson(Map<String, dynamic> json) {
    return ProcessingResult(
      smoothedValue: (json['smooth'] as num).toDouble(),
      fatigueLevel: json['lvl'] as String,
      alertTriggered: json['alert_trig'] as bool,
      alertShown: json['alert_shown'] as bool,
      suppressionReason: json['suppr'] as String?,
      previousLevel: json['previous_level'] as String? ?? 'none',
    );
  }
}

/// Formato de una línea de evento en la grabación.
class RecordingEventLine {
  final int formatVersion;
  final MeasurementEvent event;
  final ProcessingResult? processingResult;

  const RecordingEventLine({
    required this.formatVersion,
    required this.event,
    this.processingResult,
  });

  Map<String, dynamic> toJson() => {
    'v': formatVersion,
    ...event.toJson(),
    if (processingResult != null) 'proc': processingResult!.toJson(),
  };

  factory RecordingEventLine.fromJson(Map<String, dynamic> json) {
    return RecordingEventLine(
      formatVersion: json['v'] as int,
      event: MeasurementEvent.fromJson(json),
      processingResult: json['proc'] != null
          ? ProcessingResult.fromJson(json['proc'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RecordingWriter {
  final File _file;
  RandomAccessFile? _sink;
  int _eventCount = 0;
  final Map<String, int> _channelCounts = {};
  bool _isOpen = false;

  static const int _formatVersion = 1;

  RecordingWriter(String filePath) : _file = File(filePath);

  String get filePath => _file.path;
  int get eventCount => _eventCount;
  bool get isOpen => _isOpen;
  Map<String, int> get channelCounts => Map.unmodifiable(_channelCounts);

  /// Inicia la grabación escribiendo el header.
  Future<void> start({
    required FatigueConfig config,
    required MeasurementSourceType source,
    String? deviceName,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_isOpen) throw StateError('Ya existe una grabación abierta');
    await _file.parent.create(recursive: true);
    if (await _file.exists()) throw StateError('La grabación ya existe');
    _sink = _file.openSync(mode: FileMode.writeOnly);
    _isOpen = true;
    _eventCount = 0;
    _channelCounts.clear();

    final header = {
      'type': 'header',
      'format_version': _formatVersion,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'device_tz_offset': DateTime.now().timeZoneOffset.inSeconds,
      'config': config.toJson(),
      'source': source.name,
      'algorithm_version': config.algorithmVersion,
      if (deviceName != null) 'device_name': deviceName,
      ...metadata,
    };

    writeRecord(header);

    AppLogger.instance.log(
      LogCategory.session,
      LogLevel.info,
      'Recording started',
      data: {'file': _file.path, 'source': source.name},
    );
  }

  /// Escribe un evento de medición con su resultado de procesamiento
  /// opcional.
  void writeEvent(
    MeasurementEvent event, {
    ProcessingResult? processingResult,
  }) {
    if (!_isOpen || _sink == null) throw StateError('Grabador cerrado');

    final line = RecordingEventLine(
      formatVersion: _formatVersion,
      event: event,
      processingResult: processingResult,
    );

    writeRecord(line.toJson());
    _eventCount++;
    _channelCounts[event.channel] = (_channelCounts[event.channel] ?? 0) + 1;
  }

  /// Finaliza la grabación escribiendo el footer y cerrando el archivo.
  Future<void> stop({String status = 'completed'}) async {
    if (!_isOpen || _sink == null) return;

    final footer = {
      'type': 'footer',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'total_events': _channelCounts,
      'total_count': _eventCount,
      'status': status,
    };

    writeRecord(footer);
    _sink!.closeSync();
    _sink = null;
    _isOpen = false;

    AppLogger.instance.log(
      LogCategory.session,
      LogLevel.info,
      'Recording stopped',
      data: {
        'file': _file.path,
        'total': _eventCount,
        'channels': _channelCounts,
        'status': status,
      },
    );
  }

  /// Cierra la grabación marcándola como interrumpida.
  Future<void> abort() async {
    await stop(status: 'interrupted');
  }

  /// Journal durable antes de publicar a consumidores: los errores se propagan.
  /// El coste de flush se mide en las pruebas de carga y debe validarse en móvil.
  void writeRecord(Map<String, dynamic> record) {
    if (!_isOpen || _sink == null) throw StateError('Grabador cerrado');
    _sink!.writeStringSync('${jsonEncode(record)}\n');
    _sink!.flushSync();
  }
}
