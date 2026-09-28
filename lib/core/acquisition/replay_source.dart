import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'measurement_source.dart';
import 'recording_writer.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';

class ParsedRecording {
  const ParsedRecording({
    required this.header,
    required this.events,
    required this.footer,
    required this.config,
    required this.isComplete,
    required this.warnings,
    this.deliveries = const [],
  });
  final Map<String, dynamic> header;
  final List<RecordingEventLine> events;
  final Map<String, dynamic>? footer;
  final FatigueConfig config;
  final bool isComplete;
  final List<String> warnings;
  final List<Map<String, dynamic>> deliveries;
  int get totalEvents => events.length;
  String get source => header['source'] as String? ?? 'unknown';
  String get algorithmVersion =>
      header['algorithm_version'] as String? ?? 'unknown';
}

class RecordingReader {
  static Future<ParsedRecording> parse(File file) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) throw const FormatException('Grabación vacía');
    late Map<String, dynamic> header;
    late FatigueConfig config;
    try {
      header = jsonDecode(lines.first) as Map<String, dynamic>;
      if (header['type'] != 'header' || header['format_version'] != 1) {
        throw const FormatException('Formato de grabación incompatible');
      }
      config = FatigueConfig.fromJson(header['config'] as Map<String, dynamic>);
      config.validate();
    } catch (e) {
      throw FormatException('Cabecera de grabación inválida: $e');
    }
    final events = <RecordingEventLine>[];
    final deliveries = <Map<String, dynamic>>[];
    final warnings = <String>[];
    final keys = <String>{};
    final sequences = <String, int>{};
    int? lastTime;
    Map<String, dynamic>? footer;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      try {
        final json = jsonDecode(lines[i]) as Map<String, dynamic>;
        if (footer != null) {
          throw const FormatException('Contenido después del cierre');
        }
        if (json['type'] == 'footer') {
          footer = json;
          continue;
        }
        if (json['type'] == 'delivery' || json['type'] == 'dismissal') {
          deliveries.add(json);
          continue;
        }
        final line = RecordingEventLine.fromJson(json);
        final event = line.event;
        if (line.formatVersion != 1 ||
            !event.value.isFinite ||
            !{'fuerza', 'fatiga'}.contains(event.channel) ||
            event.sequence < 0) {
          throw const FormatException('Evento incompatible');
        }
        final key = '${event.channel}:${event.sequence}';
        if (!keys.add(key)) throw FormatException('Medición duplicada: $key');
        if (lastTime != null && event.receptionTimestampUs < lastTime) {
          warnings.add('Línea ${i + 1}: tiempo de recepción retrocede');
        }
        if (event.sequence != (sequences[event.channel] ?? -1) + 1) {
          warnings.add(
            'Línea ${i + 1}: salto de secuencia Flutter (no prueba pérdida BLE)',
          );
        }
        sequences[event.channel] = event.sequence;
        lastTime = event.receptionTimestampUs;
        events.add(line);
      } catch (e) {
        warnings.add('Línea ${i + 1}: $e');
      }
    }
    if (footer == null) warnings.add('Grabación interrumpida: falta cierre');
    if (footer != null && footer['total_count'] != events.length) {
      warnings.add('El contador de cierre no coincide con los eventos');
    }
    return ParsedRecording(
      header: header,
      events: List.unmodifiable(events),
      footer: footer,
      config: config,
      isComplete: footer != null && warnings.isEmpty,
      warnings: List.unmodifiable(warnings),
      deliveries: List.unmodifiable(deliveries),
    );
  }
}

enum ReplayState { idle, playing, paused, stopped, completed, error }

class ReplayMeasurementSource implements MeasurementSource {
  ReplayMeasurementSource(this.recording);
  final ParsedRecording recording;
  final _controller = StreamController<MeasurementEvent>.broadcast();
  Timer? _timer;
  final _watch = Stopwatch();
  Completer<void>? _completion;
  double _remainingUs = 0;
  double _speed = 1;
  int _index = 0;
  ReplayState _state = ReplayState.idle;
  @override
  Stream<MeasurementEvent> get measurements => _controller.stream;
  @override
  MeasurementSourceStatus get status => switch (_state) {
    ReplayState.idle => MeasurementSourceStatus.idle,
    ReplayState.playing => MeasurementSourceStatus.running,
    ReplayState.paused => MeasurementSourceStatus.paused,
    ReplayState.error => MeasurementSourceStatus.error,
    _ => MeasurementSourceStatus.stopped,
  };
  ReplayState get replayState => _state;
  double get playbackSpeed => _speed;
  int get currentEventIndex => _index;
  int get totalEvents => recording.events.length;
  double get progress => totalEvents == 0 ? 0 : _index / totalEvents;
  FatigueConfig get originalConfig => recording.config;
  List<ProcessingResult?> get originalResults =>
      recording.events.map((e) => e.processingResult).toList();

