// ┌──────────────────────────────────────────────────────────────────┐
// │  ARCHIVO TEMPORAL DE DEMOSTRACIÓN — ELIMINAR ANTES DE RELEASE  │
// │  Muestra todas las pantallas y estados del design system        │
// │  sin necesitar un dispositivo BLE real.                         │
// └──────────────────────────────────────────────────────────────────┘

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/features/alerts/utils/fatigue_utils.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_alert_widget.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/app_card.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/bluetooth_icon_container.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/bluetooth_search_animation.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/status_chip.dart';

// ─── Demo entry point ────────────────────────────────────────────────

class DemoGallery extends StatefulWidget {
  const DemoGallery({super.key});

  @override
  State<DemoGallery> createState() => _DemoGalleryState();
}

class _DemoGalleryState extends State<DemoGallery> {
  int _currentPage = 0;

  final _pages = const <_DemoPage>[
    _DemoPage(title: 'Buscando…', icon: Icons.bluetooth_searching),
    _DemoPage(title: 'Encontrados', icon: Icons.devices),
    _DemoPage(title: 'Conectar?', icon: Icons.link),
    _DemoPage(title: 'Conectando', icon: Icons.sync),
    _DemoPage(title: 'Éxito', icon: Icons.check_circle_outline),
    _DemoPage(title: 'Monitoreo', icon: Icons.show_chart),
    _DemoPage(title: 'Fatiga Leve', icon: Icons.info_outline),
    _DemoPage(title: 'Fatiga Alta', icon: Icons.error_outline),
    _DemoPage(title: 'Alerta', icon: Icons.warning_amber),
    _DemoPage(title: 'Sin conexión', icon: Icons.bluetooth_disabled),
    _DemoPage(title: 'Sin resultados', icon: Icons.search_off),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentPage,
        children: const [
          _SearchingStateDemo(),       // 0
          _DevicesFoundDemo(),         // 1
          _ConnectionDialogDemo(),     // 2
          _ConnectingStateDemo(),      // 3
          _ConnectionSuccessDemo(),    // 4
          _MonitoringActiveDemo(),     // 5
          _FatigueLowDemo(),           // 6
          _FatigueHighDemo(),          // 7
          _AlertOverlayDemo(),         // 8
          _DisconnectedDemo(),         // 9
          _NoDevicesFoundDemo(),       // 10
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final page = _pages[index];
                final isSelected = _currentPage == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          page.icon,
                          size: 18,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _currentPage = index),
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: AppColors.surfaceAlt,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoPage {
  final String title;
  final IconData icon;
  const _DemoPage({required this.title, required this.icon});
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 1: Buscando dispositivos — con animación radar
// ═══════════════════════════════════════════════════════════════════════

class _SearchingStateDemo extends StatelessWidget {
  const _SearchingStateDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar dispositivo')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animación de radar
                    const BluetoothSearchAnimation(size: 200),

                    const SizedBox(height: AppSpacing.xxl),

                    Text(
                      'Buscando dispositivos...',
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Asegúrate de que tu dispositivo\nesté encendido y cerca.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Detener búsqueda'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 2: Dispositivos encontrados
// ═══════════════════════════════════════════════════════════════════════

class _DevicesFoundDemo extends StatelessWidget {
  const _DevicesFoundDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
        title: const Text('Dispositivos encontrados'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.lg,
              ),
              children: [
                _MockDeviceCard(
                  name: 'ESP32 EMG',
                  id: 'A4:CF:12:34:56:78',
                  rssi: -65,
                  status: 'idle',
                  textTheme: textTheme,
                ),
                _MockDeviceCard(
                  name: 'MyoWare Sensor 2',
                  id: 'A4:CF:12:8B:3E:02',
                  rssi: -72,
                  status: 'idle',
                  textTheme: textTheme,
                ),
                _MockDeviceCard(
                  name: 'Dispositivo desconocido',
                  id: 'C8:3A:52:F1:AA:10',
                  rssi: -85,
                  status: 'idle',
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Detener búsqueda'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Seleccionar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 3: Diálogo de conexión — ¿Conectar con ESP32 EMG?
// ═══════════════════════════════════════════════════════════════════════

class _ConnectionDialogDemo extends StatelessWidget {
  const _ConnectionDialogDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Buscar dispositivo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícono del dispositivo
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.developer_board,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  '¿Conectar con\nESP32 EMG?',
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A4:CF:12:34:56:78',
                  style: textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Beneficios
                _ConnectionFeature(
                  icon: Icons.check,
                  text: 'Enviar datos EMG en tiempo real',
                  textTheme: textTheme,
                ),
                const SizedBox(height: AppSpacing.md),
                _ConnectionFeature(
                  icon: Icons.check,
                  text: 'Ver estado de batería',
                  textTheme: textTheme,
                ),
                const SizedBox(height: AppSpacing.md),
                _ConnectionFeature(
                  icon: Icons.check,
                  text: 'Mantener conexión estable',
                  textTheme: textTheme,
                ),

                const SizedBox(height: AppSpacing.xxl),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Conectar'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () {},
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionFeature extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextTheme textTheme;

  const _ConnectionFeature({
    required this.icon,
    required this.text,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.success, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(text, style: textTheme.bodyLarge),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 4: Conectando a dispositivo
// ═══════════════════════════════════════════════════════════════════════

class _ConnectingStateDemo extends StatelessWidget {
  const _ConnectingStateDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar dispositivo')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.lg,
              ),
              children: [
                _MockDeviceCard(
                  name: 'ESP32 EMG',
                  id: 'A4:CF:12:34:56:78',
                  rssi: -65,
                  status: 'connecting',
                  textTheme: textTheme,
                ),
                Opacity(
                  opacity: 0.5,
                  child: _MockDeviceCard(
                    name: 'MyoWare Sensor 2',
                    id: 'A4:CF:12:8B:3E:02',
                    rssi: -72,
                    status: 'idle',
                    textTheme: textTheme,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Cancelar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 5: Conexión exitosa
// ═══════════════════════════════════════════════════════════════════════

class _ConnectionSuccessDemo extends StatelessWidget {
  const _ConnectionSuccessDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono de éxito con anillo verde
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Text(
                'Conexión exitosa',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ya puedes comenzar a\nmonitorear tus músculos.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Ir a monitoreo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 6: Monitoreo activo (datos normales)
// ═══════════════════════════════════════════════════════════════════════

class _MonitoringActiveDemo extends StatelessWidget {
  const _MonitoringActiveDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Monitoreo'),
            floating: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Configuración',
                  onPressed: () {},
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.sm),

                // Chips de estado
                const Row(
                  children: [
                    StatusChip(
                      label: 'Tiempo real',
                      color: AppColors.primary,
                      background: AppColors.primaryLight,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    StatusChip(
                      label: 'Conectado',
                      color: AppColors.success,
                      background: AppColors.successBg,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                // Indicador fatiga normal
                _MockFatigueIndicator(
                  level: FatigueLevel.none,
                  value: 12,
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                // Gráfica de Fuerza
                Text('Fuerza muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChart(
                  color: AppColors.primary,
                  lastValue: 68,
                  statusLabel: 'Buena',
                  seed: 1,
                ),

                const SizedBox(height: AppSpacing.sectionGap),

                // Gráfica de Fatiga
                Text('Fatiga muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChart(
                  color: AppColors.error,
                  lastValue: 12,
                  statusLabel: 'Baja',
                  seed: 2,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 7: Monitoreo con fatiga leve
// ═══════════════════════════════════════════════════════════════════════

class _FatigueLowDemo extends StatelessWidget {
  const _FatigueLowDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Monitoreo'),
            floating: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.sm),

                const Row(
                  children: [
                    StatusChip(
                      label: 'Tiempo real',
                      color: AppColors.primary,
                      background: AppColors.primaryLight,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    StatusChip(
                      label: 'Conectado',
                      color: AppColors.success,
                      background: AppColors.successBg,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                _MockFatigueIndicator(
                  level: FatigueLevel.low,
                  value: 38,
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                Text('Fuerza muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChart(
                  color: AppColors.primary,
                  lastValue: 52,
                  statusLabel: 'Moderada',
                  seed: 3,
                ),

                const SizedBox(height: AppSpacing.sectionGap),

                Text('Fatiga muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChart(
                  color: AppColors.error,
                  lastValue: 38,
                  statusLabel: 'Leve',
                  seed: 4,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 8: Monitoreo con fatiga alta
// ═══════════════════════════════════════════════════════════════════════

class _FatigueHighDemo extends StatelessWidget {
  const _FatigueHighDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Monitoreo'),
            floating: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.sm),

                const Row(
                  children: [
                    StatusChip(
                      label: 'Tiempo real',
                      color: AppColors.primary,
                      background: AppColors.primaryLight,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    StatusChip(
                      label: 'Conectado',
                      color: AppColors.success,
                      background: AppColors.successBg,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                _MockFatigueIndicator(
                  level: FatigueLevel.high,
                  value: 82,
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                Text('Fuerza muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChart(
                  color: AppColors.primary,
                  lastValue: 25,
                  statusLabel: 'Baja',
                  seed: 5,
                ),

                const SizedBox(height: AppSpacing.sectionGap),

                Text('Fatiga muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChart(
                  color: AppColors.error,
                  lastValue: 82,
                  statusLabel: 'Severa',
                  seed: 6,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 9: Alerta overlay
// ═══════════════════════════════════════════════════════════════════════

class _AlertOverlayDemo extends StatelessWidget {
  const _AlertOverlayDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo: pantalla de monitoreo
          CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Monitoreo'),
                floating: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: AppSpacing.sm),
                    const Row(
                      children: [
                        StatusChip(
                          label: 'Tiempo real',
                          color: AppColors.primary,
                          background: AppColors.primaryLight,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        StatusChip(
                          label: 'Conectado',
                          color: AppColors.success,
                          background: AppColors.successBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    _MockFatigueIndicator(
                      level: FatigueLevel.high,
                      value: 78,
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    Text('Fuerza muscular', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    _MockChart(
                      color: AppColors.primary,
                      lastValue: 30,
                      statusLabel: 'Baja',
                      seed: 7,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ]),
                ),
              ),
            ],
          ),

          // Overlay: alerta de fatiga
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: FatigueAlertWidget(
              config: FatigueAlertConfigs.high,
              onDismiss: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 10: Sin conexión (esperando)
// ═══════════════════════════════════════════════════════════════════════

class _DisconnectedDemo extends StatelessWidget {
  const _DisconnectedDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Monitoreo'),
            floating: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: AppSpacing.sm),

                const Row(
                  children: [
                    StatusChip(
                      label: 'Esperando conexión',
                      color: AppColors.textSecondary,
                      background: AppColors.surfaceAlt,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                _MockFatigueIndicator(
                  level: FatigueLevel.none,
                  value: 0,
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                Text('Fuerza muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChartEmpty(
                  label: 'Esperando datos de fuerza...',
                ),

                const SizedBox(height: AppSpacing.sectionGap),

                Text('Fatiga muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MockChartEmpty(
                  label: 'Esperando datos de fatiga...',
                ),

                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Estado 11: No se encontraron dispositivos (error)
// ═══════════════════════════════════════════════════════════════════════

class _NoDevicesFoundDemo extends StatelessWidget {
  const _NoDevicesFoundDemo();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar dispositivo')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono de error
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.errorBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'No se encontraron\ndispositivos',
                      style: textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Verifica que el Bluetooth esté\nactivado e intenta nuevamente.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () {},
                    child: const Text('Reintentar'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () {},
                  child: const Text('Ayuda'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Componentes mock reutilizables
// ═══════════════════════════════════════════════════════════════════════

class _MockDeviceCard extends StatelessWidget {
  final String name;
  final String id;
  final int rssi;
  final String status; // 'idle', 'connecting', 'connected'
  final TextTheme textTheme;

  const _MockDeviceCard({
    required this.name,
    required this.id,
    required this.rssi,
    required this.status,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    Widget trailing = switch (status) {
      'connecting' => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      'connected' => const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 24,
        ),
      _ => Text('$rssi dBm', style: textTheme.labelSmall),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.cardPaddingCompact),
        child: Row(
          children: [
            const BluetoothIconContainer(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(id, style: textTheme.labelSmall),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _MockFatigueIndicator extends StatelessWidget {
  final FatigueLevel level;
  final double value;

  const _MockFatigueIndicator({
    required this.level,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final (color, bgColor, icon, label) = switch (level) {
      FatigueLevel.none => (
          AppColors.success,
          AppColors.successBg,
          Icons.favorite_outline,
          'Estado Normal',
        ),
      FatigueLevel.low => (
          AppColors.warning,
          AppColors.warningBg,
          Icons.info_outline,
          'Fatiga Leve',
        ),
      FatigueLevel.medium => (
          AppColors.warning,
          AppColors.warningBg,
          Icons.warning_amber_outlined,
          'Fatiga Moderada',
        ),
      FatigueLevel.high => (
          AppColors.error,
          AppColors.errorBg,
          Icons.error_outline,
          'Fatiga Severa',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.xlRadius,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Fatiga: ${value.toStringAsFixed(1)}%',
                  style: textTheme.labelSmall?.copyWith(
                    color: color.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
          // Anillo
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: value / 100,
                    strokeWidth: 5,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${value.toStringAsFixed(0)}%',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('Fatiga', style: textTheme.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockChart extends StatelessWidget {
  final Color color;
  final double lastValue;
  final String statusLabel;
  final int seed;

  const _MockChart({
    required this.color,
    required this.lastValue,
    required this.statusLabel,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rng = Random(seed);
    final points = List<FlSpot>.generate(80, (i) {
      final noise = (rng.nextDouble() - 0.5) * 20;
      final trend = lastValue + sin(i * 0.1) * 10 + noise;
      return FlSpot(i.toDouble(), trend.clamp(0, 100));
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${lastValue.toStringAsFixed(0)}%',
                style: textTheme.displaySmall,
              ),
              const Spacer(),
              Icon(
                Icons.open_in_full,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            statusLabel,
            style: textTheme.labelMedium?.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                minX: 0,
                maxX: 80,
                lineTouchData: const LineTouchData(enabled: false),
                clipData: const FlClipData.all(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    dotData: const FlDotData(show: false),
                    color: color,
                    barWidth: 2.5,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withAlpha(60),
                          color.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ],
                titlesData: const FlTitlesData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockChartEmpty extends StatelessWidget {
  final String label;
  const _MockChartEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('--', style: textTheme.displaySmall),
              const Spacer(),
              Icon(
                Icons.open_in_full,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sin datos',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 140,
            child: Center(
              child: Text(label, style: textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
