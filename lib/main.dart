import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/config/router/app_router.dart';
import 'package:muscle_monitoring/config/theme/app_theme.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _logError(details.exception, details.stack ?? StackTrace.current);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(error, stack);
      return true;
    };
    await _boot();
  }, _logError);
}

void _logError(Object error, StackTrace stack) {
  AppLogger.instance.log(
    LogCategory.app,
    LogLevel.error,
    'Unhandled application error',
    error: error.toString(),
    stackTrace: stack.toString(),
  );
}

Future<void> _boot() async {
  try {
    final services = await AppServices.open();
    runApp(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const MainApp(),
      ),
    );
  } catch (e, s) {
    _logError(e, s);
    runApp(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline),
                    const Text('No se pudo abrir el almacenamiento local'),
                    Text(e.toString()),
                    ElevatedButton(
                      onPressed: _boot,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});
  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Una sesión experimental necesita presentación en primer plano.
      unawaited(ref.read(sessionProvider.notifier).stop(status: 'interrupted'));
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: ref.watch(appRouterProvider),
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
  );
}
