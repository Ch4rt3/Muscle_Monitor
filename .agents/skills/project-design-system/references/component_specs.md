# Component Specs — project-design-system

Specs y snippets Dart por componente. Leer junto con `design_tokens.dart`
y `app_theme.dart`. Adaptar, no reinventar: si necesitas una variante que
no está aquí, créala siguiendo los mismos tokens y agrégala a este archivo.

---

## Botón primario

Fondo `AppColors.primary`, texto blanco, `radius.full`, alto 52–56px,
ancho completo salvo que dos botones compartan fila. Sin sombra o sombra
mínima (`AppShadows.button`) solo si el fondo detrás es muy parecido.

```dart
ElevatedButton(
  onPressed: onPressed,
  child: const Text('Ir a monitoreo'),
)
// El estilo ya viene de ElevatedButtonThemeData en app_theme.dart —
// no sobreescribir shape/radius/color en el widget salvo excepción real.
```

## Botón secundario / outline

Borde 1px `AppColors.border` (neutro) o del color semántico (`error` para
"Desconectar"/"Reintentar"), fondo transparente, mismo alto y radio que
el primario.

```dart
OutlinedButton(
  onPressed: onPressed,
  style: OutlinedButton.styleFrom(
    foregroundColor: AppColors.error,
    side: const BorderSide(color: AppColors.error),
  ),
  child: const Text('Desconectar'),
)
```

## Botón de texto plano

Para acciones terciarias tipo "Ayuda", "Cancelar". Sin fondo, sin borde,
texto `AppColors.textSecondary`, mismo alto táctil (48px mínimo).

```dart
TextButton(
  onPressed: onPressed,
  child: const Text('Ayuda'),
)
```

---

## Card base

Todas las cards de la app parten de este mismo contenedor. `radius.xl`
(20px), fondo `surface`, sombra sutil, sin borde adicional.

```dart
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
```

**Card compacta** (ej. items de "Resumen rápido"): mismo widget con
`padding: const EdgeInsets.all(AppSpacing.cardPaddingCompact)` y
`borderRadius: AppRadius.lgRadius` si necesita verse más chica.

---

## Card de métrica hero (ej. "Fuerza muscular 68%")

```dart
AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Fuerza muscular', style: textTheme.titleMedium),
          Icon(LucideIcons.expand, size: 20, color: AppColors.textSecondary),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text('68%', style: textTheme.displaySmall),
      const SizedBox(height: AppSpacing.xs),
      Text('Buena', style: textTheme.labelMedium?.copyWith(color: AppColors.primary)),
      const SizedBox(height: AppSpacing.lg),
      // Gráfica de línea aquí (fl_chart), color AppColors.primary,
      // relleno degradado de AppColors.primary con opacidad decreciente.
    ],
  ),
)
```

Para la variante negativa (fatiga), usar `AppColors.error` en vez de
`AppColors.primary` para el label y la línea/relleno de la gráfica —
nunca cambiar el resto del layout.

---

## Chip de estado (conectado / normal / fatiga)

`radius.full`, punto de color + texto corto, fondo suave del color
semántico.

```dart
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.fullRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// Uso:
// StatusChip(label: 'Conectado', color: AppColors.primary, background: AppColors.primaryLight)
// StatusChip(label: 'Normal', color: AppColors.success, background: AppColors.successBg)
```

---

## Progreso circular (ej. "12% Fatiga")

Anillo 56–64px, stroke ~5px, color según severidad (`success`/`warning`/
`error`), fondo del track en `AppColors.surfaceAlt`, valor numérico
centrado en `titleMedium` bold + label chico debajo.

```dart
SizedBox(
  width: 64,
  height: 64,
  child: Stack(
    alignment: Alignment.center,
    children: [
      CircularProgressIndicator(
        value: fatiguePercent / 100,
        strokeWidth: 5,
        backgroundColor: AppColors.surfaceAlt,
        valueColor: AlwaysStoppedAnimation(AppColors.success),
      ),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$fatiguePercent%', style: textTheme.titleMedium),
          Text('Fatiga', style: textTheme.labelSmall),
        ],
      ),
    ],
  ),
)
```

---

## Ícono contenedor circular (avatar Bluetooth / dispositivo)

48px de diámetro, fondo `primaryLight`, ícono `primary` 24px centrado.

```dart
Container(
  width: 48,
  height: 48,
  decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
  child: const Icon(LucideIcons.bluetooth, color: AppColors.primary, size: 24),
)
```

---

## App bar

Fondo transparente sobre `background`, título left-aligned en
`headlineSmall`, máximo un ícono de acción a la derecha dentro de un
círculo sutil si necesita fondo.

