// Design tokens del proyecto — generados a partir de la skill
// `project-design-system`. Importar estos archivos en vez de usar
// valores mágicos (hex, px sueltos) en los widgets.
//
// Ubicación sugerida en el proyecto: lib/theme/design_tokens.dart

import 'package:flutter/material.dart';

/// Paleta de colores del sistema. No agregar colores nuevos aquí sin que
/// exista una necesidad semántica real — ver SKILL.md sección 4.
class AppColors {
  AppColors._();

  // Superficies
  static const background = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F1F3);

  // Texto
  static const textPrimary = Color(0xFF1A1D1F);
  static const textSecondary = Color(0xFF8A8F98);
  static const textDisabled = Color(0xFFC2C6CC);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // Acento primario (marca) — teal
  static const primary = Color(0xFF14B8A6);
  static const primaryDark = Color(0xFF0F9C8C);
  static const primaryLight = Color(0xFFE3F7F4);

  // Estados semánticos
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFE9F9EF);
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFEF3E2);
  static const error = Color(0xFFEF4444);
  static const errorBg = Color(0xFFFDECEC);

  // Bordes / divisores
  static const border = Color(0xFFEBECEF);
  static const divider = Color(0xFFEBECEF);

  // Sombra base (usar siempre con esta opacidad, no más oscura)
  static const shadowColor = Color(0x14101828); // ~8% opacidad
}

/// Escala de espaciado — unidad base 4px. Usar siempre estos valores en
/// vez de números sueltos de padding/margin/gap.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;

  /// Margen horizontal estándar de pantalla.
  static const screenHorizontal = xl; // 20.0
  /// Padding interno de cards principales (gráficas, dispositivo).
  static const cardPaddingLarge = xl; // 20.0
  /// Padding interno de cards compactas (resumen rápido).
  static const cardPaddingCompact = lg; // 16.0
  /// Gap entre cards relacionadas dentro de una misma sección.
  static const cardGap = md; // 12.0
  /// Gap entre secciones distintas de una pantalla.
  static const sectionGap = lg; // 16.0–20.0 según densidad
}

/// Radios de esquina — reutilizar siempre el mismo token para el mismo
/// tipo de componente en toda la app.
class AppRadius {
  AppRadius._();

  static const md = 12.0; // inputs, chips pequeños
  static const lg = 16.0; // cards compactas, badges de estado
  static const xl = 20.0; // cards principales, dialogs, bottom sheets
  static const full = 999.0; // botones tipo pill, avatares circulares

  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get fullRadius => BorderRadius.circular(full);

  /// Bottom sheets: solo esquinas superiores redondeadas.
  static const bottomSheet = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
}

/// Sombras estándar por tipo de componente — ver SKILL.md sección 7.
class AppShadows {
  AppShadows._();

  /// Cards en listas / dashboard.
  static const card = [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  /// Botones primarios (usar solo si el botón necesita separarse del
  /// fondo; por defecto los botones no llevan sombra).
  static const button = [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Dialogs y bottom sheets (flotan sobre overlay oscuro).
  static const overlay = [
    BoxShadow(
      color: AppColors.shadowColor,
      blurRadius: 28,
      offset: Offset(0, 8),
    ),
  ];

  /// Sin sombra — usar explícitamente en vez de omitir, para dejar claro
  /// que fue una decisión intencional.
  static const none = <BoxShadow>[];
}

/// Duraciones y curvas de animación estándar — ver SKILL.md sección 8.
class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 450);
  static const searchLoop = Duration(milliseconds: 1800);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const stateChangeCurve = Curves.easeInOutCubic;
  static const successBounceCurve = Curves.elasticOut;
}
