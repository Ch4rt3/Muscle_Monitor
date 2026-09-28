/// Fuente de mediciones por simulación controlada.
///
/// Genera datos siguiendo un ciclo de 4 fases (calentamiento, esfuerzo,
/// fatiga alta, descanso) a una frecuencia configurable. Cada tick
/// produce dos [MeasurementEvent] independientes (fuerza y fatiga),
/// cada uno con su propia secuencia.
///
/// Reemplaza al `_startExerciseSimulation()` inline de `ble_provider.dart`.
library;

import 'dart:async';
import 'dart:math';

import 'package:muscle_monitoring/core/acquisition/measurement_source.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';

class SimulationMeasurementSource implements MeasurementSource {
  SimulationMeasurementSource({this.intervalMs = 40, int? seed})
    : _rand = Random(seed);

  /// Intervalo entre ticks en milisegundos (40ms = 25 Hz).
  final int intervalMs;

  final Random _rand;
  final _controller = StreamController<MeasurementEvent>.broadcast();
  Timer? _timer;
  int _simStep = 0;
  int _seqFuerza = 0;
  int _seqFatiga = 0;
  MeasurementSourceStatus _status = MeasurementSourceStatus.idle;

  // 500 steps = 20 segundos @ 25 Hz. 4 fases de 125 steps.
  static const int _totalSteps = 500;
  static const int _phaseLength = 125;

  @override
  Stream<MeasurementEvent> get measurements => _controller.stream;

  @override
  MeasurementSourceStatus get status => _status;

  /// Secuencias actuales (para verificación de integridad).
  int get sequenceFuerza => _seqFuerza;
  int get sequenceFatiga => _seqFatiga;

  @override
  Future<void> start() async {
    if (_status == MeasurementSourceStatus.running) return;

    _status = MeasurementSourceStatus.running;
    _simStep = 0;
    _seqFuerza = 0;
    _seqFatiga = 0;

    AppLogger.instance.log(
      LogCategory.measurement,
      LogLevel.info,
      'Simulation source started',
      data: {'interval_ms': intervalMs, 'frequency_hz': 1000 / intervalMs},
    );

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), _tick);
  }

  void _tick(Timer _) {
    final phase = (_simStep ~/ _phaseLength) % 4;
    final progress = (_simStep % _phaseLength) / _phaseLength;
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;

    double fatigaValue;
    double fuerzaValue;

    switch (phase) {
      case 0: // Calentamiento: 0 → 40
        fatigaValue = 40 * progress;
        fuerzaValue = 20 + 30 * progress;
      case 1: // Esfuerzo moderado: 40 → 60
        fatigaValue = 40 + 20 * progress;
        fuerzaValue = 50 + 30 * progress;
      case 2: // Fatiga alta: 60 → 100
        fatigaValue = 60 + 40 * progress;
        fuerzaValue = 80 + 15 * progress;
      case 3: // Descanso: 100 → 20
        fatigaValue = 100 - 80 * progress;
        fuerzaValue = 95 - 65 * progress;
      default:
        fatigaValue = 0;
        fuerzaValue = 0;
    }

    // Variabilidad natural (±5 unidades).
    fatigaValue += (_rand.nextDouble() - 0.5) * 10;
    fuerzaValue += (_rand.nextDouble() - 0.5) * 10;
    fatigaValue = fatigaValue.clamp(0, 100);
    fuerzaValue = fuerzaValue.clamp(0, 100);

    final fuerzaEvent = MeasurementEvent(
      channel: 'fuerza',
      value: fuerzaValue,
      receptionTimestampUs: now,
      sequence: _seqFuerza++,
      source: MeasurementSourceType.simulation,
    );

    final fatigaEvent = MeasurementEvent(
      channel: 'fatiga',
      value: fatigaValue,
      receptionTimestampUs: now,
      sequence: _seqFatiga++,
      source: MeasurementSourceType.simulation,
    );

    if (!_controller.isClosed) {
      _controller.add(fuerzaEvent);
      _controller.add(fatigaEvent);
    }

    _simStep = (_simStep + 1) % _totalSteps;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _status = MeasurementSourceStatus.stopped;

    AppLogger.instance.log(
      LogCategory.measurement,
      LogLevel.info,
      'Simulation source stopped',
      data: {'total_fuerza': _seqFuerza, 'total_fatiga': _seqFatiga},
    );
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