  void setSpeed(double speed) {
    if (!speed.isFinite || speed < 0.25 || speed > 4) {
      throw ArgumentError('Velocidad fuera de rango');
    }
    final running = _state == ReplayState.playing;
    if (running) _cancelDelay();
    _speed = speed;
    if (running) _schedule();
  }

  @override
  Future<void> start() {
    if (_state == ReplayState.playing || _state == ReplayState.paused) {
      return _completion!.future;
    }
    if (_controller.isClosed) throw StateError('Reproductor cerrado');
    if (recording.events.isEmpty) {
      throw const FormatException('Grabación sin mediciones');
    }
    _completion = Completer<void>();
    _index = 0;
    _remainingUs = 0;
    _state = ReplayState.playing;
    _schedule();
    return _completion!.future;
  }

  void _cancelDelay() {
    _timer?.cancel();
    _remainingUs = (_remainingUs - _watch.elapsedMicroseconds * _speed).clamp(
      0,
      double.infinity,
    );
    _watch.stop();
  }

  void _schedule() {
    _watch
      ..reset()
      ..start();
    _timer = Timer(
      Duration(microseconds: (_remainingUs / _speed).round()),
      _emitNext,
    );
  }

  void _emitNext() {
    if (_state != ReplayState.playing) return;
    _watch.stop();
    final e = recording.events[_index].event;
    _controller.add(
      MeasurementEvent(
        channel: e.channel,
        value: e.value,
        receptionTimestampUs: e.receptionTimestampUs,
        sequence: e.sequence,
        source: MeasurementSourceType.replay,
        rawBytes: e.rawBytes,
        firmwareSequence: e.firmwareSequence,
      ),
    );
    _index++;
    if (_index == totalEvents) {
      _state = ReplayState.completed;
      _completion?.complete();
      return;
    }
    _remainingUs =
        (recording.events[_index].event.receptionTimestampUs -
                e.receptionTimestampUs)
            .clamp(0, 1 << 53)
            .toDouble();
    _schedule();
  }

  Future<void> pause() async {
    if (_state != ReplayState.playing) return;
    _cancelDelay();
    _state = ReplayState.paused;
  }

  Future<void> resume() async {
    if (_state != ReplayState.paused) return;
    _state = ReplayState.playing;
    _schedule();
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _watch.stop();
    _state = ReplayState.stopped;
    if (_completion != null && !_completion!.isCompleted) {
      _completion!.complete();
    }
  }

  void seekToBeginning() {
    if (_state == ReplayState.playing || _state == ReplayState.paused) {
      throw StateError('Detén la reproducción antes de reiniciarla');
    }
    _index = 0;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

/// Compara datos y decisiones deterministas. La entrega real se informa aparte.
Map<String, dynamic> compareRecording(
  ParsedRecording original,
  List<RecordingEventLine> replay, {
  List<Map<String, dynamic>> deliveries = const [],
}) {
  final differences = <Map<String, dynamic>>[];
  var missingOriginalResults = 0;
  final count = original.events.length < replay.length
      ? original.events.length
      : replay.length;
  for (var i = 0; i < count; i++) {
    final a = Map<String, dynamic>.of(original.events[i].event.toJson())
      ..remove('src');
    final b = Map<String, dynamic>.of(replay[i].event.toJson())..remove('src');
    if (jsonEncode(a) != jsonEncode(b)) {
      differences.add({'index': i, 'kind': 'measurement'});
    }
    final p = original.events[i].processingResult;
    final q = replay[i].processingResult;
    if (original.events[i].event.channel == 'fatiga' && p == null) {
      missingOriginalResults++;
    }
    if (p != null && q != null) {
      final pa = p.toJson()..remove('alert_shown');
      final qa = q.toJson()..remove('alert_shown');
      if (jsonEncode(pa) != jsonEncode(qa)) {
        differences.add({
          'index': i,
          'kind': 'processing',
          'original': pa,
          'replay': qa,
        });
      }
    } else if (p != null && q == null) {
      differences.add({'index': i, 'kind': 'missing_processing'});
    }
  }
  return {
    'original_count': original.events.length,
    'replay_count': replay.length,
    'missing_original_results': missingOriginalResults,
    'differences': differences,
    'original_deliveries': original.deliveries,
    'replay_deliveries': deliveries,
    'original_warnings': original.warnings,
    'match':
        differences.isEmpty &&
        missingOriginalResults == 0 &&
        original.events.length == replay.length &&
        original.warnings.isEmpty,
  };
}
