/// Gestor central de alertas de fatiga
/// Maneja la visualización de alertas como overlays en pantalla
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/features/alerts/providers/fatigue_alert_provider.dart';
import 'package:muscle_monitoring/features/alerts/utils/fatigue_utils.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_alert_widget.dart';

/// Widget que gestiona la visualización de alertas de fatiga
/// Debe ser colocado en la parte superior del árbol de widgets
class FatigueAlertManager extends ConsumerStatefulWidget {
  final Widget child;

  const FatigueAlertManager({super.key, required this.child});

  @override
  ConsumerState<FatigueAlertManager> createState() =>
      _FatigueAlertManagerState();
}

class _FatigueAlertManagerState extends ConsumerState<FatigueAlertManager> {
  OverlayEntry? _currentOverlay;
  FatigueLevel? _lastShownLevel;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  /// Muestra una alerta como overlay
  void _showAlert(FatigueAlertConfig config) {
    // Remover alerta anterior si existe
    _removeOverlay();

    // Crear nuevo overlay
    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: FatigueAlertWidget(
            config: config,
            onDismiss: () {
              _removeOverlay();
              // Notificar al provider que la alerta fue cerrada
              ref.read(fatigueAlertProvider.notifier).dismissAlert();
            },
          ),
        ),
      ),
    );

    // Insertar en el overlay
    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Remueve el overlay actual
  void _removeOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en el estado de alertas
    ref.listen(fatigueAlertProvider, (previous, next) {
      // Si hay una alerta activa y es de un nivel diferente al último mostrado
      if (next.isAlertActive) {
        final config = getAlertConfig(next.currentLevel);

        // Solo mostrar si hay configuración y es un nivel diferente
        if (config != null && next.currentLevel != _lastShownLevel) {
          _lastShownLevel = next.currentLevel;
          _showAlert(config);
        }
      } else {
        // Si no hay alerta activa, remover overlay
        if (next.currentLevel == FatigueLevel.none) {
          _removeOverlay();
          _lastShownLevel = null;
        }
      }
    });

    // Renderizar el widget hijo normalmente
    return widget.child;
  }
}
