import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

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
            if (isConnected)
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
              const FatigueIndicator(),

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
              Text('Fatiga muscular', style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _MetricChart(
                color: AppColors.error,
                getPoints: (ref) => ref.watch(bleProvider).dataFatiga,
                emptyLabel: 'Esperando datos de fatiga...',
              ),

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

  const _MetricChart({
    required this.color,
    required this.getPoints,
    required this.emptyLabel,
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
                lastValue != null
                    ? '${lastValue.toStringAsFixed(0)}%'
                    : '--',
                style: textTheme.displaySmall,
              ),
              const Spacer(),
              Icon(Icons.open_in_full, size: 20, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            lastValue != null
                ? _getStatusLabel(lastValue)
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
                  )
                : Center(
                    child: Text(
                      emptyLabel,
                      style: textTheme.bodyMedium,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(double value) {
    if (color == AppColors.error) {
      // Fatiga
      if (value >= 75) return 'Severa';
      if (value >= 50) return 'Moderada';
      if (value >= 30) return 'Leve';
      return 'Baja';
    } else {
      // Fuerza
      if (value >= 70) return 'Buena';
      if (value >= 40) return 'Moderada';
      return 'Baja';
    }
  }
}
