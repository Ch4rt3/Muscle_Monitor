# ❓ Preguntas Frecuentes (FAQ) - Sistema de Alertas de Fatiga

## 🚀 Instalación y Configuración

### ¿Necesito instalar dependencias adicionales?
**No.** El sistema utiliza únicamente las dependencias ya presentes en el proyecto:
- `flutter_riverpod` (manejo de estado)
- `flutter` (widgets y animaciones)

### ¿Cómo activo el sistema de alertas?
**Automáticamente.** El sistema se activa al iniciar la app. No requiere configuración adicional. Solo necesitas:
1. Conectar un dispositivo BLE con el sensor MyoWare 2.0
2. Los datos de fatiga fluirán automáticamente
3. Las alertas aparecerán cuando sea necesario

### ¿Dónde está integrado el sistema?
En dos lugares:
1. **`main.dart`**: El `FatigueAlertManager` envuelve toda la app
2. **`monitoring_screen.dart`**: El `FatigueIndicator` muestra el estado permanente

---

## 🎯 Funcionamiento

### ¿Cómo se calcula el porcentaje de fatiga?
```dart
// El MyoWare 2.0 envía valores de 0-255
// Se convierte a porcentaje (0-100)
percentage = (valorEMG / 255) * 100
```

### ¿Qué es el "promedio móvil"?
Es un filtro que suaviza las fluctuaciones de los datos para evitar falsas alarmas.

**Ejemplo:**
```
Valores brutos: 85, 92, 88, 90, 87
Promedio móvil: 88.4% (ventana de 5 valores)
```

### ¿Por qué usar promedio móvil?
Sin él, las lecturas fluctúan mucho:
```
Sin filtro:  [85] [92] [88] [90] [87] → 5 evaluaciones separadas
Con filtro:  ────────[ 88.4 ]──────── → 1 evaluación suavizada
```

### ¿Cuándo se dispara una alerta?
Cuando el **promedio móvil** de fatiga supera estos umbrales:
- **60-75%**: Alerta Leve 🟡
- **76-89%**: Alerta Moderada 🟠
- **≥90%**: Alerta Severa 🔴

### ¿Por qué no veo alertas aunque la fatiga sea alta?
Revisa estos puntos:
1. ✅ ¿El valor está por encima del 60%?
2. ✅ ¿Han pasado 5 segundos desde la última alerta del mismo nivel?
3. ✅ ¿Estás viendo el promedio móvil o el valor instantáneo?

---

## ⚙️ Personalización

### ¿Cómo cambio los umbrales de fatiga?
Edita `lib/features/alerts/utils/fatigue_utils.dart`:

```dart
FatigueLevel getFatigueLevel(double fatigueValue) {
  if (fatigueValue >= 85) return FatigueLevel.high;    // Era 90
  if (fatigueValue >= 70) return FatigueLevel.medium;  // Era 76
  if (fatigueValue >= 55) return FatigueLevel.low;     // Era 60
  return FatigueLevel.none;
}
```

### ¿Cómo cambio el tiempo de cooldown?
Edita `lib/features/alerts/models/alert_state.dart`:

```dart
bool shouldShowAlert(FatigueLevel newLevel) {
  // ... código existente ...
  
  if (lastAlertTime != null) {
    final elapsed = DateTime.now().difference(lastAlertTime!);
    if (elapsed.inSeconds < 10) { // Cambia 5 a 10 segundos
      return false;
    }
  }
  
  return true;
}
```

### ¿Cómo ajusto la ventana del promedio móvil?
Edita `lib/features/alerts/providers/fatigue_alert_provider.dart`:

```dart
final MovingAverage _movingAverage = MovingAverage(windowSize: 10); // Era 5
```

**⚠️ Nota:** Ventanas más grandes = respuesta más lenta pero más estable.

### ¿Cómo cambio los colores de las alertas?
Edita `lib/features/alerts/utils/fatigue_utils.dart`:

```dart
static const medium = FatigueAlertConfig(
  color: Color(0xFF9C27B0), // Púrpura en lugar de naranja
  // ... resto del código
);
```

### ¿Cómo cambio la duración de las alertas?
```dart
static const high = FatigueAlertConfig(
  displayDuration: Duration(seconds: 10), // Era 5 segundos
  // ... resto del código
);
```

---

## 🐛 Troubleshooting

### "Las alertas no aparecen"

**Posibles causas:**

1. **No hay datos de fatiga llegando**
   ```dart
   // Verifica en la consola:
   print(ref.watch(bleProvider).dataFatiga.length);
   // Si es 0, el problema está en BLE, no en alertas
   ```

2. **El valor está por debajo del umbral**
   ```dart
   // Añade logging temporal:
   print('Fatiga actual: ${alertState.currentValue}%');
   ```

3. **El FatigueAlertManager no está integrado**
   ```dart
   // Verifica que main.dart contenga:
   return FatigueAlertManager(
     child: MaterialApp.router(...),
   );
   ```

### "Las alertas se muestran demasiado frecuentemente"

**Soluciones:**
1. Aumenta el cooldown (ver arriba)
2. Aumenta la ventana del promedio móvil
3. Ajusta los umbrales más altos

### "Las alertas no se cierran automáticamente"

