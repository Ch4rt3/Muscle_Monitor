// Provider para el índice de la pestaña actual
import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// final pageIndexProvider = StateProvider<int>((ref) => 0);

enum BleConnectionState { idle, connecting, connected, disconnected }

class BleDataPoint {
  final double x;
  final double y;
  BleDataPoint(this.x, this.y);
}

class BleState {
  final List<BleDataPoint> dataFuerza;
  final List<BleDataPoint> dataFatiga;
  final BleConnectionState connectionState;
  final BluetoothDevice? currentDevice;

  BleState({
    required this.dataFuerza,
    required this.dataFatiga,
    required this.connectionState,
    required this.currentDevice,
  });

  BleState copyWith({
    List<BleDataPoint>? dataFuerza,
    List<BleDataPoint>? dataFatiga,
    BleConnectionState? connectionState,
    BluetoothDevice? currentDevice,
  }) {
    return BleState(
      dataFuerza: dataFuerza ?? this.dataFuerza,
      dataFatiga: dataFatiga ?? this.dataFatiga,
      connectionState: connectionState ?? this.connectionState,
      currentDevice: currentDevice ?? this.currentDevice,
    );
  }
}

class BleNotifier extends StateNotifier<BleState> {
  BleNotifier()
    : super(
        BleState(
          dataFuerza: [],
          dataFatiga: [],
          connectionState: BleConnectionState.idle,
          currentDevice: null,
        ),
      );

  double _xValue = 0;
  // Máximo de puntos a mantener en memoria (ajusta según rendimiento/UX)
  final int maxDataPoints = 200;
  Timer? _simTimer;
  // ignore: unused_field
  final Random _rand = Random(); // Usado en modo simulación (comentado abajo)

  // Variables para simulación de ejercicio
  int _simStep = 0;

  // Subscripciones a los streams BLE (para cancelarlas al desconectar)
  StreamSubscription? _fuerzaSubscription;
  StreamSubscription? _fatigaSubscription;

  // UUIDs esperadas del ESP32 (en minúsculas para comparación)
  static const String serviceFuerzaUuid =
      '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String charFuerzaUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  // UUIDs de FATIGA (formato completo y corto)
  static const String serviceFatigaUuid =
      '6b2f0001-0000-1000-8000-00805f9b34fb';
  static const String serviceFatigaUuidCorto =
      '6b2f0001'; // UUID corto (16-bit)

  static const String charFatigaUuid = '6b2f0002-0000-1000-8000-00805f9b34fb';
  static const String charFatigaUuidCorto = '6b2f0002'; // UUID corto (16-bit)

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  void setConnectionState(BleConnectionState newState) {
    state = state.copyWith(connectionState: newState);
  }

  void setCurrentDevice(BluetoothDevice? device) {
    state = state.copyWith(currentDevice: device);
    // Si se desconecta, cancelamos todas las suscripciones y timers
    if (device == null) {
      _simTimer?.cancel();
      _simTimer = null;
      _fuerzaSubscription?.cancel();
      _fuerzaSubscription = null;
      _fatigaSubscription?.cancel();
      _fatigaSubscription = null;
    }
  }

  void addFuerza(double y) {
    final newData = [...state.dataFuerza, BleDataPoint(_xValue, y)];
    if (newData.length > maxDataPoints) {
      final excess = newData.length - maxDataPoints;
      newData.removeRange(0, excess);
    }
    _xValue += 1;
    state = state.copyWith(dataFuerza: newData);
  }

  void addFatiga(double y) {
    final newData = [...state.dataFatiga, BleDataPoint(_xValue, y)];
    if (newData.length > maxDataPoints) {
      final excess = newData.length - maxDataPoints;
      newData.removeRange(0, excess);
    }
    _xValue += 1;
    state = state.copyWith(dataFatiga: newData);
  }

  Future<void> startDevicesScan() async {
    if (await Permission.locationWhenInUse.request().isGranted) {
      if (await Permission.bluetoothScan.request().isGranted) {
        if (await Permission.bluetoothConnect.request().isGranted) {
          await FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
        }
      }
    }
  }

  Future<void> stopDevicesScan() async {
    if (await Permission.bluetoothScan.request().isGranted) {
      if (await Permission.bluetoothConnect.request().isGranted) {
        FlutterBluePlus.stopScan();
      }
    }
  }

