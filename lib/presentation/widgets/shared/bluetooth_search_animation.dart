import 'package:flutter/material.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';

/// Animación de radar/pulso para la búsqueda de dispositivos BLE.
///
/// Muestra un ícono Bluetooth centrado con anillos concéntricos que se
/// expanden y desvanecen, simulando un escaneo de radar. Basado en el
/// mockup de referencia del proyecto.
class BluetoothSearchAnimation extends StatefulWidget {
  /// Tamaño total del widget (ancho y alto).
  final double size;

  const BluetoothSearchAnimation({
    super.key,
    this.size = 200,
  });

  @override
  State<BluetoothSearchAnimation> createState() =>
      _BluetoothSearchAnimationState();
}

class _BluetoothSearchAnimationState extends State<BluetoothSearchAnimation>
    with TickerProviderStateMixin {
  static const _ringCount = 3;

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnimations;
  late final List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(_ringCount, (index) {
      return AnimationController(
        duration: AppMotion.searchLoop,
        vsync: this,
      );
    });

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.6, end: 0.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      );
    }).toList();

    // Iniciar cada anillo con un delay escalonado
    for (var i = 0; i < _ringCount; i++) {
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (mounted) {
          _controllers[i].repeat();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.size;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anillos de radar (de atrás hacia adelante)
          for (var i = 0; i < _ringCount; i++)
            AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, _) {
                return Transform.scale(
                  scale: _scaleAnimations[i].value,
                  child: Container(
                    width: ringSize,
                    height: ringSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary
                            .withAlpha((_fadeAnimations[i].value * 255).toInt()),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Círculo interior (fondo sólido)
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bluetooth,
              color: AppColors.primary,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
