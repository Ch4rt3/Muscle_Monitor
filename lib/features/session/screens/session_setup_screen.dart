import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/core/acquisition/fatigue_processor.dart';
import 'package:muscle_monitoring/core/acquisition/simulation_source.dart';
import 'package:muscle_monitoring/core/models/fatigue_config.dart';
import 'package:muscle_monitoring/core/models/measurement_event.dart';
import 'package:muscle_monitoring/presentation/providers/ble_provider.dart';
import 'package:muscle_monitoring/presentation/providers/page_index_provider.dart';
import '../session_provider.dart';
import 'research_screen.dart';

class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key});
  @override
  ConsumerState<SessionSetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<SessionSetupScreen> {
  final _exercise = TextEditingController();
  final _notes = TextEditingController();
  final _low = TextEditingController(text: '30');
  final _medium = TextEditingController(text: '50');
  final _high = TextEditingController(text: '75');
  final _window = TextEditingController(text: '3');
  final _cooldown = TextEditingController(text: '5');
  String? _participant;
  String? _error;
  bool _captureRaw = false;
  MeasurementSourceType _type = MeasurementSourceType.simulation;
  ExperimentCondition _condition = ExperimentCondition.withAlerts;
  FeedbackPolicy _feedback = FeedbackPolicy.pending;
  @override
  void dispose() {
    for (final c in [
      _exercise,
      _notes,
      _low,
      _medium,
      _high,
      _window,
      _cooldown,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      if (_participant == null) throw StateError('Selecciona un participante');
      final ble = ref.read(bleProvider.notifier);
      ble.source?.captureRaw = _captureRaw;
      final input = _type == MeasurementSourceType.simulation
          ? SimulationMeasurementSource()
          : ble.source;
      if (input == null) {
        throw StateError('Conecta el dispositivo desde la pantalla Bluetooth');
      }
      final config = FatigueConfig(
        thresholdLow: double.parse(_low.text),
        thresholdMedium: double.parse(_medium.text),
        thresholdHigh: double.parse(_high.text),
        movingAverageWindow: int.parse(_window.text),
        cooldown: Duration(
          microseconds: (double.parse(_cooldown.text) * 1000000).round(),
        ),
      );
      await ref
          .read(sessionProvider.notifier)
          .start(
            participant: _participant!,
            exercise: _exercise.text,
            input: input,
            type: _type,
            condition: _condition,
            feedbackPolicy: _feedback,
            config: config,
            deviceName: ref.read(bleProvider).currentDevice?.platformName,
            notes: _notes.text,
          );
      if (mounted) {
        ref.read(pageIndexProvider.notifier).state = 1;
        context.go('/home/1');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(sessionProvider).busy;
    return ResearchScaffold(
      title: 'Preparar sesión',
      children: [
        ref
            .watch(participantsProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ResearchError(
                e.toString(),
                onRetry: () => ref.invalidate(participantsProvider),
              ),
              data: (rows) => DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _participant,
                decoration: const InputDecoration(labelText: 'Participante'),
                items: [
                  for (final r in rows.where((r) => r['id'] != '__replay__'))
                    DropdownMenuItem(
                      value: r['id'] as String,
                      child: Text(r['id'] as String),
                    ),
                ],
                onChanged: (v) => setState(() => _participant = v),
              ),
            ),
        TextButton(
          onPressed: () => context.push('/participants'),
          child: const Text('Agregar participante'),
        ),
        TextField(
          controller: _exercise,
          decoration: const InputDecoration(labelText: 'Ejercicio'),
        ),
        DropdownButtonFormField(
          isExpanded: true,
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Fuente'),
          items: const [
            DropdownMenuItem(
              value: MeasurementSourceType.simulation,
              child: Text('Simulación'),
            ),
            DropdownMenuItem(
              value: MeasurementSourceType.ble,
              child: Text('ESP32 por Bluetooth'),
            ),
          ],
          onChanged: (v) => setState(() => _type = v!),
        ),
        DropdownButtonFormField(
          isExpanded: true,
          initialValue: _condition,
          decoration: const InputDecoration(labelText: 'Condición'),
          items: const [
            DropdownMenuItem(
              value: ExperimentCondition.withAlerts,
              child: Text('Con alertas'),
            ),
            DropdownMenuItem(
              value: ExperimentCondition.withoutAlerts,
              child: Text('Sin alertas'),
            ),
          ],
          onChanged: (v) => setState(() => _condition = v!),
        ),
        if (_condition == ExperimentCondition.withoutAlerts) ...[
          DropdownButtonFormField(
            isExpanded: true,
            initialValue: _feedback,
            decoration: const InputDecoration(labelText: 'Gráfica de fatiga'),
            items: const [
              DropdownMenuItem(
                value: FeedbackPolicy.pending,
                child: Text('Decisión pendiente'),
              ),
              DropdownMenuItem(
                value: FeedbackPolicy.keepChart,
                child: Text('Visible, sin interpretación'),
              ),
              DropdownMenuItem(
                value: FeedbackPolicy.hideChart,
                child: Text('Oculta'),
              ),
            ],
            onChanged: (v) => setState(() => _feedback = v!),
          ),
          const Text(
            'La opción pendiente permite pruebas simuladas. Una sesión real requiere definir la retroalimentación visible.',
          ),
        ],
        ExpansionTile(
          title: const Text('Configuración de fatiga'),
          children: [
            for (final field in [
              (_low, 'Umbral leve'),
              (_medium, 'Umbral moderado'),
              (_high, 'Umbral severo'),
              (_window, 'Ventana de promedio'),
              (_cooldown, 'Intervalo entre alertas (s)'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: TextField(
                  controller: field.$1,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: field.$2),
                ),
              ),
          ],
        ),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Notas / orden de condición',
          ),
        ),
        if (_type == MeasurementSourceType.ble)
          SwitchListTile(
            title: const Text('Capturar bytes originales para diagnóstico'),
            value: _captureRaw,
            onChanged: (value) => setState(() => _captureRaw = value),
          ),
        if (_type == MeasurementSourceType.ble)
          const Text(
            'Pendiente validar con firmware: significado, rango y frecuencia de ambos canales.',
          ),
        if (_error != null) ResearchError(_error!),
        ElevatedButton(
          onPressed: busy ? null : _start,
          child: Text(busy ? 'Preparando…' : 'Iniciar sesión'),
        ),
      ],
    );
  }
}
