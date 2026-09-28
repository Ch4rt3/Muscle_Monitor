import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide LogLevel;
import 'package:permission_handler/permission_handler.dart';
import 'package:muscle_monitoring/core/acquisition/acquisition_providers.dart';
import 'package:muscle_monitoring/core/acquisition/ble_measurement_source.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';

enum BleConnectionState { idle, connecting, connected, disconnected }

class BleDataPoint {
  const BleDataPoint(this.x, this.y);
  final double x;
  final double y;
}

class BleState {
  const BleState({
    this.dataFuerza = const [],
    this.dataFatiga = const [],
    this.connectionState = BleConnectionState.idle,
    this.currentDevice,
    this.error,
  });
  final List<BleDataPoint> dataFuerza;
  final List<BleDataPoint> dataFatiga;
  final BleConnectionState connectionState;
  final BluetoothDevice? currentDevice;
  final String? error;
}

class BleNotifier extends StateNotifier<BleState> {
  BleNotifier(this._ref) : super(const BleState()) {
    _busSubscription = _ref
        .read(measurementBusProvider)
        .stream
        .listen(_onEvent);
    _ref.listen(sessionProvider.select((s) => s.session?.id), (previous, next) {
      if (next != null && next != previous) {
        state = BleState(
          connectionState: state.connectionState,
          currentDevice: state.currentDevice,
        );
      }
    });
  }
  final Ref _ref;
  StreamSubscription<MeasurementEvent>? _busSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  BleMeasurementSource? source;
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  void _onEvent(MeasurementEvent event) {
    final point = BleDataPoint(event.sequence.toDouble(), event.value);
    List<BleDataPoint> append(List<BleDataPoint> old) =>
        List.unmodifiable([...old.skip(old.length >= 200 ? 1 : 0), point]);
    state = BleState(
      dataFuerza: event.channel == 'fuerza'
          ? append(state.dataFuerza)
          : state.dataFuerza,
      dataFatiga: event.channel == 'fatiga'
          ? append(state.dataFatiga)
          : state.dataFatiga,
      currentDevice: state.currentDevice,
      connectionState: state.connectionState,
    );
  }

  void _connection(
    BleConnectionState value,
    BluetoothDevice? device, [
    String? error,
  ]) {
    state = BleState(
      dataFuerza: state.dataFuerza,
      dataFatiga: state.dataFatiga,
      connectionState: value,
      currentDevice: device,
      error: error,
    );
  }

  Future<void> startDevicesScan() async {
    if (_ref.read(sessionProvider).active) return;
    try {
      if (Platform.isAndroid) {
        final permissions = await [
          Permission.locationWhenInUse,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        if (permissions.values.any((s) => !s.isGranted)) {
          throw StateError('Permisos Bluetooth pendientes');
        }
      }
      AppLogger.instance.log(
        LogCategory.ble,
        LogLevel.info,
        'BLE scan started',
      );
      await _scanSubscription?.cancel();
      await _scanningSubscription?.cancel();
      final seen = <String>{};
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (!seen.add(result.device.remoteId.str)) continue;
          AppLogger.instance.log(
            LogCategory.ble,
            LogLevel.info,
            'BLE device found',
            data: {'name': result.device.platformName, 'rssi': result.rssi},
          );
        }
      });
      var wasScanning = false;
      _scanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
        if (wasScanning && !scanning) {
          AppLogger.instance.log(
            LogCategory.ble,
            LogLevel.info,
            'BLE scan stopped',
          );
        }
        wasScanning = scanning;
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      AppLogger.instance.log(
        LogCategory.ble,
        LogLevel.error,
        'BLE scan failed',
        error: e.toString(),
      );
      _connection(state.connectionState, state.currentDevice, e.toString());
    }
  }

  Future<void> stopDevicesScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectDevice(BluetoothDevice device) async {
    if (_ref.read(sessionProvider).active) return;
    await disconnectDevice();
    _connection(BleConnectionState.connecting, device);
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      source = BleMeasurementSource(device);
      _connection(BleConnectionState.connected, device);
      _connectionSubscription = device.connectionState.listen((status) {
        if (status == BluetoothConnectionState.disconnected) {
          _connection(BleConnectionState.disconnected, null);
          AppLogger.instance.log(
            LogCategory.ble,
            LogLevel.warning,
            'BLE disconnected',
            data: {'cause': device.disconnectReason.toString()},
          );
        }
      });
      AppLogger.instance.log(
        LogCategory.ble,
        LogLevel.info,
        'BLE connected',
        data: {'name': device.platformName},
      );
    } catch (e, s) {
      AppLogger.instance.log(
        LogCategory.ble,
        LogLevel.error,
        'BLE connection failed',
        error: e.toString(),
        stackTrace: s.toString(),
      );
      _connection(BleConnectionState.disconnected, null, e.toString());
    }
  }

  Future<void> disconnectDevice() async {
    if (_ref.read(sessionProvider).active) {
      await _ref.read(sessionProvider.notifier).stop(status: 'interrupted');
    }
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await source?.dispose();
    source = null;
    final device = state.currentDevice;
    if (device != null && device.isConnected) await device.disconnect();
    _connection(BleConnectionState.disconnected, null);
  }

  @override
  void dispose() {
    unawaited(_busSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_scanSubscription?.cancel());
    unawaited(_scanningSubscription?.cancel());
    unawaited(source?.dispose());
    super.dispose();
  }
}

final bleProvider = StateNotifierProvider<BleNotifier, BleState>(
  (ref) => BleNotifier(ref),
);
