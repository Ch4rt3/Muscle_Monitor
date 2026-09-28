import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/features/session/screens/research_screen.dart';
import 'export_repository.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportState();
}

class _ExportState extends ConsumerState<ExportScreen> {
  bool _includeDiagnostics = false;
  bool _busy = false;
  String? _error;
  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final services = ref.read(servicesProvider);
      final files = await ExportRepository(services.database).export(
        '${services.directory}/exports/csv_${DateTime.now().microsecondsSinceEpoch}',
        includeDiagnostics: _includeDiagnostics,
      );
      if (mounted) {
        await Share.shareXFiles(
          files.map((f) => XFile(f.path)).toList(),
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ResearchScaffold(
    title: 'Exportar sesiones',
    children: [
      const Text(
        'Se exportan participantes, sesiones, mediciones, decisiones de alerta y evaluaciones en archivos CSV UTF-8.',
      ),
      const Text(
        'Por defecto se incluyen únicamente sesiones BLE completas. Los tiempos son de recepción en Flutter, en microsegundos UTC.',
      ),
      SwitchListTile(
        title: const Text('Incluir simulaciones, replay e interrupciones'),
        value: _includeDiagnostics,
        onChanged: _busy
            ? null
            : (v) => setState(() => _includeDiagnostics = v),
      ),
      ElevatedButton(
        onPressed: _busy ? null : _export,
        child: Text(_busy ? 'Exportando…' : 'Exportar y compartir CSV'),
      ),
      if (_error != null) ResearchError(_error!, onRetry: _export),
      ref
          .watch(sessionsListProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ResearchError(
              e.toString(),
              onRetry: () => ref.invalidate(sessionsListProvider),
            ),
            data: (rows) => rows.isEmpty
                ? const Text('Aún no hay sesiones.')
                : Column(
                    children: [
                      for (final row in rows)
                        ListTile(
                          title: Text(
                            '${row['participant_id']} · ${row['exercise']}',
                          ),
                          subtitle: Text(
                            '${row['source']} · ${row['status']} · ${row['stored_count'] ?? 0} mediciones',
                          ),
                        ),
                    ],
                  ),
          ),
    ],
  );
}
