/// Widget que muestra el estado actual de fatiga en la pantalla de monitoreo
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/features/alerts/alerts.dart';

/// Indicador visual del nivel de fatiga actual
class FatigueIndicator extends ConsumerWidget {
  const FatigueIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertState = ref.watch(fatigueAlertProvider);
    final level = alertState.currentLevel;
    final value = alertState.currentValue;
    final textTheme = Theme.of(context).textTheme;

    final color = _getColor(level);
    final bgColor = _getBgColor(level);

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
          Icon(
            _getIcon(level),
            color: color,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getLevelText(level),
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
          _buildFatigueRing(value, color, textTheme),
        ],
      ),
    );
  }

  Color _getColor(FatigueLevel level) {
    return switch (level) {
      FatigueLevel.none => AppColors.success,
      FatigueLevel.low => AppColors.warning,
      FatigueLevel.medium => AppColors.warning,
      FatigueLevel.high => AppColors.error,
    };
  }

  Color _getBgColor(FatigueLevel level) {
    return switch (level) {
      FatigueLevel.none => AppColors.successBg,
      FatigueLevel.low => AppColors.warningBg,
      FatigueLevel.medium => AppColors.warningBg,
      FatigueLevel.high => AppColors.errorBg,
    };
  }

  IconData _getIcon(FatigueLevel level) {
    return switch (level) {
      FatigueLevel.none => Icons.favorite_outline,
      FatigueLevel.low => Icons.info_outline,
      FatigueLevel.medium => Icons.warning_amber_outlined,
      FatigueLevel.high => Icons.error_outline,
    };
  }

  String _getLevelText(FatigueLevel level) {
    return switch (level) {
      FatigueLevel.none => 'Estado Normal',
      FatigueLevel.low => 'Fatiga Leve',
      FatigueLevel.medium => 'Fatiga Moderada',
      FatigueLevel.high => 'Fatiga Severa',
    };
  }

  Widget _buildFatigueRing(
    double value,
    Color color,
    TextTheme textTheme,
  ) {
    return SizedBox(
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
              Text(
                'Fatiga',
                style: textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
