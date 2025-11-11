# 🚀 Guía de Despliegue - Sistema de Alertas de Fatiga

## ✅ Estado Actual

El sistema de alertas está **completamente implementado y listo para usar**. No requiere pasos adicionales de instalación.

---

## 📋 Checklist Pre-Ejecución

Antes de ejecutar la app, verifica:

### 1. Dependencias Instaladas ✅
```bash
flutter pub get
```

**Salida esperada:**
```
Running "flutter pub get" in Muscle_Monitor...
Got dependencies!
```

### 2. Sin Errores de Compilación ✅
```bash
flutter analyze
```

**Salida esperada:**
```
Analyzing Muscle_Monitor...
No issues found!
```

### 3. Dispositivo/Emulador Conectado ✅
```bash
flutter devices
```

**Salida esperada:**
```
2 connected devices:

Android (mobile) • <device-id>
Chrome (web) • chrome
```

---

## 🏃 Ejecución de la App

### Opción 1: Desde VS Code
1. Presiona `F5` o click en "Run > Start Debugging"
2. Selecciona el dispositivo target
3. La app se compilará e iniciará automáticamente

### Opción 2: Desde Terminal
```bash
# Modo debug
flutter run

# Modo release (más rápido)
flutter run --release
```

### Opción 3: Hot Reload Durante Desarrollo
```bash
flutter run
# Luego, presiona 'r' para hot reload
# O presiona 'R' para hot restart
```

---

## 🔍 Verificación Post-Inicio

### 1. Verificar que el módulo está cargado
Al iniciar la app, deberías ver en la consola:
```
✅ FatigueAlertManager initialized
```

### 2. Navegar a la pantalla de monitoreo
1. Abre la app
2. Ve a la pestaña "BLE"
3. Conecta un dispositivo
4. Ve a "Monitoreo"
5. Deberías ver el `FatigueIndicator` mostrando "Estado Normal"

### 3. Verificar alertas (con hardware)
1. Conecta el ESP32 con MyoWare 2.0
2. Realiza un ejercicio muscular
3. Cuando la fatiga supere 60%, aparecerá la primera alerta

---

## 🧪 Testing sin Hardware

Si no tienes el hardware disponible, puedes probar con datos simulados:

### 1. Activar Modo Simulación
Edita `lib/presentation/providers/ble_provider.dart` y descomenta el código de simulación en el método `connectDevice()`:

```dart
// SIMULACIÓN (descomentar para probar sin hardware)
_simTimer?.cancel();
_simTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
  final f = _rand.nextInt(256).toDouble();
  final fa = 150 + _rand.nextInt(105).toDouble(); // Genera 60-100%
  addFuerza(f);
  addFatiga(fa);
});
```

### 2. Ejecutar y Observar
1. Ejecuta la app
2. Ve a "BLE" y conecta cualquier dispositivo (o simula la conexión)
3. Las alertas comenzarán a aparecer automáticamente

---

## 🔧 Configuración Opcional

### Ajustar Nivel de Logs BLE
En `lib/main.dart`, cambia el nivel de verbosidad:

```dart
// Menos logs
FlutterBluePlus.setLogLevel(LogLevel.warning, color: true);

// Más logs (debug)
FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
```

### Cambiar Tema
Edita `lib/config/theme/app_theme.dart` para personalizar colores globales.

---

## 📱 Build para Producción

### Android
```bash
flutter build apk --release
# APK generado en: build/app/outputs/flutter-apk/app-release.apk
```

### iOS
```bash
flutter build ios --release
# Requiere Mac y configuración de certificados
```

### Web
```bash
flutter build web --release
# Archivos generados en: build/web/
```

---

## 🐛 Troubleshooting Común

### Problema: "No devices found"
**Solución:**
```bash
# Android
adb devices

# iOS
flutter devices

# Activar modo desarrollador en el dispositivo
```

### Problema: "Pub get failed"
**Solución:**
```bash
flutter clean
flutter pub get
```

### Problema: "BLE permissions denied"
**Solución:**
- Android: Acepta permisos de ubicación y Bluetooth
- iOS: Acepta permisos de Bluetooth en configuración

### Problema: "Las alertas no aparecen"
**Soluciones:**
1. Verifica que hay datos de fatiga llegando:
   ```dart
   print(ref.watch(bleProvider).dataFatiga.length);
   ```
2. Verifica que los valores superan el 60%
3. Revisa que `FatigueAlertManager` está en `main.dart`

### Problema: "Errores de compilación"
**Solución:**
```bash
flutter clean
flutter pub get
flutter run
```

---

## 📊 Monitoreo de Performance

### Ver estadísticas de rendimiento
```bash
flutter run --profile
```

### Analizar tamaño del build
```bash
flutter build apk --analyze-size
```

### Ver widgets en tiempo real
Activa Flutter DevTools:
```bash
flutter run
# Luego abre el link que aparece en consola
```

---

## 🔐 Permisos Requeridos

### Android (`android/app/src/main/AndroidManifest.xml`)
Ya están configurados:
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### iOS (`ios/Runner/Info.plist`)
Ya están configurados:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>La app necesita Bluetooth para conectar con sensores</string>
```

---

## 🎯 Modo de Uso Recomendado

### Para Desarrollo
```bash
flutter run --debug
# Hot reload: presiona 'r'
# Hot restart: presiona 'R'
```

### Para Testing
```bash
flutter run --profile
```

### Para Producción
```bash
flutter run --release
```

---

## 📦 Distribución

### Google Play Store
1. Genera el APK firmado:
   ```bash
   flutter build appbundle --release
   ```
2. Sube a Play Console
3. Completa metadatos y capturas

### App Store
1. Build desde Xcode en Mac
2. Archive y sube con Application Loader
3. Completa info en App Store Connect

### Web Hosting
```bash
flutter build web --release
# Sube el contenido de build/web/ a tu servidor
```

---

## 🎉 ¡Listo para Usar!

El sistema está completamente funcional. Solo ejecuta:

```bash
flutter run
```

Y observa las alertas en acción cuando conectes el sensor.

---

## 📞 Recursos Adicionales

- [Flutter Docs](https://docs.flutter.dev)
- [Riverpod Docs](https://riverpod.dev)
- [Flutter Blue Plus](https://pub.dev/packages/flutter_blue_plus)
- Documentación del módulo: `lib/features/alerts/README.md`

---

**Versión:** 1.0.0  
**Estado:** ✅ Producción Ready  
**Última actualización:** Noviembre 10, 2025
