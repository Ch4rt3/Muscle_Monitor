import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:muscle_monitoring/presentation/screens/home_screen.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/features/session/screens/research_screen.dart';
import 'package:muscle_monitoring/features/session/screens/session_setup_screen.dart';
import 'package:muscle_monitoring/features/session/screens/session_end_screen.dart';
import 'package:muscle_monitoring/features/participants/participants_screen.dart';
import 'package:muscle_monitoring/features/diagnostics/diagnostics_screen.dart';
import 'package:muscle_monitoring/features/replay/replay_screen.dart';
import 'package:muscle_monitoring/features/export/export_screen.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_alert_manager.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(
    sessionProvider.select((s) => s.session?.id),
    (_, next) => refresh.value++,
  );
  final router = GoRouter(
    initialLocation: '/home/0',
    refreshListenable: refresh,
    redirect: (context, state) {
      final active = ref.read(sessionProvider).session;
      if (active == null) return null;
      final path = state.uri.path;
      final allowed =
          path.startsWith('/home') ||
          (active.source == MeasurementSourceType.replay &&
              path == '/replay') ||
          (active.source != MeasurementSourceType.ble &&
              path == '/diagnostics');
      return allowed ? null : '/home/1';
    },
    routes: [
      GoRoute(path: '/', redirect: (_, state) => '/home/0'),
      GoRoute(
        path: '/home/:page',
        builder: (_, state) {
          final page = int.tryParse(state.pathParameters['page'] ?? '0') ?? 0;
          return FatigueAlertManager(
            child: HomeScreen(initialPage: page.clamp(0, 1)),
          );
        },
      ),
      GoRoute(path: '/research', builder: (_, state) => const ResearchScreen()),
      GoRoute(
        path: '/participants',
        builder: (_, state) => const ParticipantsScreen(),
      ),
      GoRoute(
        path: '/session/setup',
        builder: (_, state) => const SessionSetupScreen(),
      ),
      GoRoute(
        path: '/session/end',
        builder: (_, state) => const SessionEndScreen(),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (_, state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: '/replay',
        builder: (_, state) => const FatigueAlertManager(child: ReplayScreen()),
      ),
      GoRoute(path: '/export', builder: (_, state) => const ExportScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
