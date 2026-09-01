/// Widget de alerta de fatiga con animaciones sutiles del design system
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/features/alerts/utils/fatigue_utils.dart';

/// Widget animado que muestra una alerta de fatiga como overlay
class FatigueAlertWidget extends StatefulWidget {
  final FatigueAlertConfig config;
  final VoidCallback? onDismiss;

  const FatigueAlertWidget({super.key, required this.config, this.onDismiss});

  @override
  State<FatigueAlertWidget> createState() => _FatigueAlertWidgetState();
}

class _FatigueAlertWidgetState extends State<FatigueAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: AppMotion.standard,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve),
    );

    _controller.forward();

    if (widget.config.shouldVibrate) {
      HapticFeedback.mediumImpact();
    }

    Future.delayed(widget.config.displayDuration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.sm,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.xlRadius,
              boxShadow: AppShadows.overlay,
              border: Border(
                left: BorderSide(
                  color: widget.config.color,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                // Ícono con fondo suave
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.config.color.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.config.icon,
                    color: widget.config.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.config.title,
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.config.message,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                // Botón de cierre
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: 'Cerrar alerta',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
