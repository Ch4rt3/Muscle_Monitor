# 🚨 Sistema de Alertas de Fatiga Muscular

## 📋 Descripción

Sistema modular de alertas en tiempo real basado en el nivel de fatiga muscular, integrado con el monitoreo EMG del sensor MyoWare 2.0 conectado vía ESP32.

## 🏗️ Arquitectura

El módulo sigue una arquitectura limpia y modular basada en Riverpod:

```
lib/features/alerts/
├── models/
│   └── alert_state.dart          # Estado de las alertas
├── providers/
│   └── fatigue_alert_provider.dart # Provider principal de alertas
├── utils/
│   └── fatigue_utils.dart         # Utilidades y configuraciones
├── widgets/
│   ├── fatigue_alert_manager.dart # Gestor de overlays
│   ├── fatigue_alert_widget.dart  # Widget animado de alerta
│   └── fatigue_indicator.dart     # Indicador de estado
└── alerts.dart                    # Barrel file
```

## 🎯 Umbrales de Fatiga

Basados en estudios de electromiografía con MyoWare 2.0:

| Nivel | Rango | Color | Comportamiento |
|-------|-------|-------|----------------|
| **Normal** | < 60% | Gris | Sin alerta |
| **Leve** | 60-75% | Naranja claro | Alerta informativa |
| **Moderada** | 76-89% | Naranja intenso | Alerta + vibración |
| **Severa** | ≥ 90% | Rojo | Alerta + vibración + sonido* |

*El sonido está configurado pero requiere implementación de audio player

## 🔧 Componentes Principales

### 1. FatigueAlertProvider
Provider que escucha el stream de datos BLE y evalúa los niveles de fatiga.

**Características:**
- Promedio móvil (ventana de 5 valores) para suavizar datos
- Cooldown de 5 segundos para evitar spam de alertas
- Conversión automática de valores EMG (0-255) a porcentaje

### 2. FatigueAlertManager
Gestor de overlays que muestra las alertas en pantalla.

**Características:**
- Usa `OverlayEntry` para no bloquear la UI
- Posicionamiento en la parte superior de la pantalla
- Auto-cierre configurable por nivel de alerta

### 3. FatigueAlertWidget
Widget animado que renderiza la alerta visual.

**Animaciones:**
- `SlideTransition`: Entrada desde arriba
- `FadeTransition`: Desvanecimiento
- `ScaleTransition`: Efecto elástico
- Icono con animación de pulso continuo

### 4. FatigueIndicator
Indicador visual permanente del estado actual de fatiga.

**Características:**
- Muestra porcentaje exacto de fatiga
- Barra circular de progreso
- Código de colores según nivel
- Integrado en la pantalla de monitoreo

## 📱 Integración

### En `main.dart`
```dart
return FatigueAlertManager(
  child: MaterialApp.router(
    routerConfig: AppRouter.router,
    theme: AppTheme().getTheme(),
  ),
);
```

### En `monitoring_screen.dart`
```dart
// Importar módulo
import 'package:muscle_monitoring/features/alerts/alerts.dart';

// Añadir indicador en la UI
const FatigueIndicator(),
```

## 🎨 Personalización

### Modificar umbrales de fatiga
Edita `lib/features/alerts/utils/fatigue_utils.dart`:

```dart
FatigueLevel getFatigueLevel(double fatigueValue) {
  if (fatigueValue >= 90) return FatigueLevel.high;
  if (fatigueValue >= 76) return FatigueLevel.medium;
  if (fatigueValue >= 60) return FatigueLevel.low;
  return FatigueLevel.none;
}
```

### Ajustar duración de alertas
Edita las configuraciones en `FatigueAlertConfigs`:

```dart
displayDuration: Duration(seconds: 5), // Cambiar duración
```

### Modificar cooldown
En `alert_state.dart`, ajusta el tiempo de cooldown:

```dart
if (elapsed.inSeconds < 5) { // Cambiar a tu valor preferido
  return false;
}
```

### Personalizar ventana del promedio móvil
En `fatigue_alert_provider.dart`:

```dart
final MovingAverage _movingAverage = MovingAverage(windowSize: 5); // Ajustar
```

## 🔄 Flujo de Datos

```
ESP32 (MyoWare 2.0)
    ↓
BleProvider (Stream<int> 0-255)
    ↓
FatigueAlertProvider
    ├─ Convierte a porcentaje
    ├─ Aplica promedio móvil
    ├─ Evalúa nivel de fatiga
    └─ Emite FatigueAlertState
        ↓
FatigueAlertManager (escucha cambios)
    ├─ Verifica cooldown
    ├─ Crea OverlayEntry
    └─ Muestra FatigueAlertWidget
```

## 🧪 Pruebas y Debugging

### Ver logs del provider
El provider imprime información útil:
```dart
print(state); // Muestra nivel, valor y estado activo
```

### Verificar valores
Añade un Consumer temporal:
```dart
Consumer(
  builder: (context, ref, _) {
    final alert = ref.watch(fatigueAlertProvider);
    return Text('Fatiga: ${alert.currentValue.toStringAsFixed(1)}%');
  },
)
```

### Simular valores de prueba
Modifica temporalmente `ble_provider.dart` para inyectar valores:
```dart
addFatiga(230.0); // Simular 90% de fatiga
```

## 🚀 Extensiones Futuras

### 1. Alertas por Fuerza
Duplicar la estructura para crear `ForceAlertProvider` con umbrales específicos.

### 2. Sonido de Alertas
Integrar `audioplayers` o `just_audio`:
```yaml
dependencies:
  audioplayers: ^5.0.0
```

### 3. Historial de Alertas
Crear un provider que almacene las alertas disparadas:
```dart
final alertHistoryProvider = StateProvider<List<AlertEvent>>((ref) => []);
```

### 4. Configuración Personalizable
Permitir al usuario ajustar los umbrales desde la UI.

### 5. Notificaciones Push
Integrar `flutter_local_notifications` para alertas en segundo plano.

## 📚 Referencias

- [MyoWare 2.0 Documentation](https://myoware.com)
- [Flutter Riverpod](https://riverpod.dev)
- [Electromiografía - Estudios de Fatiga](https://pubmed.ncbi.nlm.nih.gov)

## 👤 Mantenimiento

**Autor**: GitHub Copilot  
**Fecha**: Noviembre 2025  
**Versión**: 1.0.0

---

Para cualquier duda o mejora, consulta el código fuente directamente. Todos los archivos están ampliamente comentados.
