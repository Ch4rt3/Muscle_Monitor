---
name: project-design-system
description: Sistema de diseño visual específico de este proyecto Flutter (app de monitoreo muscular EMG), extraído de la imagen de referencia oficial. Úsala SIEMPRE que se cree, edite o revise cualquier pantalla, widget, componente, tema (ThemeData), color, tipografía, espaciado, ícono, sombra o animación de esta app — incluso si el usuario no menciona "diseño" explícitamente. Es de uso obligatorio antes de escribir cualquier código de UI en Flutter (widgets, screens, ThemeData, componentes reutilizables) para mantener consistencia visual con el lenguaje de la app. Consulta también cuando el usuario pida "una pantalla nueva", "un componente", "un botón", "una card", "un formulario", "un estado vacío/error/carga", o cualquier ajuste visual.
---

# Project Design System — App de Monitoreo Muscular EMG (Flutter)

Esta skill es la **fuente de verdad visual** del proyecto. La imagen de referencia
original (dashboard de monitoreo EMG con Bluetooth) ya no está disponible para
consultas futuras — **esta skill reemplaza a la imagen**. Todo lo que necesitas
para replicar su lenguaje visual está documentado aquí como reglas concretas y
tokens, no como descripciones vagas.

Cuando tengas que tomar una decisión de diseño que no está explícitamente
definida aquí, sigue este orden:
1. Infiere la solución más consistente con las reglas y tokens de este documento.
2. Reutiliza un token o componente ya definido antes de crear uno nuevo.
3. Evita introducir una decisión visual nueva si puedes lograr el mismo
   resultado con lo existente.
4. Mantén la consistencia entre todas las pantallas por encima de la
   originalidad puntual de una pantalla.

Si en algún punto dudas "¿esto encaja con el estilo de la app?", la respuesta
correcta casi siempre es la opción más silenciosa, limpia y menos decorativa.

---

## 1. Dirección visual

**Estilo:** healthtech / fitness-tech premium. Minimalismo funcional con datos
en primer plano — piensa "Apple Health x Oura x Whoop", no "dashboard SaaS
genérico" ni "Material Design de libro de texto".

**Sensación que transmite:** calma, precisión clínica, confianza. Es una app
que mide algo delicado (actividad muscular) y por eso el diseño evita el ruido
visual: pocos colores, mucho aire, datos legibles de un vistazo.

**Nivel de minimalismo:** alto. Una pantalla nunca tiene más de 1 acento de
color fuerte compitiendo con el teal principal (el rojo solo aparece para
fatiga/errores, nunca decorativo).

**Qué lo hace ver premium/moderno (replicar siempre):**
- Fondo gris muy claro (no blanco puro) + cards blancas puras → crea
  profundidad sin necesidad de bordes duros.
- Un único color de acento (teal) usado con disciplina: mismo teal en
  iconos activos, gráficas positivas, botones primarios, barra de progreso,
  estado "conectado". Nunca un teal distinto por pantalla.
- Radios de esquina grandes y consistentes en todo (cards, botones, sheets).
- Tipografía con jerarquía clara: números grandes y en negrita para las
  métricas clave (68%, 12%), todo lo demás en pesos medios/regulares.
- Sombras casi imperceptibles — dan elevación sin "flotar" agresivamente.
- Mucho espacio negativo entre secciones; nunca dos cards pegadas sin gap.
- Gráficas de línea minimalistas con relleno degradado sutil, sin ejes
  recargados ni grillas visibles.
- Estados (conectado/normal/fatiga) siempre comunicados con un punto de
  color + texto corto, nunca con badges ruidosos.

**Qué evitar para que NO parezca "UI genérica de IA" (lista negativa):**
- Gradientes multicolor decorativos de fondo.
- Iconos "rellenos" (filled) mezclados con outline en la misma pantalla.
- Sombras duras / oscuras / con offset grande.
- Bordes de colores random alrededor de cards.
- Emojis dentro de componentes de UI (el emoji 👋 en "¡Hola, Atleta!" es
  la ÚNICA excepción tolerada: un saludo humano en el home, nada más).
