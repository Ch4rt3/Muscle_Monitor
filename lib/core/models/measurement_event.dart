/// Evento de medición individual e inmutable.
///
/// Cada notificación BLE, tick de simulación o evento de reproducción
/// produce exactamente un [MeasurementEvent]. Los consumidores
/// (gráficos, procesador de fatiga, grabador SQLite) lo reciben
/// tal cual sin modificarlo.
library;

/// Fuente que originó la medición.
enum MeasurementSourceType {
  /// Datos reales del ESP32 vía BLE.
  ble,

  /// Datos generados por el simulador integrado.
  simulation,

  /// Datos reproducidos desde una grabación previa.
  replay,
}

/// Evento de medición individual e inmutable.
class MeasurementEvent {
  /// Canal de origen: `'fuerza'` o `'fatiga'`.
  final String channel;

  /// Valor numérico decodificado (tal como sale del primer byte BLE o
  /// del generador). Rango esperado: 0–100, pero no se valida aquí
  /// porque el rango real del ESP32 es una dependencia pendiente (D-01).
  final double value;

  /// Microsegundos desde epoch UTC en el momento en que Flutter recibió
  /// la notificación (o la generó en simulación/replay).
  ///
  /// **No es** el instante de adquisición en el ESP32 — la latencia BLE
  /// es variable y el firmware actual no incluye timestamps propios.
  final int receptionTimestampUs;

  /// Número de secuencia por canal dentro de la sesión, generado por
  /// Flutter (contador auto‑incremental). Comienza en 0 al iniciar sesión.
  ///
  /// **Limitación:** Este número lo genera la app, no el firmware.
  /// No es posible detectar pérdidas de paquetes BLE con esta secuencia
  /// a menos que el firmware incluya su propio contador. Esta distinción
  /// queda documentada como dependencia pendiente del firmware.
  final int sequence;

  /// Origen de la medición.
  final MeasurementSourceType source;

  /// Payload BLE original. Solo se captura cuando el modo de diagnóstico
  /// detallado está activo. `null` en simulación y en capturas normales.
  final List<int>? rawBytes;

  /// Ausente con el protocolo actual. Nunca se infiere del contador Flutter.
  final int? firmwareSequence;

  MeasurementEvent({
    required this.channel,
    required this.value,
    required this.receptionTimestampUs,
    required this.sequence,
    required this.source,
    List<int>? rawBytes,
    this.firmwareSequence,
  }) : rawBytes = rawBytes == null ? null : List.unmodifiable(rawBytes);

  /// Serializa a mapa JSON para grabaciones JSONL.
  Map<String, dynamic> toJson() => {
    'ch': channel,
    'val': value,
    't': receptionTimestampUs,
    'seq': sequence,
    'src': source.name,
    if (rawBytes != null) 'raw': rawBytes,
    if (firmwareSequence != null) 'firmware_seq': firmwareSequence,
  };

  /// Deserializa desde mapa JSON de una grabación.
  factory MeasurementEvent.fromJson(Map<String, dynamic> json) {
    return MeasurementEvent(
      channel: json['ch'] as String,
      value: (json['val'] as num).toDouble(),
      receptionTimestampUs: json['t'] as int,
      sequence: json['seq'] as int,
      source: MeasurementSourceType.values.byName(json['src'] as String),
      rawBytes: (json['raw'] as List<dynamic>?)?.cast<int>(),
      firmwareSequence: json['firmware_seq'] as int?,
    );
  }

  @override
  String toString() =>
      'MeasurementEvent($channel, val=$value, seq=$sequence, src=${source.name})';
}
