# MyoSafe - Muscle Monitoring App 💪

Aplicación Flutter para monitoreo de actividad muscular en tiempo real usando sensor MyoWare 2.0 conectado vía Bluetooth (ESP32).

## 🚀 Características Principales

### ✅ Monitoreo BLE
- Conexión Bluetooth con ESP32
- Lectura en tiempo real de datos EMG (Fuerza y Fatiga)
- Gráficos de línea con `fl_chart`
- Gestión de permisos automática

### ✅ Sistema de Alertas de Fatiga (NUEVO)
Sistema modular de alertas en tiempo real basado en niveles de fatiga muscular:

- **🟡 Fatiga Leve (60-75%)**: Alerta informativa
- **🟠 Fatiga Moderada (76-89%)**: Alerta + vibración
- **🔴 Fatiga Severa (≥90%)**: Alerta intensa + vibración

**Características:**
- Alertas animadas tipo overlay (no bloquean UI)
- Promedio móvil para evitar falsos positivos
- Cooldown de 5 segundos anti-spam
- Indicador visual permanente en pantalla
- Completamente personalizable

📖 **Documentación completa**: [`ALERTS_IMPLEMENTATION_SUMMARY.md`](ALERTS_IMPLEMENTATION_SUMMARY.md)

## 📁 Estructura del Proyecto

```
lib/
├── config/
│   ├── router/        # GoRouter configuración
│   └── theme/         # Tema de la aplicación
├── features/
│   └── alerts/        # 🆕 Módulo de alertas de fatiga
│       ├── models/
│       ├── providers/
│       ├── utils/
│       ├── widgets/
│       └── examples/
├── presentation/
│   ├── providers/     # BLE provider
│   ├── screens/       # Pantallas principales
│   └── widgets/       # Widgets compartidos
└── main.dart
```

## 🛠️ Dependencias

```yaml
dependencies:
  flutter_riverpod: ^2.6.1     # Manejo de estado
  go_router: ^16.2.0           # Navegación
  flutter_blue_plus: ^1.35.5   # Bluetooth BLE
  fl_chart: ^1.1.0             # Gráficos
  permission_handler: ^12.0.1  # Permisos
```

## 🚀 Inicio Rápido

### 1. Instalar dependencias
```bash
flutter pub get
```

### 2. Ejecutar la app
```bash
flutter run
```

### 3. Conectar dispositivo BLE
- Ve a la pantalla BLE
- Busca tu ESP32
- Conecta
- Navega a "Monitoreo"

### 4. Ver alertas en acción
Las alertas aparecerán automáticamente cuando la fatiga supere los umbrales configurados.

## 📚 Documentación del Módulo de Alertas

- 📖 [`ALERTS_IMPLEMENTATION_SUMMARY.md`](ALERTS_IMPLEMENTATION_SUMMARY.md) - Resumen ejecutivo
- 🚀 [`ALERTS_QUICKSTART.md`](ALERTS_QUICKSTART.md) - Guía rápida
- 📖 [`lib/features/alerts/README.md`](lib/features/alerts/README.md) - Documentación técnica
- 📊 [`lib/features/alerts/FLOW_DIAGRAM.md`](lib/features/alerts/FLOW_DIAGRAM.md) - Diagramas de flujo
- ❓ [`lib/features/alerts/FAQ.md`](lib/features/alerts/FAQ.md) - Preguntas frecuentes

## 🎯 Personalización de Alertas

### Cambiar umbrales de fatiga
Edita `lib/features/alerts/utils/fatigue_utils.dart`:
```dart
FatigueLevel getFatigueLevel(double fatigueValue) {
  if (fatigueValue >= 90) return FatigueLevel.high;    // Cambiar aquí
  if (fatigueValue >= 76) return FatigueLevel.medium;  // Cambiar aquí
  if (fatigueValue >= 60) return FatigueLevel.low;     // Cambiar aquí
  return FatigueLevel.none;
}
```

### Ajustar colores y duración
Edita las configuraciones en `FatigueAlertConfigs` del mismo archivo.

## 🧪 Testing

### Con Hardware Real
1. Conecta el ESP32 con MyoWare 2.0
2. Realiza ejercicios para generar fatiga
3. Observa las alertas aparecer

### Simulación (Sin Hardware)
Modifica `lib/presentation/providers/ble_provider.dart` para simular datos de prueba.

## 📱 Pantallas

- **Home**: Pantalla de inicio
- **BLE**: Búsqueda y conexión de dispositivos
- **Monitoring**: Gráficos en tiempo real + alertas

## 🏗️ Arquitectura

- **State Management**: Riverpod
- **Navigation**: GoRouter
- **BLE**: flutter_blue_plus
- **Charts**: fl_chart
- **Alerts**: Módulo custom modular

## 🔮 Próximas Funcionalidades

- [ ] Sonido en alertas severas
- [ ] Historial de sesiones
- [ ] Exportar datos a CSV
- [ ] Configuración de umbrales desde UI
- [ ] Alertas para fuerza muscular
- [ ] Estadísticas y análisis

## 📄 Licencia

Este proyecto es de código abierto.

## 👤 Autor

Desarrollado con ❤️ para monitoreo muscular seguro.