- Botones con esquinas distintas entre pantallas.
- Textos centrados por defecto (todo en esta app es left-aligned salvo
  estados vacíos/de éxito a pantalla completa).
- Cards con altura desigual que no respetan un ritmo vertical.

---

## 2. Layout

**Grid base:** unidad de espaciado = 4px. Usa siempre múltiplos de 4
(4, 8, 12, 16, 20, 24, 32, 40, 48).

**Márgenes de pantalla:** 20px horizontal (mínimo) a 24px en pantallas grandes.
El contenido nunca toca el borde de la pantalla.

**Padding interno de cards:** 16px en cards compactas (resumen rápido),
20px en cards principales (gráficas, estado de dispositivo).

**Espaciado vertical entre bloques/cards:** 12px entre elementos relacionados
(las dos cards de "Resumen rápido"), 16–20px entre secciones distintas
(de "Estado muscular" a "Resumen rápido").

**Alineación:** todo left-aligned. Los números de métricas grandes son
left-aligned igual que sus labels — nunca centrados dentro de la card.

**Jerarquía visual (de mayor a menor peso en una pantalla típica):**
1. Título de pantalla (app bar) — texto negro, bold, 20–22px.
2. Métrica/número hero de la card principal (68%, 12%) — 32–36px, bold.
3. Nombre de sección ("Estado muscular", "Resumen rápido") — 14–16px, semibold.
4. Texto de soporte / labels ("Buena", "Todo en rango saludable") — 12–13px,
   regular, gris.

**Espacio negativo:** es un elemento de diseño activo, no un descuido. Antes
de agregar un elemento nuevo a una pantalla, pregúntate si el espacio en
blanco ya está comunicando suficiente calma — no llenes huecos "porque sí".

**Bordes y radios (token único, reutilizar siempre):**
- Cards grandes / contenedores principales: `radius.xl` = 20px
- Cards pequeñas / chips de estado: `radius.lg` = 16px
- Botones (pill / full round): `radius.full` = 999px (altura completa)
- Inputs / campos: `radius.md` = 12px
- Iconos contenedores circulares (avatar bluetooth): círculo perfecto (50%)
- Bottom sheets: `radius.xl` = 20px solo en las esquinas superiores
- **Nunca mezclar radios distintos entre componentes del mismo tipo.**

**Tamaños aproximados de referencia:**
- Altura de botón primario: 52–56px
- Altura de item de lista / card compacta: 72–88px
- Icono contenedor circular (bluetooth): 48px de diámetro
- Ícono de barra de navegación: 24px
- Gráfica de línea (altura): ~120–140px dentro de su card
- Anillo de progreso circular (fatiga %): 56–64px de diámetro, stroke ~5px

---

## 3. Tipografía

**Familia recomendada para Flutter:** `Inter` (vía `google_fonts`). Es la que
mejor reproduce la geometría neutra y legible de la referencia. Si el
proyecto ya usa `Manrope` o la fuente de sistema (SF Pro / Roboto), esa es
aceptable también — pero **una sola familia para toda la app, sin mezclar**.

```dart
// pubspec.yaml
dependencies:
  google_fonts: ^6.2.1
```

**Escala tipográfica (nombre semántico → tamaño / peso / uso):**

