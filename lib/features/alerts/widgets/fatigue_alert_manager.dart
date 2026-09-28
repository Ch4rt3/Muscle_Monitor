import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/features/alerts/providers/fatigue_alert_provider.dart';
import 'package:muscle_monitoring/features/alerts/utils/fatigue_utils.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_alert_widget.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';

class FatigueAlertManager extends ConsumerStatefulWidget {
  const FatigueAlertManager({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<FatigueAlertManager> createState() => _ManagerState();
}

class _ManagerState extends ConsumerState<FatigueAlertManager> {
  OverlayEntry? _overlay;
  int? _lastSequence;
  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider.select((s) => s.session?.id), (_, next) {
      _remove();
      _lastSequence = null;
    });
    ref.listen(fatigueAlertProvider, (previous, next) {
      final session = ref.read(sessionProvider).session;
      if (session == null ||
          !session.showInterpretation ||
          !next.isAlertActive) {
        _remove();
        return;
      }
      final seq = next.alertSequence;
      final config = getAlertConfig(next.currentLevel);
      if (seq == null ||
          config == null ||
          seq == _lastSequence ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _lastSequence = seq;
      _remove();
      try {
        _overlay = OverlayEntry(
          builder: (context) => Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: FatigueAlertWidget(
                config: config,
                onDismiss: () {
                  _remove();
                  ref
                      .read(sessionProvider.notifier)
                      .recordDelivery(seq, shown: true, dismissed: true);
                  ref.read(fatigueAlertProvider.notifier).dismissAlert();
                },
                onAutoDismiss: () {
                  _remove();
                  ref.read(fatigueAlertProvider.notifier).dismissAlert();
                },
              ),
            ),
          ),
        );
        Overlay.of(context).insert(_overlay!);
        final insertedOverlay = _overlay;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              identical(_overlay, insertedOverlay) &&
              _overlay != null &&
              ref.read(sessionProvider).session?.id == session.id) {
            ref.read(sessionProvider.notifier).recordDelivery(seq, shown: true);
          }
        });
      } catch (error) {
        _remove();
        ref
            .read(sessionProvider.notifier)
            .recordDelivery(seq, shown: false, reason: 'overlay_error: $error');
      }
    });
    return widget.child;
  }
}
