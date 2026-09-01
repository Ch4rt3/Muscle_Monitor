import 'package:flutter/material.dart';
// ┌──────────────────────────────────────────────────────────────────┐
// │  MODO DEMO TEMPORAL — Para restaurar la app real:                │
// │  1. Descomentar los imports y el cuerpo de MainApp de abajo     │
// │  2. Comentar/eliminar el import de demo_gallery                 │
// │  3. Eliminar lib/presentation/screens/demo_gallery.dart         │
// └──────────────────────────────────────────────────────────────────┘

// ── Imports originales (comentados durante demo) ──
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:muscle_monitoring/config/router/app_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/config/theme/app_theme.dart';
import 'package:muscle_monitoring/presentation/screens/demo_gallery.dart';

void main() {
  // FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ── MODO DEMO ──
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const DemoGallery(),
    );

    // ── APP REAL (descomentar para restaurar) ──
    // return MaterialApp.router(
    //   routerConfig: AppRouter.router,
    //   debugShowCheckedModeBanner: false,
    //   theme: AppTheme.light(),
    // );
  }
}