| Token          | Tamaño | Peso (FontWeight) | Line height | Uso                                      |
|----------------|-------:|--------------------|-------------|-------------------------------------------|
| `display`      | 34     | w700 (bold)         | 1.15        | Número hero de métrica (68%, 12%)         |
| `headline`     | 22     | w700 (bold)         | 1.2         | Título de app bar / pantalla              |
| `titleLarge`   | 18     | w600 (semibold)     | 1.3         | Nombre de card destacada                  |
| `titleMedium`  | 16     | w600 (semibold)     | 1.3         | Nombre de sección ("Estado muscular")     |
| `bodyLarge`    | 15     | w400 (regular)      | 1.4         | Texto principal / nombre de dispositivo   |
| `bodyMedium`   | 14     | w400 (regular)      | 1.4         | Texto secundario general                  |
| `label`        | 13     | w500 (medium)       | 1.3         | Labels de estado ("Buena", "Conectado")   |
| `caption`      | 12     | w400 (regular)      | 1.3         | Texto de soporte, timestamps, hints       |
| `buttonText`   | 15     | w600 (semibold)     | 1.0         | Texto dentro de botones                   |

**Letter spacing:** neutro por defecto (0). Solo usar `+0.2` a `+0.4` en
labels en mayúsculas pequeñas si se necesitan (ninguna en la referencia
actual — evitar introducirlas salvo necesidad real).

**Reglas de uso:**
- Un número de métrica grande **siempre** va en `display`, negro/casi-negro,
  nunca en el color de acento (el color de acento va en el label debajo,
  ej. "Buena" en teal, "Baja" en rojo).
- Los títulos de sección van en `titleMedium`, color texto primario, sin
  íconos decorativos pegados salvo que aporten función (ej. corazón en
  "Estado muscular" si indica salud).
- El texto secundario/gris **nunca** compite en tamaño con el texto primario
  de la misma card — siempre un escalón más chico.
- Botones: texto centrado, `buttonText`, sin mayúsculas forzadas (usar
  capitalización normal como en la referencia: "Detener búsqueda", no
  "DETENER BÚSQUEDA").

---

## 4. Color — Design Tokens

Todos los valores están calibrados sobre la referencia. **No inventes colores
nuevos.** Si necesitas una variación (hover, disabled, etc.), derívala con
opacidad o `Color.lerp` del token existente más cercano, nunca con un hex
nuevo arbitrario.

```dart
// lib/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Superficies
  static const background   = Color(0xFFF5F6F8); // fondo general de pantalla
  static const surface      = Color(0xFFFFFFFF); // cards, sheets, app bar
  static const surfaceAlt   = Color(0xFFF0F1F3); // fondos secundarios sutiles (tracks de progreso, chips inactivos)

  // Texto
  static const textPrimary   = Color(0xFF1A1D1F); // títulos, números hero, cuerpo principal
  static const textSecondary = Color(0xFF8A8F98); // labels, captions, texto de soporte
  static const textDisabled  = Color(0xFFC2C6CC);

  // Acento primario (marca) — teal
  static const primary       = Color(0xFF14B8A6);
  static const primaryDark   = Color(0xFF0F9C8C); // pressed / gráfica línea fuerza
  static const primaryLight  = Color(0xFFE3F7F4); // fondos suaves de ícono, chip activo claro

  // Estados semánticos
  static const success      = Color(0xFF16A34A); // "Normal", check de éxito
  static const successBg    = Color(0xFFE9F9EF);
  static const warning      = Color(0xFFF59E0B); // reservado, no usado aún en la referencia
  static const warningBg    = Color(0xFFFEF3E2);
  static const error        = Color(0xFFEF4444); // fatiga, desconectar, "no se encontraron dispositivos"
  static const errorBg      = Color(0xFFFDECEC);

  // Bordes / divisores
  static const border       = Color(0xFFEBECEF);
  static const divider      = Color(0xFFEBECEF);

  // Sombra (usar SIEMPRE vía BoxShadow, nunca opacidades más altas que estas)
  static const shadowColor  = Color(0x14101828); // ~8% opacidad, tono azul-negro neutro
}
```

**Reglas de aplicación de color:**
- `primary` (teal) = única acción/estado positivo de la app: conectado,
  fuerza muscular, botones primarios, tab activo, barra de batería/señal
  buena, progreso circular saludable.
