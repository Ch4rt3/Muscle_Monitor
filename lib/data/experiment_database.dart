import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:muscle_monitoring/core/acquisition/recording_writer.dart';

class StoredMeasurement {
  const StoredMeasurement(this.ordinal, this.line);
  final int ordinal;
  final RecordingEventLine line;
  String get payload => jsonEncode(line.toJson());
}

/// Repositorio SQLite compartido por sesiones, participantes y exportaciones.
/// Se admite inyectar la factoría SQLite real de escritorio en las pruebas.
class ExperimentDatabase {
  ExperimentDatabase(this.db);
  final Database db;
  int lastBatchMs = 0;

  static Future<ExperimentDatabase> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final database = await (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = FULL');
        },
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE participants (
            id TEXT PRIMARY KEY, alias TEXT, age_range TEXT, experience_level TEXT,
            notes TEXT, created_at_us INTEGER NOT NULL)''');
          await db.execute(
            '''CREATE TABLE sessions (
            id TEXT PRIMARY KEY, participant_id TEXT NOT NULL REFERENCES participants(id),
            condition TEXT NOT NULL CHECK(condition IN ('with_alerts','without_alerts')),
            exercise TEXT NOT NULL, started_at_us INTEGER NOT NULL, ended_at_us INTEGER,
            status TEXT NOT NULL DEFAULT 'active', device_name TEXT, device_mac_hash TEXT,
            device_tz_offset_s INTEGER NOT NULL, config_json TEXT NOT NULL,
            source TEXT NOT NULL CHECK(source IN ('ble','simulation','replay')),
            notes TEXT, recording_path TEXT NOT NULL, expected_count INTEGER,
            stored_count INTEGER, integrity_json TEXT, feedback_policy TEXT NOT NULL)''',
          );
          await db.execute(
            '''CREATE TABLE measurements (
            id INTEGER PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id),
            ordinal INTEGER NOT NULL, reception_timestamp_us INTEGER NOT NULL,
            channel TEXT NOT NULL CHECK(channel IN ('fuerza','fatiga')),
            value REAL NOT NULL, sequence INTEGER NOT NULL, firmware_sequence INTEGER,
            source TEXT NOT NULL, payload_json TEXT NOT NULL,
            UNIQUE(session_id, channel, sequence), UNIQUE(session_id, ordinal))''',
          );
          await db.execute(
            'CREATE INDEX idx_meas_session_ch ON measurements(session_id,channel)',
          );
          await db.execute('''CREATE TABLE alert_events (
            id INTEGER PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id),
            sequence INTEGER NOT NULL, timestamp_us INTEGER NOT NULL,
            level TEXT NOT NULL, trigger_value REAL NOT NULL, smoothed_value REAL NOT NULL,
            previous_level TEXT NOT NULL, triggered INTEGER NOT NULL,
            was_shown INTEGER NOT NULL DEFAULT 0, suppression_reason TEXT,
            condition TEXT NOT NULL, was_dismissed_by_user INTEGER NOT NULL DEFAULT 0,
            dismissed_at_us INTEGER, shown_at_us INTEGER,
            UNIQUE(session_id,sequence))''');
          await db.execute('''CREATE TABLE session_evals (
            id INTEGER PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id),
            eval_type TEXT NOT NULL, value REAL NOT NULL, timestamp_us INTEGER NOT NULL,
            notes TEXT)''');
        },
      ),
    );
    return ExperimentDatabase(database);
  }

  Future<void> addParticipant(String id, {String? alias}) async {
    if (id.trim().isEmpty) {
      throw ArgumentError('El código de participante es obligatorio');
    }
    await db.insert('participants', {
      'id': id.trim(),
      'alias': alias,
      'created_at_us': DateTime.now().microsecondsSinceEpoch,
    });
  }

  Future<List<Map<String, Object?>>> participants() =>
      db.query('participants', orderBy: 'id');
  Future<List<Map<String, Object?>>> sessions() =>
      db.query('sessions', orderBy: 'started_at_us DESC');
  Future<void> createSession(Map<String, Object?> session) async {
    await db.insert('sessions', session);
  }

  Future<void> writeBatch(
    String sessionId,
    String condition,
    List<StoredMeasurement> rows,
  ) async {
    if (rows.isEmpty) return;
    final watch = Stopwatch()..start();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final row in rows) {
        final event = row.line.event;
        batch.insert('measurements', {
          'session_id': sessionId,
          'ordinal': row.ordinal,
          'reception_timestamp_us': event.receptionTimestampUs,
          'channel': event.channel,
          'value': event.value,
          'sequence': event.sequence,
          'firmware_sequence': event.firmwareSequence,
          'source': event.source.name,
          'payload_json': row.payload,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        final result = row.line.processingResult;
        if (result != null) {
          batch.insert('alert_events', {
            'session_id': sessionId,
            'sequence': event.sequence,
            'timestamp_us': event.receptionTimestampUs,
            'level': result.fatigueLevel,
            'trigger_value': event.value,
            'smoothed_value': result.smoothedValue,
            'previous_level': result.previousLevel,
            'triggered': result.alertTriggered ? 1 : 0,
            'was_shown': 0,
            'suppression_reason': result.suppressionReason ?? 'not_delivered',
            'condition': condition,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      await batch.commit(noResult: true);
      // Reintentos idempotentes: una clave repetida debe contener EL MISMO evento.
      final stored = await txn.query(
        'measurements',
        columns: ['ordinal', 'payload_json'],
        where: 'session_id = ? AND ordinal >= ? AND ordinal <= ?',
        whereArgs: [sessionId, rows.first.ordinal, rows.last.ordinal],
      );
      final byOrdinal = {
        for (final r in stored) r['ordinal']: r['payload_json'],
      };
      for (final row in rows) {
        if (byOrdinal[row.ordinal] != row.payload) {
          throw StateError(
            'Conflicto de integridad en medición ${row.ordinal}',
          );
        }
      }
    });
    lastBatchMs = watch.elapsedMilliseconds;
  }

  Future<void> delivery(String sessionId, Map<String, dynamic> delivery) async {
    final type = delivery['type'];
    final values = type == 'dismissal'
        ? <String, Object?>{
            'was_dismissed_by_user': 1,
            'dismissed_at_us': delivery['at'] as int,
          }
        : <String, Object?>{
            'was_shown': delivery['shown'] == true ? 1 : 0,
            'shown_at_us': delivery['at'] as int,
            'suppression_reason': delivery['shown'] == true
                ? null
                : delivery['reason'] as String?,
          };
    final count = await db.update(
      'alert_events',
      values,
      where: 'session_id = ? AND sequence = ?',
      whereArgs: [sessionId, delivery['seq']],
    );
    if (count != 1) throw StateError('Decisión de alerta no encontrada');
  }

  Future<Map<String, dynamic>> integrity(
    String id,
    List<StoredMeasurement> expected,
  ) async {
    final stored = await db.query(
      'measurements',
      columns: ['payload_json'],
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'ordinal',
    );
    String digest(Iterable<String> values) =>
        sha256.convert(utf8.encode(values.join('\n'))).toString();
    final expectedHash = digest(expected.map((e) => e.payload));
    final storedHash = digest(stored.map((e) => e['payload_json'] as String));
    return {
      'expected': expected.length,
      'stored': stored.length,
      'expected_sha256': expectedHash,
      'stored_sha256': storedHash,
      'ok': expected.length == stored.length && expectedHash == storedHash,
    };
  }

  Future<void> finish(
    String id,
    String status,
    Map<String, dynamic> report,
  ) async {
    await db.update(
      'sessions',
      {
        'status': status,
        'ended_at_us': DateTime.now().microsecondsSinceEpoch,
        'expected_count': report['expected'],
        'stored_count': report['stored'],
        'integrity_json': jsonEncode(report),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addEvaluation(
    String id,
    String type,
    double value, {
    String? notes,
  }) async {
    if (!value.isFinite) throw ArgumentError('Evaluación inválida');
    await db.insert('session_evals', {
      'session_id': id,
      'eval_type': type,
      'value': value,
      'notes': notes,
      'timestamp_us': DateTime.now().microsecondsSinceEpoch,
    });
  }
}
