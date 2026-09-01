import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/presentation/providers/ble_provider.dart';
import 'package:muscle_monitoring/presentation/widgets/ble/device_card.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/bluetooth_search_animation.dart';

class BleScreen extends ConsumerWidget {
  static const String name = 'ble-screen';

  const BleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleController = ref.read(bleProvider.notifier);
    final bleState = ref.watch(bleProvider);
    final isConnected =
        bleState.connectionState == BleConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar dispositivo'),
      ),
      body: Column(
        children: [
          // Lista de dispositivos encontrados
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: bleController.scanResults,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.lg,
                    ),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final data = snapshot.data![index];
                      return DeviceCard(
                        data: data,
                        bleController: bleController,
                      );
                    },
                  );
                } else {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BluetoothSearchAnimation(size: 200),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            'Buscando dispositivos...',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Asegúrate de que tu dispositivo\nesté encendido y cerca.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          // Botones de acción fijos abajo
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => bleController.startDevicesScan(),
                    child: const Text('Iniciar búsqueda'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => bleController.stopDevicesScan(),
                    child: const Text('Detener búsqueda'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