- `error` (rojo) = únicamente fatiga muscular, desconexión, estados de
  error/alerta. Nunca decorativo.
- `success` (verde) = estado textual "Normal" / confirmaciones de éxito.
  Es un verde distinto del teal a propósito — no lo confundas ni los
  intercambies.
- El fondo de pantalla es **siempre** `background`, nunca blanco puro —
  eso es lo que separa visualmente el fondo de las cards `surface`.
- Nunca uses más de 2 colores de acento (positivo + negativo) visibles al
  mismo tiempo en una pantalla, aparte de neutros.
- Los "colores de la app" que aparecen en el selector inferior (teal, azul,
  rosa, verde, gris) son **colores de producto físico** (personalización del
  dispositivo/branding), no tokens de UI — no los uses para botones, textos
  ni fondos de pantalla.

---

## 5. Componentes

Especificaciones detalladas, ejemplos de código Dart y reglas por
componente están en `references/component_specs.md`. Resumen obligatorio:

- **Buttons:** primario = fondo `primary`, texto blanco, `radius.full`,
  altura 52–56px, sin sombra o sombra mínima. Secundario/outline = borde
  1px `border` o del color semántico (ej. rojo para "Desconectar"/
  "Reintentar"), fondo transparente/`surface`, mismo radio y altura.
  Nunca botones cuadrados ni con esquinas distintas al resto de la app.
- **Cards:** fondo `surface`, `radius.xl` (20px), padding 16–20px, sombra
  sutil (`shadowColor`, blur 16–24, offset y=4–8, sin spread). Sin bordes
  visibles además de la sombra (no combinar border + shadow salvo cards
  seleccionables).
- **Inputs:** fondo `surfaceAlt` o `surface` con borde 1px `border`,
  `radius.md` (12px), altura 52px, label flotante o encima en `label`.
- **App bar:** transparente sobre `background`, título en `headline`
  left-aligned, un solo ícono de acción a la derecha (círculo sutil de
  fondo `surface` si es botón, sin sombra dura).
- **Navigation (bottom nav):** 3–4 ítems máx, ícono 24px + label 11–12px,
  activo en `primary`, inactivo en `textSecondary`, sin fondo destacado
  detrás del ítem activo (solo color de ícono/texto cambia).
- **Chips:** solo para estado (conectado/desconectado), `radius.full`,
  padding horizontal 10–12px, fondo `primaryLight`/`errorBg` según estado,
  punto de color + texto en `label`.
- **Dialogs / confirmación de conexión:** `surface`, `radius.xl`, ícono o
  imagen del dispositivo arriba, lista de checks con ícono `success` +
  texto corto, CTA primario + CTA secundario tipo texto/outline debajo.
- **Bottom sheets:** esquinas superiores `radius.xl`, handle bar gris
  centrado arriba (4px alto, 36px ancho, `surfaceAlt`), mismo padding
  20px que las pantallas.
- **Lists:** items con padding vertical 12–16px, divisor `divider` de 1px
  o separación por espacio (preferir espacio antes que línea cuando se
  pueda, como en "Última sesión").
- **Empty states:** ícono grande circular con fondo `primaryLight` o
  `errorBg`, título `titleLarge`, texto de soporte `bodyMedium` gris,
  CTA primario debajo. Centrado vertical y horizontalmente, mucho aire.
- **Loading states:** animación sutil (radar/pulso en `primary`, o barra
  de progreso lineal `primary` sobre `surfaceAlt`), texto corto debajo en
  `bodyMedium`, nunca spinners genéricos de Material sin personalizar el
  color.
- **Error states:** ícono circular fondo `errorBg`, ícono `error`, título
  `titleLarge`, texto `bodyMedium` gris, CTA "Reintentar" en outline rojo
  + CTA secundario "Ayuda" en texto plano.