**Verifica:**
1. Que `displayDuration` esté configurado
2. Que el widget no tenga errores de animación

**Debug:**
```dart
// En FatigueAlertWidget, añade:
print('Alerta auto-cerrada en ${widget.config.displayDuration}');
```

### "El indicador de fatiga muestra 0% siempre"

**Causas comunes:**
1. No hay datos de fatiga del BLE
2. El provider no está escuchando correctamente

**Solución:**
```dart
// En monitoring_screen.dart, añade debug:
Consumer(
  builder: (context, ref, _) {
    final ble = ref.watch(bleProvider);
    return Text('Datos fatiga: ${ble.dataFatiga.length}');
  },
)
```

### "Error de compilación: Type 'FatigueAlertState' not found"

**Solución:**
Asegúrate de importar el módulo:
```dart
import 'package:muscle_monitoring/features/alerts/alerts.dart';
```

---

## 🧪 Testing

### ¿Cómo pruebo las alertas sin el hardware?

**Opción 1: Modificar temporalmente ble_provider.dart**
```dart
// En connectDevice(), después de las características BLE:
_simTimer?.cancel();
_simTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
  final fa = 150 + _rand.nextInt(105).toDouble(); // 60-100%
  addFatiga(fa);
});
```

**Opción 2: Usar el widget de prueba**
```dart
// Navega a la pantalla de pruebas:
import 'package:muscle_monitoring/features/alerts/examples/alert_examples.dart';

Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AlertTestScreen()),
);
```

### ¿Cómo verifico que el promedio móvil funciona?

Añade logging temporal en `fatigue_alert_provider.dart`:
```dart
void _updateAlertState(FatigueLevel newLevel, double value) {
  print('Raw: ${rawValue.toStringAsFixed(1)} | Smooth: ${value.toStringAsFixed(1)} | Level: $newLevel');
  // ... resto del código
}
```

---

## 📊 Optimización

### ¿El sistema consume mucha batería?
**No.** Las alertas solo se procesan cuando hay datos nuevos del BLE. No hay timers constantes.

### ¿Afecta el rendimiento de la app?
**Mínimamente.** El sistema usa:
- 1 listener en el provider BLE
- Cálculos simples (promedio de 5 valores)
- Overlays nativos de Flutter (muy eficientes)

### ¿Cómo reduzco el uso de memoria?
El sistema ya está optimizado:
- Solo guarda 5 valores en el promedio móvil
- No almacena historial de alertas (se pueden añadir si es necesario)
- Los overlays se destruyen automáticamente

---

## 🔮 Extensiones Futuras

### ¿Cómo añado sonido a las alertas?

1. Añade la dependencia:
```yaml
dependencies:
  audioplayers: ^5.0.0
```

2. Modifica `FatigueAlertWidget`:
```dart
@override
void initState() {
  super.initState();
  
  if (widget.config.shouldPlaySound) {
    final player = AudioPlayer();
    player.play(AssetSource('alert_sound.mp3'));
  }
  
  // ... resto del código
}
```

### ¿Cómo guardo un historial de alertas?

Crea un nuevo provider:
```dart
class AlertEvent {
  final FatigueLevel level;
  final DateTime timestamp;
  final double value;
  
  AlertEvent(this.level, this.timestamp, this.value);
}

final alertHistoryProvider = StateNotifierProvider<AlertHistoryNotifier, List<AlertEvent>>((ref) {
  return AlertHistoryNotifier();
});
```

### ¿Cómo creo alertas para fuerza (no solo fatiga)?

Duplica la estructura:
1. Crea `force_alert_provider.dart`
2. Define umbrales específicos para fuerza
3. Crea widgets separados o reutiliza los existentes
4. Integra en `FatigueAlertManager`

### ¿Cómo permito que el usuario configure los umbrales?

1. Crea un provider de configuración:
```dart
class AlertThresholds {
  final double low;
  final double medium;
  final double high;
}

final thresholdsProvider = StateProvider<AlertThresholds>((ref) {
  return AlertThresholds(low: 60, medium: 76, high: 90);
});
```

2. Úsalo en `getFatigueLevel()`:
```dart
FatigueLevel getFatigueLevel(double value, AlertThresholds thresholds) {
  if (value >= thresholds.high) return FatigueLevel.high;
  if (value >= thresholds.medium) return FatigueLevel.medium;
  if (value >= thresholds.low) return FatigueLevel.low;
  return FatigueLevel.none;
}
```

3. Crea una pantalla de configuración para que el usuario ajuste los valores.

---

## 📚 Recursos

- **Documentación completa**: `lib/features/alerts/README.md`
- **Diagrama de flujo**: `lib/features/alerts/FLOW_DIAGRAM.md`
- **Guía rápida**: `ALERTS_QUICKSTART.md`
- **Ejemplos de código**: `lib/features/alerts/examples/alert_examples.dart`

---

## 🤝 Contribuciones

Para añadir nuevas funcionalidades o mejorar el sistema:
1. Revisa la arquitectura en `FLOW_DIAGRAM.md`
2. Sigue el patrón de Riverpod existente
3. Documenta los cambios en `README.md`
4. Añade comentarios en el código

---

¿Más preguntas? Consulta el código fuente. Todos los archivos están comentados detalladamente. 🚀
