/// Widget que muestra el estado actual de fatiga en la pantalla de monitoreo
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/features/alerts/alerts.dart';

/// Indicador visual del nivel de fatiga actual
class FatigueIndicator extends ConsumerWidget {
  const FatigueIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertState = ref.watch(fatigueAlertProvider);
    final level = alertState.currentLevel;
    final value = alertState.currentValue;

    // Obtener configuración visual según el nivel
    final config = getAlertConfig(level);
    final color = config?.color ?? Colors.grey.shade400;
    final icon = config?.icon ?? Icons.favorite_border;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getLevelText(level),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fatiga: ${value.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          _buildFatigueBar(value, color),
        ],
      ),
    );
  }

  String _getLevelText(FatigueLevel level) {
    switch (level) {
      case FatigueLevel.none:
        return 'Estado Normal';
      case FatigueLevel.low:
        return 'Fatiga Leve';
      case FatigueLevel.medium:
        return 'Fatiga Moderada';
      case FatigueLevel.high:
        return 'Fatiga Severa';
    }
  }

  Widget _buildFatigueBar(double value, Color color) {
    return SizedBox(
      width: 60,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Barra de progreso circular
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          // Porcentaje en el centro
          Text(
            '${value.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
