import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:muscle_monitoring/data/experiment_database.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/features/session/screens/session_setup_screen.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_indicator.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_alert_manager.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_alert_widget.dart';
import 'package:muscle_monitoring/presentation/screens/monitoring_screen.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
import 'package:muscle_monitoring/core/acquisition/acquisition_providers.dart';
import 'package:muscle_monitoring/features/alerts/providers/fatigue_alert_provider.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import '../core/session_flow_test.dart' show ManualSource;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manifest = File('.dart_tool/package_config.json').absolute;
    final packages =
        (jsonDecode(await manifest.readAsString()) as Map)['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter') as Map;
    final root = manifest.uri.resolve('${flutter['rootUri']}/');
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await File.fromUri(
        root.resolve('../../bin/cache/artifacts/material_fonts/${entry.value}'),
      ).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  late Directory dir;
  late ExperimentDatabase db;
  late ProviderContainer container;
  late ManualSource source;
  setUp(() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('myosafe_ui');
    db = await ExperimentDatabase.open(
      '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    await db.addParticipant('P01');
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(AppServices(dir.path, db, [])),
      ],
    );
    source = ManualSource();
  });
  tearDown(() async {
    container.dispose();
    await source.dispose();
    await db.db.close();
    await dir.delete(recursive: true);
  });
  Widget app(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.fullRadius),
          ),
        ),
      ),
      home: child,
    ),
  );

  for (final hide in [false, true]) {
    testWidgets(
      'sin alertas: indicador y labels ocultos, gráfica ${hide ? 'oculta' : 'visible'}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(const FatigueAlertManager(child: MonitoringScreen())),
        );
        await tester.runAsync(
          () => container
              .read(sessionProvider.notifier)
              .start(
                participant: 'P01',
                exercise: 'test',
                input: source,
                type: MeasurementSourceType.simulation,
                condition: ExperimentCondition.withoutAlerts,
                feedbackPolicy: hide
                    ? FeedbackPolicy.hideChart
                    : FeedbackPolicy.keepChart,
              ),
        );
        await tester.runAsync(() async {
          source.emit(0);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(FatigueIndicator), findsNothing);
        expect(find.byType(FatigueAlertWidget), findsNothing);
        expect(find.text('Severa'), findsNothing);
        expect(
          find.text('Fatiga muscular'),
          hide ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => container.read(sessionProvider.notifier).stop(),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets(
    'con alertas: overlay visible y confirmación de entrega en SQLite',
    (tester) async {
      await tester.pumpWidget(
        app(const FatigueAlertManager(child: MonitoringScreen())),
      );
      await tester.runAsync(
        () => container
            .read(sessionProvider.notifier)
            .start(
              participant: 'P01',
              exercise: 'test',
              input: source,
              type: MeasurementSourceType.simulation,
              condition: ExperimentCondition.withAlerts,
              feedbackPolicy: FeedbackPolicy.keepChart,
            ),
      );
      await tester.runAsync(() async {
        source.emit(0);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(measurementBusProvider).totalEmitted, 1);
      expect(container.read(fatigueAlertProvider).isAlertActive, true);
      expect(find.byType(FatigueAlertWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => container.read(sessionProvider.notifier).stop(),
      );
      final rows = await tester.runAsync(() => db.db.query('alert_events'));
      expect(rows!.single['was_shown'], 1);
      expect(rows.single['was_dismissed_by_user'], 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    },
  );
  testWidgets(
    'alertas sustituidas antes del frame no se registran como mostradas',
    (tester) async {
      await tester.pumpWidget(
        app(const FatigueAlertManager(child: MonitoringScreen())),
      );
      await tester.runAsync(
        () => container
            .read(sessionProvider.notifier)
            .start(
              participant: 'P01',
              exercise: 'test',
              input: source,
              type: MeasurementSourceType.simulation,
              condition: ExperimentCondition.withAlerts,
              feedbackPolicy: FeedbackPolicy.keepChart,
              config: const FatigueConfig(cooldown: Duration.zero),
            ),
      );
      await tester.runAsync(() async {
        source.emit(0);
        source.emit(1);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FatigueAlertWidget), findsOneWidget);
      await tester.runAsync(
        () => container.read(sessionProvider.notifier).stop(),
      );
      final rows = await tester.runAsync(
        () => db.db.query('alert_events', orderBy: 'sequence'),
      );
      expect(rows!.map((row) => row['was_shown']), [0, 1]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    },
  );
  testWidgets(
    'preparación a 360px: campos accesibles, sin overflow y captura renderizada',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        app(RepaintBoundary(key: key, child: const SessionSetupScreen())),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Ejercicio'),
        'Flexión de codo',
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/review/session_setup.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.scrollUntilVisible(
        find.text('Iniciar sesión'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