- **Floating actions:** evitar FAB flotante tradicional de Material salvo
  necesidad clara — la referencia resuelve acciones primarias con botones
  de ancho completo al pie de la pantalla, no con FAB circular.
- **Icons:** ver sección 6.

---

## 6. Iconografía

- **Estilo:** outline (línea), nunca filled, nunca duotono.
- **Set recomendado en Flutter:** `lucide_icons` o `phosphor_flutter`
  (variante "light"/"regular"). Evitar Material Icons por defecto (se ven
  genéricos) salvo que no exista equivalente.
- **Grosor de trazo:** 1.5–1.75px equivalente — consistente en toda la app.
- **Tamaño:** 24px en navegación y app bar, 20px dentro de filas de texto/
  listas, 28–32px dentro de contenedores circulares de estado.
- **Color:** `primary` cuando el ícono es la acción/estado activo,
  `textSecondary` cuando es neutro/inactivo, `error`/`success` solo para
  estados semánticos explícitos.
- **Cuándo usar íconos:** para reforzar una acción o estado (batería,
  señal, Bluetooth, corazón de estado muscular, flecha de navegación).
  **Cuándo NO usarlos:** como relleno decorativo, junto a cada texto sin
  función, o duplicando información que el texto ya comunica con claridad.
- **Alineación:** siempre centrados verticalmente respecto al texto que
  acompañan; en filas ícono+texto, gap fijo de 8–12px.

---

## 7. Sombras y profundidad

- Usar sombras **muy sutiles**, casi imperceptibles — dan separación de
  plano, no dramatismo.
- Valores de referencia (Flutter `BoxShadow`):
  ```dart
  BoxShadow(
    color: AppColors.shadowColor, // ~8% opacidad
    blurRadius: 20,
    offset: Offset(0, 6),
    spreadRadius: 0,
  )
  ```
- **Elevación por tipo de componente:**
  - Cards en listas/dashboard: sombra sutil (arriba).
  - Botones primarios: sin sombra o sombra mínima (blur 8, offset y=2)
    solo si el fondo es muy similar al del botón.
  - Bottom sheets / dialogs: sombra algo más presente (blur 24–32,
    offset y=8) porque flotan sobre overlay oscuro.
  - Bottom navigation: sombra muy leve hacia arriba o simplemente un
    borde superior de 1px `border` — preferir esto último si hay dudas.
- **Cuándo evitar sombra:** entre elementos dentro de una misma card
  (nunca sombra interna), en chips/badges pequeños, en textos, en íconos
  sueltos.
- Nunca combinar sombra fuerte + borde fuerte en el mismo elemento —
  elige una sola señal de profundidad por componente.

---

## 8. Motion / animaciones

La referencia sugiere una app fluida pero discreta — la animación apoya la
comprensión de datos, nunca decora porque sí.

- **Duración estándar:** 200–300ms para transiciones de UI (fade, slide
  de pantallas, expansión de cards). 400–600ms para elementos de "espera
  activa" (radar de búsqueda de dispositivo).
- **Curvas:** `Curves.easeOutCubic` para entradas, `Curves.easeInCubic`
  para salidas, `Curves.easeInOutCubic` para transiciones de estado
  (ej. barra de progreso cambiando de valor).
- **Transiciones de pantalla:** slide horizontal estándar de iOS/Cupertino
  para navegación jerárquica (Buscar dispositivo → Dispositivos
  encontrados); fade+scale sutil para modales/dialogs de confirmación.
- **Microinteracciones a animar:**
  - Botones: leve escala (0.97) al presionar, 100ms.
  - Gráficas de línea: dibujo progresivo al entrar a la pantalla (~600ms).
  - Progreso circular (fatiga %): animar el arco desde 0 hasta el valor.
  - Radar de búsqueda: barrido rotatorio continuo + pulso de ondas
    concéntricas, loop suave.
  - Check de éxito ("Conexión exitosa"): scale-in con leve bounce
    (`Curves.elasticOut`, usar con moderación, una sola vez).
  - Cambios de estado (conectado/desconectado, normal/fatiga): fade
    cruzado del color/ícono, 200ms.
