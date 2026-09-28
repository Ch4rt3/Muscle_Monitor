# MyoSafe — monitoreo muscular

Aplicación Flutter de investigación con adquisición BLE, simulación, sesiones
persistentes, alertas configurables y reproducción de grabaciones.

## Uso

1. Ejecutar `flutter pub get` y `flutter run`.
2. Abrir **Investigador** desde Bluetooth y registrar un participante con código
   (por ejemplo, P01). Evitar datos identificables.
3. En **Preparar sesión**, elegir participante, ejercicio, fuente y condición.
   La simulación no requiere hardware. Para BLE, conectar primero el ESP32.
4. Configurar los umbrales antes de empezar: por defecto **30 / 50 / 75**,
   promedio móvil de 3 muestras y cooldown de 5 segundos. La configuración queda
   congelada y guardada con la sesión.
5. Finalizar desde Monitoreo y revisar la integridad. Puede añadirse una evaluación
   opcional documentando instrumento y escala en las notas.
6. En Investigador están Diagnóstico, Grabaciones y reproducción, y Exportar.

La condición **sin alertas** conserva las evaluaciones del algoritmo, pero oculta
overlay, indicador y etiquetas interpretativas. Mostrar u ocultar también la
gráfica de fatiga es una decisión del investigador: una sesión BLE sin alertas no
puede empezar con esa decisión pendiente.

Las sesiones son de primer plano. Al pasar a segundo plano se interrumpen; no se
promete adquisición BLE en background. Al reiniciar se recuperan los registros
durables de sesiones que no terminaron correctamente.

## Datos

En el directorio privado de documentos de la app:

- `myosafe.db`: participantes, sesiones, mediciones, decisiones y evaluaciones.
- `recordings/<uuid>.jsonl`: mediciones, resultados originales y confirmaciones
  de visualización de alertas.
- `recordings/<uuid>_comparison.json`: comparación de una reproducción.
- `logs/critical.jsonl`: errores, advertencias y contexto de sesión recuperables.
- `exports/`: archivos compartibles desde la app.

La exportación genera cinco CSV UTF-8: participantes, sesiones, mediciones, alertas
y evaluaciones. Por defecto incluye solo sesiones BLE completadas; simulaciones,
reproducciones e interrupciones requieren activar datos de diagnóstico.

El replay no sobrescribe originales. El cooldown usa tiempo registrado, no la
velocidad de reproducción.

## Verificación

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

En el Mac de desarrollo, mientras Xcode requiere aceptar su licencia, las pruebas
nativas SQLite pueden utilizar las Command Line Tools ya instaladas:

```sh
tool/test_with_clt.sh --no-pub
```

El script solo modifica el entorno del proceso, no la configuración global.
La suite incluye 60 segundos reales de simulación, SQLite real, reintentos,
recuperación tras SIGKILL, replay y pruebas de interfaz.

## Límites

El protocolo BLE actual contiene un byte por notificación. Se valida su estructura,
pero **no se ha validado el firmware ni el significado fisiológico de sus valores**.
`sequence` se genera en Flutter y no detecta paquetes perdidos antes de la recepción.
`firmwareSequence` permanece nulo. No se inventa una conversión a porcentaje.

Consulta [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) para estado por fase,
evidencia, decisiones técnicas y pendientes de hardware/metodología.
