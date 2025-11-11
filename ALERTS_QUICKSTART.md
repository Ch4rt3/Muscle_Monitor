# 🚀 Guía Rápida: Sistema de Alertas de Fatiga

## ✅ ¿Qué se ha implementado?

Se ha creado un **sistema modular de alertas** que monitorea en tiempo real los niveles de fatiga muscular y muestra alertas visuales animadas cuando se detectan niveles peligrosos.

## 📁 Archivos Creados

```
lib/features/alerts/
├── alerts.dart                          ✅ Exportaciones públicas
├── README.md                            ✅ Documentación completa
├── models/
│   └── alert_state.dart                ✅ Estado de alertas
├── providers/
│   └── fatigue_alert_provider.dart     ✅ Lógica de negocio
├── utils/
│   └── fatigue_utils.dart              ✅ Configuraciones y utilidades
└── widgets/
    ├── fatigue_alert_manager.dart      ✅ Gestor de overlays
    ├── fatigue_alert_widget.dart       ✅ Widget animado
    └── fatigue_indicator.dart          ✅ Indicador visual
```

## 📝 Archivos Modificados

### `lib/main.dart`
- ✅ Añadido `FatigueAlertManager` envolviendo la app
- ✅ Importado módulo de alertas

### `lib/presentation/screens/monitoring_screen.dart`
- ✅ Añadido `FatigueIndicator` en la UI
- ✅ Importado módulo de alertas

## 🎯 Cómo Funciona

### 1. Monitoreo Automático
El sistema se activa automáticamente cuando:
- La app está ejecutándose
- Hay un dispositivo BLE conectado
- Se están recibiendo datos de fatiga

### 2. Procesamiento de Datos
```
Valor EMG (0-255)
    ↓
Conversión a % (0-100)
    ↓
Promedio móvil (suavizado)
    ↓
Evaluación de umbral
    ↓
Emisión de alerta (si aplica)
```

### 3. Tipos de Alertas

| Nivel | Umbral | Color | Acción |
|-------|--------|-------|--------|
| 🟢 Normal | < 60% | Gris | No hay alerta |
| 🟡 Leve | 60-75% | Naranja claro | Mensaje informativo |
| 🟠 Moderada | 76-89% | Naranja | Mensaje + vibración |
| 🔴 Severa | ≥ 90% | Rojo | Mensaje + vibración + animación intensa |

## 🧪 Cómo Probar

### Opción 1: Con Hardware Real
1. Conecta el ESP32 con MyoWare 2.0
2. Inicia la app y conecta al dispositivo
3. Realiza un ejercicio muscular intenso
4. Observa las alertas aparecer cuando la fatiga aumente

### Opción 2: Simulación (para testing)
Edita `lib/presentation/providers/ble_provider.dart` y descomenta el modo simulación:

```dart
// En el método connectDevice(), después de las características BLE:
_simTimer?.cancel();
_simTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
  // Simular valores de fatiga crecientes
  final fa = 150 + _rand.nextInt(105).toDouble(); // 60-100%
  addFatiga(fa);
});
```

## 🎨 Personalización Rápida

### Cambiar Colores
Edita `lib/features/alerts/utils/fatigue_utils.dart`:
```dart
static const low = FatigueAlertConfig(
  color: Color(0xFF4CAF50), // Verde en lugar de naranja
  // ...
);
```

### Cambiar Umbrales
```dart
FatigueLevel getFatigueLevel(double fatigueValue) {
  if (fatigueValue >= 85) return FatigueLevel.high;    // Era 90
  if (fatigueValue >= 70) return FatigueLevel.medium;  // Era 76
  if (fatigueValue >= 50) return FatigueLevel.low;     // Era 60
  return FatigueLevel.none;
}
```

### Cambiar Duración de Alertas
```dart
static const high = FatigueAlertConfig(
  displayDuration: Duration(seconds: 10), // Era 5 segundos
  // ...
);
```

## 🔍 Debugging

### Ver Estado Actual
Añade esto temporalmente en `monitoring_screen.dart`:
```dart
Consumer(
  builder: (context, ref, _) {
    final alert = ref.watch(fatigueAlertProvider);
    return Text(
      'Debug: ${alert.currentLevel.name} - ${alert.currentValue.toStringAsFixed(1)}%',
      style: TextStyle(fontSize: 10),
    );
  },
)
```

### Logs en Consola
Los providers ya incluyen logging. Verás mensajes como:
```
I/flutter (12345): FatigueAlertState(level: FatigueLevel.medium, value: 78.5%, active: true)
```

## ⚠️ Troubleshooting

### Las alertas no aparecen
1. ✅ Verifica que hay datos de fatiga llegando
2. ✅ Revisa que los valores superan el 60%
3. ✅ Asegúrate que `FatigueAlertManager` está en `main.dart`

### Las alertas aparecen muy seguido
1. Aumenta el cooldown en `alert_state.dart`
2. Aumenta el `windowSize` del promedio móvil

### Las alertas se ven mal
1. Verifica que el dispositivo soporta overlays
2. Ajusta los márgenes en `fatigue_alert_widget.dart`

## 🚀 Próximos Pasos

### Funcionalidades Sugeridas
1. **Sonido de alertas**: Integra `audioplayers`
2. **Historial**: Guarda las alertas en una base de datos local
3. **Estadísticas**: Muestra gráficos de frecuencia de alertas
4. **Configuración**: Panel para ajustar umbrales desde la UI
5. **Exportar datos**: Permite guardar sesiones con alertas

### Cómo Extender
El módulo está diseñado para ser fácilmente extensible:

```dart
// Crear un nuevo tipo de alerta (por ejemplo, para fuerza)
final forceAlertProvider = StateNotifierProvider<ForceAlertNotifier, ForceAlertState>((ref) {
  return ForceAlertNotifier(ref);
});
```

## 📚 Recursos Adicionales

- `lib/features/alerts/README.md` - Documentación técnica completa
- Código fuente comentado en cada archivo
- Ejemplos de uso en los widgets

## 🤝 Soporte

Si encuentras algún problema:
1. Revisa los logs de la consola
2. Verifica los errores de compilación
3. Consulta la documentación técnica
4. Revisa el código de ejemplo en los tests

---

**¡El sistema está listo para usarse!** 🎉

Solo ejecuta la app, conecta el sensor y observa las alertas en acción.