- **Qué evitar:** animaciones de rebote exageradas, parallax decorativo,
  confetti/partículas, rotaciones o "wiggle" sin función, cualquier
  animación que tarde más de ~600ms y bloquee la interacción.

---

## 9. Responsive

- **Teléfonos pequeños (~360dp de ancho):** reducir margen horizontal a
  16px, `display` baja a 30px, cards mantienen mismo radio pero padding
  interno baja a 14px. Nunca reducir el tamaño de touch targets.
- **Teléfonos grandes (~430dp+):** margen horizontal sube a 24px, el
  ancho máximo de contenido de texto/gráficas puede limitarse a ~600px
  lógicos si se usa en modo landscape.
- **Tablets:** usar `LayoutBuilder`/`MediaQuery` para pasar de 1 columna
  a 2 columnas en el grid de "Resumen rápido" y en listas de dispositivos;
  mantener el mismo ancho máximo de card (no estirar cards a todo el
  ancho de una pantalla de 1000dp+). Bottom nav puede migrar a rail
  lateral en tablets grandes, conservando los mismos tokens de color/ícono.
- En todos los tamaños: mantener proporciones de radio y spacing (no
  escalar el radio de 20px a algo distinto solo por el tamaño de pantalla).

---

## 10. Accesibilidad

- **Contraste:** `textPrimary` sobre `background`/`surface` ya cumple
  AA cómodo. Nunca bajar `textSecondary` por debajo de un gris que
  cumpla 4.5:1 sobre blanco (el token dado ya está calibrado — no oscurecer
  ni aclarar sin verificar contraste).
- **Touch targets:** mínimo 44x44px (iOS) / 48x48dp (Android) para
  cualquier elemento tocable, incluidos íconos de acción en app bar y
  ítems de bottom nav, aunque el ícono visual sea más chico (usar padding
  para completar el área táctil).
- **Legibilidad:** nunca bajar de 12px (`caption`) para texto con
  información real (no decorativo); evitar texto gris sobre `surfaceAlt`
  si el contraste resultante es bajo — usar `textPrimary` en ese caso.
- **Estados de foco:** todo elemento interactivo (botón, input, ítem de
  lista seleccionable) debe tener un estado de foco visible — anillo de
  2px en `primary` con offset 2px, sin depender solo del color de fondo.
- **Labels:** todo ícono sin texto visible (ej. ícono de notificación,
  botón de back) necesita `Semantics`/`tooltip` con label descriptivo en
  español ("Notificaciones", "Volver").
- **Feedback de errores:** nunca comunicar error solo con color —
  siempre acompañar con ícono `error` + texto explicativo corto (como en
  "No se encontraron dispositivos"), y ofrecer una acción de recuperación
  clara (botón "Reintentar").

---

## 11. Flutter — cómo implementar el sistema

Archivos de referencia con código completo (leerlos antes de escribir
`ThemeData` o componentes nuevos):

- `references/design_tokens.dart` — `AppColors`, `AppSpacing`,
  `AppRadius`, `AppShadows`, `AppDurations` listos para copiar/importar.
- `references/app_theme.dart` — `ThemeData` completo con `ColorScheme`,
  `TextTheme`, estilos de botones/inputs/app bar/bottom nav ya
  configurados a partir de los tokens.
- `references/component_specs.md` — specs y snippets Dart por componente
  (botones, cards, chips de estado, empty/error/loading states, etc.)
  con ejemplos de código listos para adaptar.

**Flujo de trabajo esperado del agente al crear una pantalla nueva:**
1. Importar y usar `AppColors`, `AppSpacing`, `AppRadius` — nunca hex
   literales ni valores mágicos de padding/radio en el widget.
