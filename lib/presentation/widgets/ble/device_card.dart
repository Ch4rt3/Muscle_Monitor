import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/presentation/providers/ble_provider.dart';
import 'package:muscle_monitoring/presentation/providers/page_index_provider.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/app_card.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/bluetooth_icon_container.dart';

class DeviceCard extends ConsumerWidget {
  final ScanResult data;
  final BleNotifier bleController;

  const DeviceCard({
    super.key,
    required this.data,
    required this.bleController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(bleProvider).connectionState;
    final currentDevice = ref.watch(bleProvider).currentDevice;
    final textTheme = Theme.of(context).textTheme;

    final isCurrent = currentDevice?.remoteId == data.device.remoteId;

    final deviceStatus = switch (connectionState) {
      BleConnectionState.connecting when isCurrent => 'connecting',
      BleConnectionState.connected when isCurrent => 'connected',
      _ => 'idle',
    };

    Widget trailing = switch (deviceStatus) {
      'connecting' => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      'connected' => const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 24,
        ),
      _ => Text(
          '${data.rssi} dBm',
          style: textTheme.labelSmall,
        ),
    };

    final isDisabled =
        connectionState == BleConnectionState.connecting && !isCurrent;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.cardPaddingCompact),
            child: InkWell(
              borderRadius: AppRadius.xlRadius,
              onTap: isDisabled
                  ? null
                  : () async {
                      await bleController.connectDevice(data.device);
                      ref.read(pageIndexProvider.notifier).state = 1;
                    },
              child: Row(
                children: [
                  const BluetoothIconContainer(),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.device.advName.isNotEmpty
                              ? data.device.advName
                              : 'Dispositivo desconocido',
                          style: textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          data.device.remoteId.str,
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
