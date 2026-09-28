import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:muscle_monitoring/core/acquisition/acquisition_providers.dart';
import 'package:muscle_monitoring/core/acquisition/ble_measurement_source.dart';
import 'package:muscle_monitoring/core/acquisition/measurement_source.dart';
import 'package:muscle_monitoring/core/acquisition/recording_writer.dart';
import 'package:muscle_monitoring/core/acquisition/replay_source.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/data/experiment_database.dart';
import 'session_recorder.dart';

class AppServices {
  AppServices(this.directory, this.database, this.recoveryReports);
  final String directory;
  final ExperimentDatabase database;
  List<Map<String, dynamic>> recoveryReports;
  static Future<AppServices> open() async {
    final directory = (await getApplicationDocumentsDirectory()).path;
    await AppLogger.instance.initialize('$directory/logs');
    final db = await ExperimentDatabase.open('$directory/myosafe.db');
    final recovery = await SessionRecorder.recover(db);
    return AppServices(directory, db, recovery);
  }
}

final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('Inicialización pendiente'),
);

enum FeedbackPolicy { pending, keepChart, hideChart }

class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.source,
    required this.config,
    required this.condition,
    required this.feedbackPolicy,
  });
  final String id;
  final MeasurementSourceType source;
  final FatigueConfig config;
  final ExperimentCondition condition;
  final FeedbackPolicy feedbackPolicy;
  bool get showInterpretation => condition == ExperimentCondition.withAlerts;
  bool get showChart =>
      showInterpretation || feedbackPolicy != FeedbackPolicy.hideChart;
}

class SessionState {
  const SessionState({
    this.session,
    this.busy = false,
    this.error,
    this.report,
    this.lastSessionId,
  });
  final ActiveSession? session;
  final bool busy;
  final String? error;
  final Map<String, dynamic>? report;
  final String? lastSessionId;
  bool get active => session != null;
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((
  ref,
) {
  return SessionController(
    ref.read(servicesProvider),
    ref.read(measurementBusProvider),
  );
});

class SessionController extends StateNotifier<SessionState> {
  SessionController(this.services, this.bus) : super(const SessionState()) {
    bus.onFailure = _fail;
  }
  final AppServices services;
  final MeasurementBus bus;
  SessionRecorder? recorder;
  MeasurementSource? source;
  StreamSubscription<MeasurementEvent>? _subscription;
  Timer? _flushTimer;
  Timer? _statsTimer;
  ParsedRecording? _original;
  final List<Future<bool>> _deliveries = [];
  final List<RecordingEventLine> _replayed = [];
  final _elapsed = Stopwatch();
  double get frequencyPerChannel => _elapsed.elapsedMilliseconds == 0
      ? 0
      : bus.totalEmitted * 1000 / _elapsed.elapsedMilliseconds / 2;
  double frequencyForChannel(String channel) =>
      _elapsed.elapsedMilliseconds == 0
      ? 0
      : (bus.countsByChannel[channel] ?? 0) *
            1000 /
            _elapsed.elapsedMilliseconds;

