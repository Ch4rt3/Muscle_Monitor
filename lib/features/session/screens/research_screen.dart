import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:muscle_monitoring/config/theme/design_tokens.dart';
import 'package:muscle_monitoring/features/session/session_provider.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/app_card.dart';

final participantsProvider = FutureProvider(
  (ref) => ref.watch(servicesProvider).database.participants(),
);
final sessionsListProvider = FutureProvider((ref) {
  ref.watch(sessionProvider.select((s) => s.lastSessionId));
  return ref.watch(servicesProvider).database.sessions();
});

class ResearchScreen extends ConsumerWidget {
  const ResearchScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recoveries = ref.watch(servicesProvider).recoveryReports;
    return ResearchScaffold(
      title: 'Investigador',
      children: [
        Text(
          'Sesiones y herramientas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (recoveries.isNotEmpty)
          Text(
            '${recoveries.length} sesiones revisadas al reiniciar. Consulta su integridad en diagnóstico.',
          ),
        for (final item in const [
          ('Participantes', '/participants'),
          ('Preparar sesión', '/session/setup'),
          ('Diagnóstico', '/diagnostics'),
          ('Grabaciones y reproducción', '/replay'),
          ('Exportar sesiones', '/export'),
        ])
          OutlinedButton(
            onPressed: () => context.push(item.$2),
            child: Text(item.$1),
          ),
      ],
    );
  }
}

class ResearchScaffold extends StatelessWidget {
  const ResearchScaffold({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          itemCount: children.length,
          separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.lg),
          itemBuilder: (_, index) => children[index],
        ),
      ),
    ),
  );
}

class ResearchError extends StatelessWidget {
  const ResearchError(this.message, {super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