```dart
AppBar(
  title: const Text('Monitoreo'),
  actions: [
    IconButton(
      icon: const Icon(LucideIcons.settings),
      tooltip: 'Configuración',
      onPressed: onSettings,
    ),
  ],
)
// Estilo ya viene de AppBarTheme — no agregar elevation ni color manual.
```

---

## Bottom navigation

3 ítems, ícono 24px + label 12px, activo en `primary`, inactivo en
`textSecondary`, sin fondo destacado detrás del activo.

```dart
BottomNavigationBar(
  currentIndex: currentIndex,
  onTap: onTap,
  items: const [
    BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Inicio'),
    BottomNavigationBarItem(icon: Icon(LucideIcons.activity), label: 'Monitoreo'),
    BottomNavigationBarItem(icon: Icon(LucideIcons.bluetooth), label: 'Dispositivo'),
  ],
)
```

---

## Dialog de confirmación (ej. "¿Conectar con ESP32 EMG?")

`radius.xl`, imagen/ícono del elemento arriba, lista de checks (ícono
`success` 16px + texto `bodyMedium`), CTA primario + CTA texto debajo,
padding 24px.

```dart
Dialog(
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // imagen/ícono del dispositivo
        const SizedBox(height: AppSpacing.lg),
        Text('¿Conectar con ESP32 EMG?', style: textTheme.titleLarge),
        Text('A4:CF:12:34:56:78', style: textTheme.labelSmall),
        const SizedBox(height: AppSpacing.lg),
        ...checks.map((c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(LucideIcons.check, size: 16, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Text(c, style: textTheme.bodyMedium),
                ],
              ),
            )),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(onPressed: onConnect, child: const Text('Conectar')),
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
      ],
    ),
  ),
)
```

---

## Bottom sheet

Handle bar centrado (4px alto x 36px ancho, `surfaceAlt`, radius full),
esquinas superiores `radius.xl`, mismo padding horizontal 20px que las
pantallas.

```dart
showModalBottomSheet(
  context: context,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
  builder: (_) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadius.fullRadius,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // contenido
      ],
    ),
  ),
);
```

---

## Empty state / Error state

Ícono grande (56–64px) dentro de círculo de fondo suave
(`primaryLight`/`errorBg`), título `titleLarge`, texto de soporte
`bodyMedium` gris, CTA primario debajo (+ CTA "Ayuda" en texto plano si
aplica). Todo centrado, con generoso espacio vertical.

```dart
Center(
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.xxxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88, height: 88,
          decoration: const BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
          child: const Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 32),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('No se encontraron dispositivos', style: textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Verifica que el Bluetooth esté activado e intenta nuevamente.',
          style: textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
          onPressed: onRetry,
          child: const Text('Reintentar'),
        ),
        TextButton(onPressed: onHelp, child: const Text('Ayuda')),
      ],
    ),
  ),
)
```

Para el estado de éxito ("Conexión exitosa"), mismo layout con
`successBg`/`success` y un ícono de check, animado con scale-in
(`AppMotion.successBounceCurve`).

---

## Loading state (búsqueda de dispositivo / radar)

Círculos concéntricos animados en `primary` con opacidad decreciente,
barrido rotatorio continuo (`AppMotion.searchLoop`, loop, sin easing
brusco), texto de estado `bodyLarge` + texto de soporte `bodyMedium`
debajo, botón "Detener búsqueda" (outline neutro) + "Ayuda" (texto).

Para loading lineal (ej. barra de batería/progreso mientras carga):
usar `LinearProgressIndicator` con `color: AppColors.primary`,
`backgroundColor: AppColors.surfaceAlt`, `borderRadius` aplicado con
`ClipRRect` (`AppRadius.fullRadius`) — nunca el indicador cuadrado por
defecto de Material.

---

## Lista de dispositivos / ítems (ej. "Dispositivos encontrados")

Item = ícono contenedor circular + nombre (`bodyLarge`) + subtítulo
(`labelSmall`, ej. MAC address) + indicador de señal a la derecha
(`textSecondary`). Padding vertical 12–16px, separación por espacio o
`Divider` fino, nunca ambos.

```dart
ListTile(
  contentPadding: EdgeInsets.zero,
  leading: /* avatar circular Bluetooth */,
  title: Text('ESP32 EMG', style: textTheme.bodyLarge),
  subtitle: Text('A4:CF:12:34:56:78', style: textTheme.labelSmall),
  trailing: Text('-45 dBm', style: textTheme.labelSmall),
)
```
