import 'package:flutter/material.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';

/// Contenedor circular para ícono Bluetooth / dispositivo.
///
/// 48px de diámetro, fondo `primaryLight`, ícono `primary` centrado.
class BluetoothIconContainer extends StatelessWidget {
  final double size;
  final IconData icon;

  const BluetoothIconContainer({
    super.key,
    this.size = 48,
    this.icon = Icons.bluetooth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 24),
    );
  }
}
