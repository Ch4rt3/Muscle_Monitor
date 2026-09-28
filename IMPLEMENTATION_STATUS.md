# Estado de implementación — Plan v2 corregido

28 de septiembre de 2026. Continuación del trabajo existente de Antigravity.

## Estado por fase

| Fase | Implementado | Validación pendiente |
| --- | --- | --- |
| 0. Limpieza | Imports, retirada de `get`, umbrales coherentes. | Ninguna específica. |
| 1. Fundamentos | Evento inmutable, configuración, logger circular y archivo crítico recuperable. | Coste de escritura durable en teléfonos objetivo. |
| 2. Adquisición | Simulación/BLE, bus con grabador obligatorio, buffers visuales y procesamiento único. | Gráficas prolongadas en teléfono; frecuencia real BLE. |
| 3. SQLite | WAL, claves foráneas, unicidad, lotes, reintentos, hash de integridad y recuperación. | Rendimiento bajo carga BLE real. |
| 4. Grabación/replay | JSONL con procesamiento original, entregas, pausa/velocidad/reinicio y comparación exportable. | Captura real ESP32 y reproducción en teléfono. |
| 5. Diagnóstico | Estadísticas por canal, errores, configuración, logs filtrables, exportación y recuperación. | Conexiones y desconexiones físicas. |
| 6. Experimento/CSV | Participantes, preparación/cierre, evaluaciones, condición sin alertas y exportación separada. | Protocolo experimental y compartir en dispositivo. |
| 7. ESP32 | Validación de un byte, suscripciones, MTU, desconexiones y logs preparados. | Validación física completa. |

No se considera validado el 100% del plan: las pruebas de software y el APK no
sustituyen las pruebas con el ESP32 y los teléfonos de la investigación.
Se conserva la estructura existente, agrupando responsabilidades relacionadas
sin crear todos los archivos/repositorios hipotéticos del borrador.

## Las seis correcciones solicitadas

### 1. Integridad adquisición → SQLite

La suscripción a la fuente se establece antes de iniciarla. Cada evento admitido
pasa por un procesador único y una llamada obligatoria al grabador. Este escribe
y fuerza a disco el JSONL **antes** de que el bus incremente aceptadas o notifique
a la interfaz. La grabación no depende de suscriptores visuales.

SQLite recibe lotes de hasta 100 registros, con vaciado periódico cada segundo.
El buffer elimina solo el prefijo confirmado, no los eventos llegados durante una
escritura. Tras tres intentos fallidos se interrumpe la adquisición y el journal
queda recuperable. El límite de 10 000 pendientes provoca interrupción explícita,
no descarte silencioso. Al cerrar se comparan cantidad y SHA-256 del contenido
ordenado de journal y SQLite, incluyendo procesamiento original. El informe
conserva recibidas, aceptadas y rechazadas.

La garantía comprende eventos aceptados y confirmados por el sistema de archivos.
No demuestra ausencia de pérdidas en radio, firmware o antes de entrar a Flutter,
ni supervivencia a destrucción física del almacenamiento. Un fallo se informa,
nunca se presenta como una medición guardada.

### 2. Resultados originales y decisiones

Cada evento de fatiga conserva valor suavizado, nivel anterior/nuevo, decisión de
generar alerta y motivo de supresión. Registros adicionales conservan confirmación
de overlay tras un frame y descarte manual, separados de la decisión del algoritmo.
Una alerta reemplazada antes de renderizarse no cuenta como mostrada.

El replay utiliza configuración, condición, política visual y tiempos originales,
y reinicia promedio/cooldown. El informe compara mediciones, niveles, transiciones
y decisiones por evento, presentando las entregas originales y nuevas por separado.
`match` significa equivalencia de mediciones/procesamiento, **no** igualdad de
interacción humana ni de tiempos de renderizado.

### 3. Unicidad y reintentos

SQLite activa `foreign_keys`, WAL y sincronización FULL. Hay unicidad por
`(session_id, channel, sequence)` y `(session_id, ordinal)`; las decisiones también
tienen identidad única por sesión/secuencia. Repetir un lote idéntico es idempotente;
repetir su identidad con contenido distinto revierte la transacción. La prueba de
confirmación perdida escribe un lote, falla después del commit y verifica que el
reintento no duplica mediciones ni decisiones.

### 4. Secuencias y tiempos

La secuencia Flutter es independiente por canal/sesión. `firmwareSequence` es un
campo separado, nulo en el protocolo actual. Intervalos anormales y discontinuidades
son indicios diagnósticos, no pruebas de pérdida BLE. Los timestamps son epoch UTC
de recepción Flutter; el offset guardado permite reconstruir hora local, no la
hora de muestreo del ESP32.

### 5. Recuperación tras cierre inesperado

Advertencias, errores y contexto de sesión se sincronizan en `logs/critical.jsonl`.
Se capturan errores Flutter, de plataforma y de la zona raíz. Al abrir se leen los
logs y se reinsertan idempotentemente registros de sesiones todavía activas; se
aplican entregas/descarte y se marcan como interrumpidas. Una recuperación fallida
queda pendiente de otro intento. Diagnóstico muestra errores de persistencia y
permite reintentar cuando no hay sesión activa.