  Future<void> connectDevice(BluetoothDevice device) async {
    setCurrentDevice(device);
    setConnectionState(BleConnectionState.connecting);

    try {
      // Conectar al dispositivo
      await device.connect(timeout: Duration(seconds: 15));
      setConnectionState(BleConnectionState.connected);

      // Escuchar cambios de estado de conexión
      device.connectionState.listen((connState) {
        if (connState == BluetoothConnectionState.connected) {
          setConnectionState(BleConnectionState.connected);
        } else if (connState == BluetoothConnectionState.disconnected) {
          setConnectionState(BleConnectionState.disconnected);
          setCurrentDevice(null);
        }
      });

      // Esperar a que el dispositivo esté completamente listo
      await Future.delayed(const Duration(seconds: 2));

      // Descubrir servicios BLE
      List<BluetoothService> services = await device.discoverServices();

      BluetoothCharacteristic? fuerzaChar;
      BluetoothCharacteristic? fatigaChar;

      // Recorrer servicios y características
      for (var service in services) {
        final svcUuid = service.uuid.toString().toLowerCase();

        for (var characteristic in service.characteristics) {
          final charUuid = characteristic.uuid.toString().toLowerCase();

          // Buscar characteristic de FUERZA
          if (svcUuid == serviceFuerzaUuid.toLowerCase() &&
              charUuid == charFuerzaUuid.toLowerCase()) {
            fuerzaChar = characteristic;
          }

          // Buscar characteristic de FATIGA (soporta UUID corto y largo)
          if ((svcUuid == serviceFatigaUuid.toLowerCase() ||
                  svcUuid == serviceFatigaUuidCorto.toLowerCase()) &&
              (charUuid == charFatigaUuid.toLowerCase() ||
                  charUuid == charFatigaUuidCorto.toLowerCase())) {
            fatigaChar = characteristic;
          }
        }
      }

      // Suscribirse a la characteristic de FUERZA
      if (fuerzaChar != null) {
        await fuerzaChar.setNotifyValue(true);
        await _fuerzaSubscription?.cancel();

        _fuerzaSubscription = fuerzaChar.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            final v = value.first.toDouble();
            addFuerza(v);
          }
        });
      }

      // Suscribirse a la characteristic de FATIGA
      if (fatigaChar != null) {
        await fatigaChar.setNotifyValue(true);
        await _fatigaSubscription?.cancel();

        _fatigaSubscription = fatigaChar.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            final v = value.first.toDouble();
            addFatiga(v);
          }
        });
      }

      print('✅ Dispositivo ${device.platformName} conectado exitosamente');

      // ════════════════════════════════════════════════════════════════
      // 🎮 MODO SIMULACIÓN DE EJERCICIO
      // ════════════════════════════════════════════════════════════════
      // ⚠️ Comenta/descomenta la siguiente línea para activar/desactivar
      // _startExerciseSimulation(); // ← COMENTAR esta línea para usar BLE real
      // ════════════════════════════════════════════════════════════════
    } catch (e) {
      print('❌ Error al conectar: $e');
      setConnectionState(BleConnectionState.disconnected);
      setCurrentDevice(null);
    }
  }

  /// 🎮 Simula un ejercicio realista con patrón cíclico
  /// Patrón: Calentamiento (0-40) → Esfuerzo (40-60) → Fatiga (60-100) → Descanso (100-20) → Repetir
  void _startExerciseSimulation() {
    _simTimer?.cancel();
    _simStep = 0;

    const int totalSteps = 500; // 20 segundos por ciclo @ 25 pasos/segundo
    const int phaseLength = 125; // 5 segundos por fase

    _simTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      // Calcular fase actual (0=Calentamiento, 1=Esfuerzo, 2=Fatiga, 3=Descanso)
      int phase = (_simStep ~/ phaseLength) % 4;
      int stepInPhase = _simStep % phaseLength;
      double progress = stepInPhase / phaseLength; // 0.0 a 1.0

      double fatigaValue;
      double fuerzaValue;

      switch (phase) {
        case 0: // Calentamiento: 0 → 40
          fatigaValue = 0 + (40 * progress);
          fuerzaValue = 20 + (30 * progress);
          break;

        case 1: // Esfuerzo moderado: 40 → 60
          fatigaValue = 40 + (20 * progress);
          fuerzaValue = 50 + (30 * progress);
          break;

        case 2: // Fatiga alta: 60 → 100
          fatigaValue = 60 + (40 * progress);
          fuerzaValue = 80 + (15 * progress);
          break;

        case 3: // Descanso: 100 → 20
          fatigaValue = 100 - (80 * progress);
          fuerzaValue = 95 - (65 * progress);
          break;

        default:
          fatigaValue = 0;
          fuerzaValue = 0;
      }

      // Agregar variabilidad natural (±5 unidades)
      fatigaValue += (_rand.nextDouble() - 0.5) * 10;
      fuerzaValue += (_rand.nextDouble() - 0.5) * 10;

      // Clampear valores entre 0-100
      fatigaValue = fatigaValue.clamp(0, 100);
      fuerzaValue = fuerzaValue.clamp(0, 100);

      addFuerza(fuerzaValue);
      addFatiga(fatigaValue);

      _simStep = (_simStep + 1) % totalSteps;
    });
  }

  /// Desconectar dispositivo BLE limpiamente
  Future<void> disconnectDevice() async {
    final device = state.currentDevice;
    if (device == null) return;

    try {
      // Cancelar suscripciones
      await _fuerzaSubscription?.cancel();
      _fuerzaSubscription = null;

      await _fatigaSubscription?.cancel();
      _fatigaSubscription = null;

      // Cancelar timer de simulación
      _simTimer?.cancel();
      _simTimer = null;

      // Desconectar
      await device.disconnect();

      setConnectionState(BleConnectionState.disconnected);
      setCurrentDevice(null);
    } catch (e) {
      print('❌ Error al desconectar: $e');
    }
  }

  @override
  void dispose() {
    // Limpiar recursos al destruir el provider
    _fuerzaSubscription?.cancel();
    _fatigaSubscription?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }
}

final bleProvider = StateNotifierProvider<BleNotifier, BleState>(
  (ref) => BleNotifier(),
);
