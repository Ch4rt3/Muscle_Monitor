import 'package:flutter/material.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';

/// Estado vacío, de error o de éxito reutilizable.
///
/// Ícono grande en círculo de fondo suave, título, texto de soporte,
/// CTA primario y CTA secundario opcional. Todo centrado con espacio generoso.
class EmptyErrorState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Variante de estilo del botón primario.
  /// Si es `true`, usa `OutlinedButton` con color semántico (para errores).
  /// Si es `false`, usa `ElevatedButton` estándar (para éxito/vacío).
  final bool outlinePrimaryButton;
  final Color? primaryButtonColor;

  const EmptyErrorState({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.outlinePrimaryButton = false,
    this.primaryButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono en círculo
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Título
            Text(
              title,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtítulo
            Text(
              subtitle,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            // CTA primario
            if (primaryActionLabel != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: outlinePrimaryButton
                    ? OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              primaryButtonColor ?? AppColors.error,
                          side: BorderSide(
                            color: primaryButtonColor ?? AppColors.error,
                          ),
                        ),
                        onPressed: onPrimaryAction,
                        child: Text(primaryActionLabel!),
                      )
                    : ElevatedButton(
                        onPressed: onPrimaryAction,
                        child: Text(primaryActionLabel!),
                      ),
              ),
            ],

            // CTA secundario
            if (secondaryActionLabel != null) ...[
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