SIGKILL no permite capturar una causa que el sistema operativo no entrega a Dart:
se recuperan contexto y errores escritos previamente, no se promete un stack trace
del cierre forzado. Tampoco se promete escribir con disco lleno: se detiene la sesión.

### 6. Dependencias abiertas del investigador

| ID | Decisión o validación pendiente |
| --- | --- |
| D-01 | Rango ESP32 y conversión, si corresponde, a porcentaje. |
| D-02 | Frecuencia por canal y ajuste del almacenamiento para esa carga. |
| D-03 | Significado de fuerza/fatiga y validez del índice del firmware. |
| D-04 | Si gráfica/valor crudo se permite sin alertas. La app ofrece ambas opciones y exige elección para BLE, sin decidir la metodología. |
| D-05 | Instrumento, escala y momento de evaluaciones. El formulario opcional no impone escala. |
| D-06 | Orden fijo, contrabalanceado o aleatorio. Puede documentarse en notas; no se asigna automáticamente. |
| D-07 | Uno o varios teléfonos y consolidación. No hay sincronización. |

## Evidencia automatizada

Verificación final: **29 pruebas aprobadas**, `flutter analyze --no-pub` sin
incidencias y `flutter build apk --debug --no-pub` completado. APK disponible en
`build/app/outputs/flutter-apk/app-debug.apk`. `git diff --check` sin errores.

Las pruebas importan clases de producción, no copias de su implementación.

- `phase1_test.dart`: inmutabilidad, configuración, logger con 10 000 entradas,
  bus sin UI/fallo durable, cooldown por tiempo grabado y secuencias simuladas.
- `persistence_test.dart`: SQLite real, FK/WAL, reintento post-commit, nuevas
  entradas durante escritura, tres fallos consecutivos, conflicto de identidad,
  recuperación y simulación de 60 segundos con igualdad de conteos y hashes.
  Un lote de 50 midió 3 ms en este Mac (<50 ms); no es un benchmark móvil.
- SIGKILL: proceso separado escribe 100 mediciones y un error crítico, termina
  sin cierre ordenado y se comprueba su recuperación.
- `replay_test.dart`: dos velocidades/reproducciones equivalentes, orden/no
  duplicación, intervalos ±10 ms en este entorno, pausa/reanudación/parada,
  truncamiento y rechazo de comparación sin resultados originales.
- `session_flow_test.dart`: sesión/replay/comparación, entregas/descarte,
  exportación separada y texto CSV, desconexión, fallo de entrega durante cierre,
  payload BLE y bloqueo de decisión metodológica pendiente.
- `session_widgets_test.dart`: condiciones visibles/ocultas, confirmación de
  overlay, reemplazo antes del frame y preparación a 360 px sin overflow.
  `build/review/session_setup.png` es una captura de prueba con fuente local,
  no una captura de teléfono físico.

Comandos reproducibles en README. La suite incluye un minuto real de adquisición.
El test SIGKILL requiere POSIX. Las pruebas FFI ejecutan SQLite nativo, no una base falsa.

## Decisiones operativas y límites

- El journal escribe y sincroniza por evento para que la aceptación sea durable.
  Esto modifica deliberadamente la escritura asíncrona del borrador: debe medirse
  su impacto en frames, consumo y recepción en el teléfono objetivo.
- El índice de grabaciones es el directorio más las cabeceras. No se duplica en
  `rec_metadata.json`, evitando un índice desactualizado.
- El esquema es versión 1; no se migra una base experimental anterior porque el
  proyecto auditado no contenía persistencia SQLite de sesiones.
- Pasar a segundo plano interrumpe la sesión; no hay servicio BLE de background.
- No se validó iOS ni BLE real. El APK es debug, no una publicación firmada.
  Las advertencias de actualización futura de Gradle/AGP/Kotlin y versión NDK
  deben revisarse antes de distribuir; no se migró el toolchain.
- No hay retención/rotación automática de grabaciones y logs críticos: controlar
  espacio durante pruebas prolongadas y exportar respaldos.
- No se añadieron backend, login, nube ni refactorizaciones ajenas al alcance.
  Se preservaron las eliminaciones de documentos que ya existían.

## Siguiente aceptación con hardware

1. Confirmar firmware, rango, semántica, UUIDs y frecuencia de ambos canales.
2. Conectar ESP32, comprobar MTU/notificaciones y registrar al menos dos minutos.
3. Medir fluidez, latencia de escritura y frecuencia bajo carga en teléfono.
4. Provocar desconexión/cierre forzado; reabrir y contrastar integridad/errores.
5. Reproducir la captura real y revisar informe, condiciones y entrega de alertas.
6. Compartir CSV desde teléfono y revisar en la herramienta del estudio.
7. Aprobar D-04 y demás decisiones antes de sesiones experimentales.
