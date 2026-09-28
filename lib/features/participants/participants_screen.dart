import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/features/session/screens/research_screen.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';

class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key});
  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsState();
}

class _ParticipantsState extends ConsumerState<ParticipantsScreen> {
  final _id = TextEditingController();
  final _alias = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _id.dispose();
    _alias.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(servicesProvider)
          .database
          .addParticipant(_id.text, alias: _alias.text.trim());
      _id.clear();
      _alias.clear();
      ref.invalidate(participantsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar. Usa un código único. $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ResearchScaffold(
    title: 'Participantes',
    children: [
      const Text(
        'Identifica a cada participante con un código, por ejemplo P01.',
      ),
      TextField(
        controller: _id,
        decoration: const InputDecoration(labelText: 'Código'),
      ),
      TextField(
        controller: _alias,
        decoration: const InputDecoration(labelText: 'Alias opcional'),
      ),
      ElevatedButton(
        onPressed: _busy ? null : _add,
        child: Text(_busy ? 'Guardando…' : 'Agregar participante'),
      ),
      if (_error != null) ResearchError(_error!),
      ref
          .watch(participantsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ResearchError(
              e.toString(),
              onRetry: () => ref.invalidate(participantsProvider),
            ),
            data: (rows) => rows.isEmpty
                ? const Text('Aún no hay participantes.')
                : Column(
                    children: [
                      for (final row in rows.where(
                        (r) => r['id'] != '__replay__',
                      ))
                        ListTile(
                          title: Text(row['id'] as String),
                          subtitle: Text(row['alias'] as String? ?? ''),
                        ),
                    ],
                  ),
          ),
    ],
  );
}
