import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/core/acquisition/acquisition_providers.dart';
import 'package:muscle_monitoring/core/acquisition/recording_writer.dart';
import 'package:muscle_monitoring/features/alerts/models/alert_state.dart';
import 'package:muscle_monitoring/features/alerts/utils/fatigue_utils.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';

class FatigueAlertNotifier extends StateNotifier<FatigueAlertState> {
  FatigueAlertNotifier(Ref ref) : super(const FatigueAlertState()) {
    _subscription = ref.read(measurementBusProvider).processed.listen((line) {
      final result = line.processingResult;
      if (result == null || !ref.read(sessionProvider).active) return;
      final level = FatigueLevel.values.byName(result.fatigueLevel);
      state = state.copyWith(
        currentLevel: level,
        currentValue: result.smoothedValue,
        isAlertActive:
            result.shouldDisplay ||
            (level != FatigueLevel.none && state.isAlertActive),
        alertSequence: result.shouldDisplay
            ? line.event.sequence
            : state.alertSequence,
      );
    });
    ref.listen(
      sessionProvider.select((s) => s.session?.id),
      (_, next) => reset(),
    );
  }
  StreamSubscription<RecordingEventLine>? _subscription;
  void dismissAlert() {
    state = state.copyWith(isAlertActive: false);
  }

  void reset() {
    state = const FatigueAlertState();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final fatigueAlertProvider =
    StateNotifierProvider<FatigueAlertNotifier, FatigueAlertState>(
      (ref) => FatigueAlertNotifier(ref),
    );
final hasActiveAlertProvider = Provider<bool>(
  (ref) => ref.watch(fatigueAlertProvider).isAlertActive,
);
final currentFatigueLevelProvider = Provider<FatigueLevel>(
  (ref) => ref.watch(fatigueAlertProvider).currentLevel,
);
