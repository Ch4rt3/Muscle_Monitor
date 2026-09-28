import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muscle_monitoring/core/acquisition/replay_source.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/features/session/screens/research_screen.dart';
import 'package:muscle_monitoring/features/alerts/widgets/fatigue_indicator.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';

final recordingsProvider = FutureProvider<List<File>>((ref) async {
  ref.watch(sessionProvider.select((s) => s.lastSessionId));
  final dir = Directory('${ref.watch(servicesProvider).directory}/recordings');
  if (!await dir.exists()) return [];
  final files = (await dir.list().toList())
      .whereType<File>()
      .where((f) => f.path.endsWith('.jsonl'))
      .toList();
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return files;
});

class ReplayScreen extends ConsumerStatefulWidget {
  const ReplayScreen({super.key});
  @override
  ConsumerState<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends ConsumerState<ReplayScreen> {
  Timer? _timer;
  String? _error;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _play(File file) async {
    setState(() => _error = null);
    try {
      await ref.read(sessionProvider.notifier).startReplay(file);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final controller = ref.read(sessionProvider.notifier);
    final source = controller.source;
    final replay = source is ReplayMeasurementSource ? source : null;
    return ResearchScaffold(
      title: 'Grabaciones y reproducción',
      children: [
        const Text(
          'La reproducción usa el tiempo y la configuración originales. Sus datos quedan separados de las exportaciones experimentales.',
        ),
        if (session.session?.showInterpretation == true)
          const FatigueIndicator(),
        if (replay != null && session.active) ...[
          LinearProgressIndicator(value: replay.progress),
          Text('${replay.currentEventIndex} / ${replay.totalEvents} eventos'),
          for (final warning in replay.recording.warnings)
            ResearchError(warning),
          DropdownButtonFormField(
            initialValue: replay.playbackSpeed,
            decoration: const InputDecoration(labelText: 'Velocidad'),
            items: [
              for (final speed in [0.5, 1.0, 2.0, 4.0])
                DropdownMenuItem(value: speed, child: Text('${speed}x')),
            ],
            onChanged: (v) => setState(() => replay.setSpeed(v!)),
          ),
          OutlinedButton(
            onPressed: () async {
              if (replay.replayState == ReplayState.paused) {
                await replay.resume();
              } else {
                await replay.pause();
              }
              if (mounted) setState(() {});
            },
            child: Text(
              replay.replayState == ReplayState.paused ? 'Reanudar' : 'Pausar',
            ),
          ),
          ElevatedButton(
            onPressed: session.busy
                ? null
                : () => controller.stop(status: 'interrupted'),
            child: const Text('Detener reproducción'),
          ),
        ],
        if (_error != null) ResearchError(_error!),
        if (session.error != null) ResearchError(session.error!),
        if (session.report?['comparison'] != null) ...[
          Text(
            (session.report!['comparison'] as Map)['match'] == true
                ? 'Comparación: resultados idénticos'
                : 'Comparación: diferencias o datos originales incompletos',
          ),
          OutlinedButton(
            onPressed: () async {
              final path =
                  '${ref.read(servicesProvider).directory}/recordings/${session.lastSessionId}_comparison.json';
              try {
                await Share.shareXFiles([
                  XFile(path),
                ], sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1));
              } catch (e) {
                if (mounted) setState(() => _error = e.toString());
              }
            },
            child: const Text('Compartir comparación'),
          ),
        ],
        if (!session.active)
          ref
              .watch(recordingsProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => ResearchError(
                  e.toString(),
                  onRetry: () => ref.invalidate(recordingsProvider),
                ),
                data: (files) => files.isEmpty
                    ? const Text(
                        'Aún no hay grabaciones. Inicia una sesión simulada para crear una.',
                      )
                    : Column(
                        children: [
                          for (final file in files)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              title: Text(
                                file.uri.pathSegments.last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                file.lastModifiedSync().toLocal().toString(),
                              ),
                              trailing: IconButton(
                                tooltip: 'Reproducir desde el inicio',
                                icon: const Icon(Icons.play_circle_outline),
                                onPressed: session.busy
                                    ? null
                                    : () => _play(file),
                              ),
                            ),
                        ],
                      ),
              ),
      ],
    );
  }
}
