import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'measurement_source.dart';

/// Protocolo actual: un byte por notificación, sin contador ni reloj de firmware.
class BleMeasurementSource implements MeasurementSource {
  BleMeasurementSource(
    this.device, {
    this.maxReceptionInterval = const Duration(milliseconds: 500),
    this.jumpThreshold = 50,
  });
  final BluetoothDevice device;
  final _events = StreamController<MeasurementEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<BluetoothCharacteristic> _characteristics = [];
  final Map<String, int> _sequences = {};
  final Map<String, int> _lastReception = {};
  final Map<String, double> _lastValue = {};
  final Duration maxReceptionInterval;
  final double jumpThreshold;
  MeasurementSourceStatus _status = MeasurementSourceStatus.idle;
  int packets = 0;
  int invalidPackets = 0;
  int mtu = 0;
  bool captureRaw = false;
  @override
  Stream<MeasurementEvent> get measurements => _events.stream;
  @override
  MeasurementSourceStatus get status => _status;

  static double decode(List<int> bytes) {
    if (bytes.length != 1 || bytes.first < 0 || bytes.first > 255) {
      throw const FormatException(
        'Se esperaba exactamente un byte BLE (0–255)',
      );
    }
    // D-01: no convertir a porcentaje hasta validar firmware/rango.
    return bytes.first.toDouble();
  }

  @override
  Future<void> start() async {
    if (_status == MeasurementSourceStatus.running) return;
    if (!device.isConnected) {
      throw StateError('El dispositivo BLE está desconectado');
    }
    _sequences.clear();
    _lastReception.clear();
    _lastValue.clear();
    packets = 0;
    invalidPackets = 0;
    _status = MeasurementSourceStatus.running;
    try {
      final services = await device.discoverServices();
      mtu = device.mtuNow;
      AppLogger.instance.log(
        LogCategory.ble,
        LogLevel.info,
        'BLE services and MTU',
        data: {
          'services': services.map((s) => s.uuid.str).toList(),
          'mtu': mtu,
        },
      );
      final wanted = {
        'fuerza': (
          '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
          'beb5483e-36e1-4688-b7f5-ea07361b26a8',
        ),
        'fatiga': (
          '6b2f0001-0000-1000-8000-00805f9b34fb',
          '6b2f0002-0000-1000-8000-00805f9b34fb',
        ),
      };
      for (final entry in wanted.entries) {
        BluetoothCharacteristic? found;
        for (final service in services) {
          if (service.uuid != Guid(entry.value.$1)) continue;
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid == Guid(entry.value.$2)) {
              found = characteristic;
            }
          }
        }
        if (found == null) {
          throw StateError('No se encontró el canal ${entry.key}');
        }
        final channel = entry.key;
        _characteristics.add(found);
        // onValueReceived no reenvía el valor cacheado de una suscripción previa.
        _subscriptions.add(
          found.onValueReceived.listen((bytes) {
            if (_status != MeasurementSourceStatus.running) return;
            packets++;
            try {
              final value = decode(bytes);
              final now = DateTime.now().microsecondsSinceEpoch;
              final previousTime = _lastReception[channel];
              final previousValue = _lastValue[channel];
              if (previousTime != null &&
                  (now < previousTime ||
                      now - previousTime >
                          maxReceptionInterval.inMicroseconds)) {
                AppLogger.instance.log(
                  LogCategory.measurement,
                  LogLevel.warning,
                  'Unusual reception interval (not proof of BLE packet loss)',
                  data: {'channel': channel, 'interval_us': now - previousTime},
                );
              }
              if (previousValue != null &&
                  (value - previousValue).abs() > jumpThreshold) {
                AppLogger.instance.log(
                  LogCategory.measurement,
                  LogLevel.warning,
                  'Abrupt value change',
                  data: {
                    'channel': channel,
                    'previous': previousValue,
                    'value': value,
                  },
                );
              }
              _lastReception[channel] = now;
              _lastValue[channel] = value;
              final sequence = _sequences.update(
                channel,
                (n) => n + 1,
                ifAbsent: () => 0,
              );
              _events.add(
                MeasurementEvent(
                  channel: channel,
                  value: value,
                  receptionTimestampUs: now,
                  sequence: sequence,
                  source: MeasurementSourceType.ble,
                  rawBytes: captureRaw ? bytes : null,
                ),
              );
            } on FormatException catch (e, s) {
              invalidPackets++;
              AppLogger.instance.log(
                LogCategory.ble,
                LogLevel.error,
                'Invalid BLE payload',
                error: e.toString(),
                data: {'channel': channel, 'bytes': bytes},
              );
              _events.addError(e, s);
            }
          }, onError: _events.addError),
        );
        await found.setNotifyValue(true);
        AppLogger.instance.log(
          LogCategory.ble,
          LogLevel.info,
          'Notifications enabled',
          data: {'channel': channel},
        );
      }
      _subscriptions.add(
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected &&
              _status == MeasurementSourceStatus.running) {
            _events.addError(
              StateError('Desconexión BLE: ${device.disconnectReason}'),
            );
          }
        }),
      );
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _status = MeasurementSourceStatus.stopped;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    for (final characteristic in _characteristics) {
      if (device.isConnected) {
        try {
          await characteristic.setNotifyValue(false);
        } catch (e) {
          AppLogger.instance.log(
            LogCategory.ble,
            LogLevel.warning,
            'Cannot disable notifications',
            error: e.toString(),
          );
        }
      }
    }
    _characteristics.clear();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}
