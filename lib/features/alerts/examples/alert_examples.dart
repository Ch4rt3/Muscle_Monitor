/// Ejemplo de implementación personalizada de alertas
/// Este archivo muestra cómo crear alertas personalizadas para diferentes casos de uso
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/features/alerts/alerts.dart';

/// EJEMPLO 1: Widget que muestra un resumen de alertas disparadas en la sesión
class AlertsSummaryWidget extends ConsumerWidget {
  const AlertsSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertState = ref.watch(fatigueAlertProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado de Fatiga',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Nivel Actual:',
              _getLevelName(alertState.currentLevel),
              _getLevelColor(alertState.currentLevel),
            ),
            _buildInfoRow(
              'Valor:',
              '${alertState.currentValue.toStringAsFixed(1)}%',
              Colors.grey,
            ),
            if (alertState.lastAlertTime != null)
              _buildInfoRow(
                'Última Alerta:',
                _formatTime(alertState.lastAlertTime!),
                Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getLevelName(FatigueLevel level) {
    switch (level) {
      case FatigueLevel.none:
        return 'Normal';
      case FatigueLevel.low:
        return 'Leve';
      case FatigueLevel.medium:
        return 'Moderada';
      case FatigueLevel.high:
        return 'Severa';
    }
  }

  Color _getLevelColor(FatigueLevel level) {
    final config = getAlertConfig(level);
    return config?.color ?? Colors.grey;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) {
      return 'Hace ${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes}m';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// EJEMPLO 2: Botón para probar alertas manualmente (útil para desarrollo)
class TestAlertButton extends ConsumerWidget {
  final FatigueLevel levelToTest;

  const TestAlertButton({super.key, required this.levelToTest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        // Simular un valor que active la alerta
        final testValue = _getTestValue(levelToTest);
        // Nota: Esto requeriría exponer un método en el provider
        // o simular datos en ble_provider
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Para probar, establece fatiga en ${testValue.toStringAsFixed(0)}%',
            ),
          ),
        );
      },
      child: Text('Probar ${_getLevelName(levelToTest)}'),
    );
  }

  double _getTestValue(FatigueLevel level) {
    switch (level) {
      case FatigueLevel.low:
        return 65;
      case FatigueLevel.medium:
        return 80;
      case FatigueLevel.high:
        return 95;
      case FatigueLevel.none:
        return 30;
    }
  }

  String _getLevelName(FatigueLevel level) {
    switch (level) {
      case FatigueLevel.none:
        return 'Normal';
      case FatigueLevel.low:
        return 'Leve';
      case FatigueLevel.medium:
        return 'Moderada';
      case FatigueLevel.high:
        return 'Severa';
    }
  }
}

/// EJEMPLO 3: Badge que muestra el estado actual de fatiga
class FatigueBadge extends ConsumerWidget {
  const FatigueBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(currentFatigueLevelProvider);
    final isActive = ref.watch(hasActiveAlertProvider);

    if (level == FatigueLevel.none) {
      return const SizedBox.shrink();
    }

    final config = getAlertConfig(level);
    if (config == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: config.color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            _getLevelText(level),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getLevelText(FatigueLevel level) {
    switch (level) {
      case FatigueLevel.none:
        return '';
      case FatigueLevel.low:
        return 'Fatiga Leve';
      case FatigueLevel.medium:
        return 'Fatiga Moderada';
      case FatigueLevel.high:
        return 'Fatiga Severa';
    }
  }
}

/// EJEMPLO 4: Pantalla de prueba para visualizar todas las alertas
class AlertTestScreen extends StatelessWidget {
  const AlertTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba de Alertas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Panel de Control de Alertas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const AlertsSummaryWidget(),
          const SizedBox(height: 16),
          const Text(
            'Probar Alertas:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              TestAlertButton(levelToTest: FatigueLevel.low),
              TestAlertButton(levelToTest: FatigueLevel.medium),
              TestAlertButton(levelToTest: FatigueLevel.high),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Badge de Estado:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: FatigueBadge()),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '📝 Notas de Desarrollo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Las alertas se activan automáticamente con datos reales\n'
                    '• Para pruebas, modifica temporalmente ble_provider.dart\n'
                    '• Umbrales: 60% (leve), 76% (moderada), 90% (severa)\n'
                    '• Cooldown de 5 segundos entre alertas del mismo nivel',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* 
 * USO DE EJEMPLOS:
 * 
 * 1. Para añadir el resumen de alertas:
 *    const AlertsSummaryWidget()
 * 
 * 2. Para añadir el badge en la AppBar:
 *    actions: [
 *      const FatigueBadge(),
 *      const SizedBox(width: 16),
 *    ]
 * 
 * 3. Para navegar a la pantalla de pruebas:
 *    Navigator.push(
 *      context,
 *      MaterialPageRoute(builder: (_) => const AlertTestScreen()),
 *    )
 */
