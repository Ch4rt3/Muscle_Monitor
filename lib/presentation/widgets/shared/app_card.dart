import 'package:flutter/material.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';

/// Card base del sistema de diseño.
///
/// Fondo `surface`, `radius.xl` (20px), sombra sutil. Todas las cards de
/// la app deben partir de este componente en vez de usar `Card` o
/// `Container` con estilos sueltos.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPaddingLarge),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlRadius,
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