2. Usar `Theme.of(context).textTheme.<token>` para todo texto (los
   tokens de la sección 3 ya están mapeados en `app_theme.dart`).
3. Componer la pantalla con los componentes ya definidos en
   `component_specs.md` (card base, botón primario/secundario, chip de
   estado) en vez de construir desde cero widgets visualmente distintos.
4. Si el componente que necesitas no existe todavía, créalo siguiendo
   los tokens de esta skill y agrégalo a `component_specs.md` para que
   quede disponible para la próxima pantalla (evita duplicar variantes).
5. Antes de entregar, revisar contra la sección `Anti-patterns` (12).

**ThemeExtension:** usar un `ThemeExtension` propio (`AppSemanticColors`)
para exponer `success`/`warning`/`error` con sus fondos, ya que
`ColorScheme` de Material no modela bien 3 estados semánticos con fondo
suave — ver ejemplo en `references/app_theme.dart`.

---

## 12. Anti-patterns (prohibido)

El agente **no debe**:

1. Inventar colores nuevos fuera de `AppColors` sin que exista una
   necesidad semántica real (y si existe, agregarlo como token nombrado,
   no como hex suelto en el widget).
2. Crear un estilo visual distinto por pantalla ("esta pantalla la hago
   más colorida"). Toda pantalla nueva reutiliza los mismos tokens.
3. Usar gradientes decorativos arbitrarios de fondo. Los únicos degradados
   permitidos son los rellenos sutiles bajo las líneas de gráficas
   (mismo color del token, opacidad decreciente).
4. Abusar de sombras: máximo una sombra por componente, siempre sutil
   (ver sección 7). Nada de sombras múltiples o "glow".
5. Llenar la interfaz de cards. Si dos piezas de información pueden vivir
   en el mismo bloque visual sin perder claridad, no las separes en dos
   cards distintas.
6. Usar radios de esquina inconsistentes (mezclar 8px, 12px, 16px, 20px
   sin criterio). Usar siempre los tokens de radio de la sección 2.
7. Cambiar la jerarquía tipográfica definida en la sección 3 (por ejemplo,
   poner un label en el mismo tamaño que un título de sección).
8. Crear botones visualmente distintos entre pantallas sin una razón
   semántica (primario/secundario/destructivo son las únicas 3
   variantes válidas).
9. Introducir elementos decorativos que no existen en este lenguaje
   visual: ilustraciones grandes genéricas de stock, patrones de fondo,
   iconografía 3D, glassmorphism, neumorphism, emojis fuera del saludo
   del home.
10. Generar una pantalla que se sienta como una plantilla genérica de
    Flutter (Material por defecto sin personalizar, `Card` con elevación
    default de 1, `AppBar` azul por defecto, `FloatingActionButton`
    circular estándar sin razón). Todo debe pasar por los tokens de esta
    skill.
11. Sacrificar consistencia por un elemento "visualmente llamativo" que
    no está respaldado por esta skill — si algo se ve interesante pero no
    encaja con las reglas de arriba, no se usa.

---

## Checklist rápido antes de entregar una pantalla nueva

- [ ] ¿Usa `AppColors`, `AppSpacing`, `AppRadius` en vez de valores mágicos?
- [ ] ¿El fondo de pantalla es `background`, no blanco puro?
- [ ] ¿Hay como máximo un acento positivo (teal) y uno negativo (rojo)
      visibles a la vez?
- [ ] ¿Los radios de todos los componentes del mismo tipo coinciden?
- [ ] ¿La jerarquía tipográfica sigue la tabla de la sección 3?
- [ ] ¿Las sombras son sutiles y como máximo una por componente?
- [ ] ¿Los botones usan una de las 3 variantes válidas (primario/
      secundario/destructivo)?
- [ ] ¿Los touch targets cumplen 44–48px mínimo?
- [ ] ¿Evité emojis, gradientes decorativos, glassmorphism, íconos
      filled mezclados con outline?
