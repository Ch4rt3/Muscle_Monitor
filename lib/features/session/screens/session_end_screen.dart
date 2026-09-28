import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../session_provider.dart';
import 'research_screen.dart';

class SessionEndScreen extends ConsumerStatefulWidget {
  const SessionEndScreen({super.key});
  @override
  ConsumerState<SessionEndScreen> createState() => _EndState();
}

class _EndState extends ConsumerState<SessionEndScreen> {
  final _value = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'rpe';
  String? _message;
  bool _busy = false;
  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final id = ref.read(sessionProvider).lastSessionId;
      if (id == null) throw StateError('No hay sesión finalizada');
      await ref
          .read(servicesProvider)
          .database
          .addEvaluation(
            id,
            _type,
            double.parse(_value.text),
            notes: _notes.text,
          );
      if (mounted) {
        setState(() {
          _message = 'Evaluación guardada';
          _value.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionProvider);
    return ResearchScaffold(
      title: 'Sesión finalizada',
      children: [
        if (state.error != null) ResearchError(state.error!),
        if (state.report != null)
          Text(
            'Integridad: ${state.report!['ok'] == true ? 'verificada' : 'requiere revisión'}\n'
            '${state.report!['stored']} mediciones guardadas / ${state.report!['expected']} esperadas',
          ),
        const Text(
          'Evaluación opcional. Registra el instrumento y la escala acordados en las notas; el momento de aplicación sigue pendiente de definición metodológica.',
        ),
        DropdownButtonFormField(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Evaluación'),
          items: const [
            DropdownMenuItem(value: 'rpe', child: Text('RPE')),
            DropdownMenuItem(
              value: 'perceived_fatigue',
              child: Text('Fatiga percibida'),
            ),
            DropdownMenuItem(value: 'comfort', child: Text('Comodidad')),
          ],
          onChanged: (v) => setState(() => _type = v!),
        ),
        TextField(
          controller: _value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor'),
        ),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Instrumento, escala y notas',
          ),
        ),
        if (_message != null) Text(_message!),
        OutlinedButton(
          onPressed: _busy ? null : _save,
          child: const Text('Guardar evaluación'),
        ),
        ElevatedButton(
          onPressed: () => context.go('/research'),
          child: const Text('Volver a investigador'),
        ),
      ],
    );
  }
}
