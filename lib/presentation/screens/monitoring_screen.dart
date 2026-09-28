import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';

import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/presentation/providers/ble_provider.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/app_card.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/status_chip.dart';
import 'package:muscle_monitoring/features/alerts/alerts.dart';

class MonitoringScreen extends StatelessWidget {
  static const name = 'monitoring-screen';

  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: _MonitoringScreenView());
  }
}

class _MonitoringScreenView extends ConsumerWidget {
  const _MonitoringScreenView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleProvider);
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.session;
    var deviceName = bleState.currentDevice?.advName;
    final isConnected =
        bleState.connectionState == BleConnectionState.connected;

    if (deviceName != null && deviceName.isEmpty) {
      deviceName = 'dispositivo';
    }

    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('Monitoreo'),
          floating: true,
          actions: [
            if (!sessionState.active)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Herramientas del investigador',
                  onPressed: () => context.push('/research'),
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
              if (!sessionState.active)
                ElevatedButton(
                  onPressed: () => context.push('/session/setup'),
                  child: const Text('Preparar sesión'),
                ),
              if (session != null) ...[
                Text(
                  '${session.source.name == 'simulation'
                      ? 'Simulación'
                      : session.source.name == 'replay'
                      ? 'Reproducción'
                      : 'Sesión BLE'} · ${session.showInterpretation ? 'Con alertas' : 'Sin alertas'}',
                ),
                ElevatedButton(
                  onPressed: sessionState.busy
                      ? null
                      : () async {
                          await ref.read(sessionProvider.notifier).stop();
                          if (context.mounted) context.go('/session/end');
                        },
                  child: Text(
                    sessionState.busy ? 'Guardando…' : 'Finalizar sesión',
                  ),
                ),
                if (session.source != MeasurementSourceType.ble)
                  TextButton(
                    onPressed: () => context.push('/diagnostics'),
                    child: const Text('Ver diagnóstico'),
                  ),
              ],
              if (sessionState.error != null) Text(sessionState.error!),

              // Estado de conexión
              Row(
                children: [
                  if (isConnected) ...[
                    const StatusChip(
                      label: 'Tiempo real',
                      color: AppColors.primary,
                      background: AppColors.primaryLight,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusChip(
                      label: 'Conectado',
                      color: AppColors.success,
                      background: AppColors.successBg,
                    ),
                  ] else
                    const StatusChip(
                      label: 'Esperando conexión',
                      color: AppColors.textSecondary,
                      background: AppColors.surfaceAlt,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // Indicador de fatiga
              if (session?.showInterpretation == true) const FatigueIndicator(),

              const SizedBox(height: AppSpacing.sectionGap),

              // Card de Fuerza
              Text('Fuerza muscular', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _MetricChart(
                color: AppColors.primary,
                getPoints: (ref) => ref.watch(bleProvider).dataFuerza,
                emptyLabel: 'Esperando datos de fuerza...',
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // Card de Fatiga
              if (session?.showChart != false) ...[
                Text('Fatiga muscular', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MetricChart(
                  color: AppColors.error,
                  getPoints: (ref) => ref.watch(bleProvider).dataFatiga,
                  emptyLabel: 'Esperando datos de fatiga...',
                  isFatigue: true,
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ]),
          ),
        ),
      ],
    );
  }
}

typedef PointsSelector = List<BleDataPoint> Function(WidgetRef ref);

class _MetricChart extends ConsumerWidget {
  final Color color;
  final PointsSelector getPoints;
  static const int visiblePoints = 120;
  final String emptyLabel;
  final bool isFatigue;

  const _MetricChart({
    required this.color,
    required this.getPoints,
    required this.emptyLabel,
    this.isFatigue = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = getPoints(ref);
    final recent = data.length <= visiblePoints
        ? data
        : data.sublist(data.length - visiblePoints);

    final points = List<FlSpot>.generate(recent.length, (i) {
      return FlSpot(i.toDouble(), recent[i].y);
    });

    final lastValue = recent.isNotEmpty ? recent.last.y : null;

    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Valor hero
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lastValue != null ? '${lastValue.toStringAsFixed(0)}%' : '--',
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
          if (!isFatigue ||
              ref.watch(sessionProvider).session?.showInterpretation == true)
            Text(
              lastValue != null
                  ? _getStatusLabel(
                      lastValue,
                      ref.watch(sessionProvider).session?.config ??
                          FatigueConfig.defaultConfig,
                    )
                  : 'Sin datos',
              style: textTheme.labelMedium?.copyWith(color: color),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Gráfica
          SizedBox(
            height: 140,
            child: points.isNotEmpty
                ? LineChart(
                    LineChartData(
                      minY: points
                          .map((e) => e.y)
                          .reduce((a, b) => a < b ? a : b),
                      maxY: points
                          .map((e) => e.y)
                          .reduce((a, b) => a > b ? a : b),
                      minX: 0,
                      maxX: visiblePoints.toDouble(),
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
                              colors: [color.withAlpha(60), color.withAlpha(0)],
                            ),
                          ),
                        ),
                      ],
                      titlesData: const FlTitlesData(show: false),
                    ),
                  )
                : Center(child: Text(emptyLabel, style: textTheme.bodyMedium)),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(double value, FatigueConfig config) {
    if (color == AppColors.error) {
      // Fatiga
      return switch (getFatigueLevel(value, config: config)) {
        FatigueLevel.none => 'Baja',
        FatigueLevel.low => 'Leve',
        FatigueLevel.medium => 'Moderada',
        FatigueLevel.high => 'Severa',
      };
    } else {
      // Fuerza
      if (value >= 70) return 'Buena';
      if (value >= 40) return 'Moderada';
      return 'Baja';
    }
  }
}