  Future<void> start({
    required String participant,
    required String exercise,
    required MeasurementSource input,
    required MeasurementSourceType type,
    required ExperimentCondition condition,
    required FeedbackPolicy feedbackPolicy,
    FatigueConfig config = FatigueConfig.defaultConfig,
    String? deviceName,
    String? notes,
    ParsedRecording? original,
  }) async {
    if (state.active || state.busy) {
      throw StateError('Ya hay una sesión en curso');
    }
    if (exercise.trim().isEmpty) throw ArgumentError('Indica un ejercicio');
    if (type == MeasurementSourceType.ble &&
        condition == ExperimentCondition.withoutAlerts &&
        feedbackPolicy == FeedbackPolicy.pending) {
      throw StateError(
        'Define la retroalimentación visible antes de una sesión real sin alertas',
      );
    }
    config.validate();
    state = const SessionState(busy: true);
    final id = const Uuid().v4();
    final path = '${services.directory}/recordings/$id.jsonl';
    final active = ActiveSession(
      id: id,
      source: type,
      config: config,
      condition: condition,
      feedbackPolicy: feedbackPolicy,
    );
    final writer = RecordingWriter(path);
    try {
      await services.database.createSession({
        'id': id,
        'participant_id': participant,
        'condition': condition.databaseValue,
        'exercise': exercise.trim(),
        'started_at_us': DateTime.now().microsecondsSinceEpoch,
        'device_tz_offset_s': DateTime.now().timeZoneOffset.inSeconds,
        'config_json': jsonEncode(config.toJson()),
        'source': type.name,
        'device_name': deviceName,
        'recording_path': path,
        'notes': notes,
        'feedback_policy': feedbackPolicy.name,
      });
      await writer.start(
        config: config,
        source: type,
        deviceName: deviceName,
        metadata: {
          'session_id': id,
          'condition': condition.databaseValue,
          'feedback_policy': feedbackPolicy.name,
          'sequence_origin': 'flutter',
          'firmware_validation': 'pending',
          'capture_raw': input is BleMeasurementSource && input.captureRaw,
        },
      );
      recorder = SessionRecorder(
        database: services.database,
        sessionId: id,
        condition: condition.databaseValue,
        writer: writer,
      );
      _original = original;
      _replayed.clear();
      _deliveries.clear();
      source = input;
      bus.begin(
        source: type,
        config: config,
        condition: condition,
        persist: (line) {
          recorder!.accept(line);
          if (type == MeasurementSourceType.replay) _replayed.add(line);
          AppLogger.instance.log(
            LogCategory.measurement,
            LogLevel.debug,
            'Measurement',
            data: line.toJson(),
          );
          final p = line.processingResult;
          if (p != null) {
            AppLogger.instance.log(
              LogCategory.fatigue,
              p.alertTriggered ? LogLevel.info : LogLevel.debug,
              'Alert evaluation',
              data: {'sequence': line.event.sequence, ...p.toJson()},
            );
          }
          if (p != null && p.fatigueLevel != p.previousLevel) {
            AppLogger.instance.log(
              LogCategory.fatigue,
              LogLevel.info,
              'Threshold crossing',
              data: {'raw_value': line.event.value, ...p.toJson()},
            );
          }
        },
      );
      _subscription = input.measurements.listen(bus.emit, onError: _fail);
      state = SessionState(session: active);
      _elapsed
        ..reset()
        ..start();
      _flushTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(
          recorder!.flush().catchError((Object e, StackTrace s) => _fail(e, s)),
        );
      });
      _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        AppLogger.instance.log(
          LogCategory.measurement,
          LogLevel.info,
          'Acquisition summary',
          data: {
            'received': bus.received,
            'accepted': bus.totalEmitted,
            'rejected': bus.rejected,
            'pending': recorder!.pending,
            'frequency_per_channel_hz': frequencyPerChannel,
          },
        );
      });
      final run = input.start();
      if (input is ReplayMeasurementSource) {
        unawaited(
          run
              .then<void>((_) async {
                await Future<void>.delayed(Duration.zero);
                if (state.session?.id == id &&
                    input.replayState == ReplayState.completed) {
                  await stop();
                }
              })
              .catchError((Object e, StackTrace s) => _fail(e, s)),
        );
      } else {
        await run;
      }
      AppLogger.instance.log(
        LogCategory.session,
        LogLevel.info,
        'Session started',
        data: {
          'id': id,
          'source': type.name,
          'condition': condition.databaseValue,
        },
      );
    } catch (e, s) {
      if (state.active) {
        _fail(e, s);
      } else {
        state = SessionState(error: e.toString());
        await writer.abort();
      }
      rethrow;
    }
  }

  Future<void> startReplay(File file) async {
    final original = await RecordingReader.parse(file);
    if (original.algorithmVersion !=
        FatigueConfig.defaultConfig.algorithmVersion) {
      throw const FormatException('Versión del algoritmo incompatible');
    }
    final db = services.database;
    if ((await db.db.query(
      'participants',
      where: 'id = ?',
      whereArgs: ['__replay__'],
    )).isEmpty) {
      await db.addParticipant('__replay__', alias: 'Diagnóstico');
    }
    final condition = original.header['condition'] == 'without_alerts'
        ? ExperimentCondition.withoutAlerts
        : ExperimentCondition.withAlerts;
    await start(
      participant: '__replay__',
      exercise: 'Reproducción',
      input: ReplayMeasurementSource(original),
      type: MeasurementSourceType.replay,
      condition: condition,
      config: original.config,
      feedbackPolicy: FeedbackPolicy.values.firstWhere(
        (policy) => policy.name == original.header['feedback_policy'],
        orElse: () => FeedbackPolicy.pending,
      ),
      original: original,
      notes: file.path,
    );
  }

  void _fail(Object error, StackTrace stack) {
    if (!mounted) return;
    AppLogger.instance.log(
      LogCategory.session,
      LogLevel.error,
      'Acquisition interrupted',
      error: error.toString(),
      stackTrace: stack.toString(),
      data: {'session': state.session?.id},
    );
    state = SessionState(
      session: state.session,
      busy: state.busy,
      error: error.toString(),
    );
    if (state.active && !state.busy) unawaited(stop(status: 'interrupted'));
  }

  void recordDelivery(
    int sequence, {
    required bool shown,
    String? reason,
    bool dismissed = false,
  }) {
    if (!state.active || state.busy || recorder == null) return;
    final pending = recorder!
        .delivery(sequence, shown: shown, reason: reason, dismissed: dismissed)
        .then((_) => true)
        .catchError((Object e, StackTrace s) {
          _fail(e, s);
          return false;
        });
    _deliveries.add(pending);
  }

  Future<void> stop({String status = 'completed'}) async {
    if (!state.active || state.busy) return;
    final session = state.session!;
    final previousError = state.error;
    state = SessionState(session: session, busy: true, error: previousError);
    _flushTimer?.cancel();
    _statsTimer?.cancel();
    try {
      await source?.stop();
      await Future<void>.delayed(Duration.zero);
      bus.end();
      await _subscription?.cancel();
      _subscription = null;
      if (session.source != MeasurementSourceType.ble) await source?.dispose();
      _elapsed.stop();
      final deliveries = await Future.wait(_deliveries);
      if (deliveries.contains(false)) {
        throw StateError(
          'Entrega de alertas pendiente de recuperar desde el registro',
        );
      }
      final report = await recorder!.finish(status);
      report.addAll({
        'received': bus.received,
        'accepted': bus.totalEmitted,
        'rejected': bus.rejected,
      });
      final finalError = state.error;
      if (bus.rejected > 0 || finalError != null) report['ok'] = false;
      if (_original != null) {
        final replayFile = await RecordingReader.parse(
          File(recorder!.writer.filePath),
        );
        final comparison = compareRecording(
          _original!,
          _replayed,
          deliveries: replayFile.deliveries,
        );
        report['comparison'] = comparison;
        await File(
          '${services.directory}/recordings/${session.id}_comparison.json',
        ).writeAsString(
          const JsonEncoder.withIndent('  ').convert(comparison),
          flush: true,
        );
      }
      await services.database.finish(
        session.id,
        report['ok'] == true ? status : 'interrupted',
        report,
      );
      state = SessionState(
        report: report,
        lastSessionId: session.id,
        error: finalError,
      );
    } catch (e, s) {
      bus.end();
      _elapsed.stop();
      await _subscription?.cancel();
      _subscription = null;
      try {
        await recorder?.writer.abort();
      } catch (_) {
        /* Preserve original error. */
      }
      AppLogger.instance.log(
        LogCategory.session,
        LogLevel.error,
        'Session finalization failed',
        error: e.toString(),
        stackTrace: s.toString(),
        data: {'session': session.id},
      );
      state = SessionState(
        error:
            'No se pudo finalizar. El registro se recuperará al reiniciar: $e',
        lastSessionId: session.id,
      );
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _statsTimer?.cancel();
    bus.onFailure = null;
    unawaited(_subscription?.cancel());
    unawaited(source?.stop());
    unawaited(
      recorder?.writer.abort().catchError((Object error) {
        AppLogger.instance.log(
          LogCategory.session,
          LogLevel.error,
          'Journal close failed',
          error: error.toString(),
        );
      }),
    );
    // El journal ya es durable; una sesión aún activa se recupera al reiniciar.
    super.dispose();
  }
}
