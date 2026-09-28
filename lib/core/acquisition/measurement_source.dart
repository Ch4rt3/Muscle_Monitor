import 'dart:async';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'fatigue_processor.dart';
import 'recording_writer.dart';

enum MeasurementSourceStatus { idle, running, paused, stopped, error }

abstract class MeasurementSource {
  Stream<MeasurementEvent> get measurements;
  MeasurementSourceStatus get status;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// Publica solamente eventos aceptados por el registro durable.
/// El grabador es una llamada directa obligatoria, independiente del broadcast.
class MeasurementBus {
  final _controller = StreamController<MeasurementEvent>.broadcast();
  final _processed = StreamController<RecordingEventLine>.broadcast();
  Stream<MeasurementEvent> get stream => _controller.stream;
  Stream<RecordingEventLine> get processed => _processed.stream;
  final Map<String, int> _sequences = {};
  final Map<String, int> _counts = {};
  final Map<String, MeasurementEvent> latest = {};
  int totalEmitted = 0;
  int received = 0;
  int rejected = 0;
  bool _closed = false;
  bool _failed = false;
  MeasurementSourceType? _source;
  FatigueProcessor? _processor;
  void Function(RecordingEventLine)? _persist;
  void Function(Object, StackTrace)? onFailure;
  Map<String, int> get sequencesByChannel => Map.unmodifiable(_sequences);
  Map<String, int> get countsByChannel => Map.unmodifiable(_counts);
  bool get active => _source != null;

  void begin({
    required MeasurementSourceType source,
    required FatigueConfig config,
    required ExperimentCondition condition,
    required void Function(RecordingEventLine) persist,
  }) {
    if (active || _closed) throw StateError('Bus no disponible');
    _processor = FatigueProcessor(config, condition);
    _persist = persist;
    _source = source;
    _failed = false;
    _sequences.clear();
    _counts.clear();
    latest.clear();
    totalEmitted = 0;
    received = 0;
    rejected = 0;
  }

  void emit(MeasurementEvent input) {
    // Fuera de sesión y fuentes distintas no son mediciones aceptadas.
    if (_source == null || input.source != _source || _closed) return;
    received++;
    if (_failed) {
      rejected++;
      return;
    }
    try {
      if (!input.value.isFinite ||
          !{'fuerza', 'fatiga'}.contains(input.channel)) {
        throw FormatException('Medición inválida');
      }
      final sequence = input.source == MeasurementSourceType.replay
          ? input.sequence
          : (_sequences[input.channel] ?? -1) + 1;
      final event = MeasurementEvent(
        channel: input.channel,
        value: input.value,
        receptionTimestampUs: input.receptionTimestampUs,
        sequence: sequence,
        source: input.source,
        rawBytes: input.rawBytes,
        firmwareSequence: input.firmwareSequence,
      );
      final line = RecordingEventLine(
        formatVersion: 1,
        event: event,
        processingResult: event.channel == 'fatiga'
            ? _processor!.process(event)
            : null,
      );
      _persist!(line); // Confirmación durable ANTES de contadores y broadcast.
      _sequences[event.channel] = sequence;
      _counts.update(event.channel, (count) => count + 1, ifAbsent: () => 1);
      totalEmitted++;
      latest[event.channel] = event;
      _controller.add(event);
      _processed.add(line);
    } catch (error, stack) {
      rejected++;
      _failed = true;
      onFailure?.call(error, stack);
    }
  }

  void end() {
    _source = null;
    _persist = null;
    _processor = null;
  }

  void dispose() {
    end();
    _closed = true;
    unawaited(_controller.close());
    unawaited(_processed.close());
  }
}
