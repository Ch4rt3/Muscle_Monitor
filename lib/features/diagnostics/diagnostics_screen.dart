import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muscle_monitoring/core/acquisition/acquisition_providers.dart';
import 'package:muscle_monitoring/core/logging/app_logger.dart';
import 'package:muscle_monitoring/core/logging/log_entry.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/features/session/session_recorder.dart';
import 'package:muscle_monitoring/features/session/screens/research_screen.dart';
import 'package:muscle_monitoring/presentation/providers/ble_provider.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/app_card.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsState();
}

class _DiagnosticsState extends ConsumerState<DiagnosticsScreen> {
  Timer? _timer;
  LogCategory? _category;
  LogLevel _level = LogLevel.info;
  bool _debug = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _export(bool diagnostics) async {
    try {
      final services = ref.read(servicesProvider);
      final log = await AppLogger.instance.export(
        '${services.directory}/exports',
      );
      final files = [XFile(log.path)];
      if (diagnostics) {
        final bus = ref.read(measurementBusProvider);
        final file = File('${services.directory}/exports/diagnostics.json');
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'recovery': services.recoveryReports,
            'received': bus.received,
            'accepted': bus.totalEmitted,
            'rejected': bus.rejected,
            'channel_counts': bus.countsByChannel,
            'last_flutter_sequences': bus.sequencesByChannel,
            'session_report': ref.read(sessionProvider).report,
            'firmware_validation': 'pending',
            'firmware_packet_loss_detectable': false,
          }),
          flush: true,
        );
        files.add(XFile(file.path));
      }
      if (mounted) {
        await Share.shareXFiles(
          files,
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);
    final bus = ref.read(measurementBusProvider);
    final ble = ref.watch(bleProvider);
    final logger = AppLogger.instance;
    final config = session.session?.config ?? FatigueConfig.defaultConfig;
    final logs = logger
        .filter(category: _category, minLevel: _level)
        .reversed
        .take(50);
    return ResearchScaffold(
      title: 'Diagnóstico',
      children: [
        AppCard(
          child: Text(
            'Fuente: ${session.session?.source.name ?? 'inactiva'}\n'
            'Bluetooth: ${ble.connectionState.name}\nDispositivo: ${ble.currentDevice?.platformName ?? 'ninguno'}\n'
            'Recibidas: ${bus.received} · Aceptadas: ${bus.totalEmitted} · Rechazadas: ${bus.rejected}\n'
            'Frecuencia media por canal: ${controller.frequencyPerChannel.toStringAsFixed(1)} Hz\n'
            'SQLite: ${controller.recorder?.persisted ?? 0} guardadas · ${controller.recorder?.pending ?? 0} pendientes\n'
            'Último lote: ${ref.read(servicesProvider).database.lastBatchMs} ms\n'
            'Reintentos: ${controller.recorder?.retries ?? 0}',
          ),
        ),
        for (final e in bus.latest.entries)
          Text(
            '${e.key}: ${bus.countsByChannel[e.key]} mediciones · ${controller.frequencyForChannel(e.key).toStringAsFixed(1)} Hz\n'
            'Último valor: ${e.value.value.toStringAsFixed(1)} · secuencia Flutter ${e.value.sequence} · ${e.value.receptionTimestampUs} µs',
          ),
        Text(
          'Umbrales: ${config.thresholdLow} / ${config.thresholdMedium} / ${config.thresholdHigh}\n'
          'Promedio: ${config.movingAverageWindow} muestras · Cooldown: ${config.cooldown.inMilliseconds / 1000} s\n'
          'Algoritmo: ${config.algorithmVersion}',
        ),
        const Text(
          'El firmware aún requiere validación. La secuencia Flutter no detecta pérdidas de paquetes antes de la recepción.',
        ),
        if (session.error != null) ResearchError(session.error!),
        if (controller.recorder?.lastError != null)
          ResearchError(controller.recorder!.lastError!),
        if (logger.persistenceError != null)
          ResearchError(
            'No se pueden persistir logs: ${logger.persistenceError}',
          ),
        Text(
          'Entradas críticas recuperadas: ${logger.recoveredEntries.length}',
        ),
        for (final report in ref.read(servicesProvider).recoveryReports)
          Text(
            'Recuperación ${report['session']}: ${report['ok'] == true ? 'integridad verificada' : 'requiere revisión'}',
          ),
        if (!session.active)
          OutlinedButton(
            onPressed: () async {
              final services = ref.read(servicesProvider);
              services.recoveryReports = await SessionRecorder.recover(
                services.database,
              );
              if (mounted) setState(() {});
            },
            child: const Text('Reintentar recuperación'),
          ),
        SwitchListTile(
          title: const Text('Registro detallado'),
          value: _debug,
          onChanged: (v) {
            setState(() => _debug = v);
            if (v) {
              logger.enableDebug();
            } else {
              logger.disableDebug();
            }
          },
        ),
        DropdownButtonFormField<LogCategory?>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            for (final c in LogCategory.values)
              DropdownMenuItem(value: c, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        DropdownButtonFormField(
          initialValue: _level,
          decoration: const InputDecoration(labelText: 'Nivel mínimo'),
          items: [
            for (final level in LogLevel.values)
              DropdownMenuItem(value: level, child: Text(level.name)),
          ],
          onChanged: (v) => setState(() => _level = v!),
        ),
        OutlinedButton(
          onPressed: () => _export(false),
          child: const Text('Exportar logs'),
        ),
        OutlinedButton(
          onPressed: () => _export(true),
          child: const Text('Exportar diagnóstico'),
        ),
        if (_message != null) ResearchError(_message!),
        if (logs.isEmpty) const Text('No hay entradas para este filtro.'),
        for (final log in logs)
          SelectableText(
            '[${log.level.name}] ${log.category.name}: ${log.message}\n${log.error ?? log.data ?? ''}',
          ),
      ],
    );
  }
}
