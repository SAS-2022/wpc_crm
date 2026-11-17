import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'project.dart';
import 'projects_repository.dart';

String projectStageLabel(AppLocalizations l10n, ProjectStage s) => switch (s) {
      ProjectStage.initiated => l10n.projectStageInitiated,
      ProjectStage.samplesSubmitted => l10n.projectStageSamples,
      ProjectStage.approved => l10n.projectStageApproved,
      ProjectStage.rejected => l10n.projectStageRejected,
    };

IconData projectStageIcon(ProjectStage s) => switch (s) {
      ProjectStage.initiated => Icons.flag_outlined,
      ProjectStage.samplesSubmitted => Icons.inventory_2_outlined,
      ProjectStage.approved => Icons.verified_outlined,
      ProjectStage.rejected => Icons.block,
    };

Color projectStageColor(ProjectStage s) => switch (s) {
      ProjectStage.initiated => const Color(0xFF546E7A),
      ProjectStage.samplesSubmitted => const Color(0xFF1565C0),
      ProjectStage.approved => const Color(0xFF2E7D32),
      ProjectStage.rejected => const Color(0xFFC62828),
    };

/// Project pins on the clients map: kept clear of the visit-status and
/// salesperson colours.
const projectPinColor = Color(0xFFAD1457);

String materialStatusLabel(AppLocalizations l10n, MaterialStatus s) =>
    s == MaterialStatus.approved ? l10n.materialApproved : l10n.materialProposed;

class ProjectStageChip extends StatelessWidget {
  const ProjectStageChip({super.key, required this.stage, this.dense = true});

  final ProjectStage stage;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = projectStageColor(stage);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(projectStageIcon(stage), size: 14, color: color),
          const SizedBox(width: 4),
          Text(projectStageLabel(AppLocalizations.of(context), stage),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Filters sheet of the client list and map: clients linked to projects in
/// some stages and / or to chosen projects.
class ProjectFilterSection extends ConsumerWidget {
  const ProjectFilterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final ids = ref.watch(projectFilterProvider);
    final stages = ref.watch(projectStageFilterProvider);
    final byId = {for (final p in projects) p.id: p};
    if (projects.isEmpty && ids.isEmpty && stages.isEmpty) {
      return Text(l10n.noProjectsYet, style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in ProjectStage.values)
              FilterChip(
                avatar: Icon(projectStageIcon(s), size: 18),
                label: Text('${projectStageLabel(l10n, s)} (${projects.where((p) => p.stage == s).length})'),
                selected: stages.contains(s),
                onSelected: (_) => ref.read(projectStageFilterProvider.notifier).toggle(s),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final id in ids)
              InputChip(
                avatar: const Icon(Icons.apartment, size: 16),
                label: Text(byId[id]?.name ?? '?'),
                onDeleted: () => ref.read(projectFilterProvider.notifier).toggle(id),
              ),
            TextButton.icon(
              onPressed: () => showDialog<void>(context: context, builder: (_) => const _ProjectPickDialog()),
              icon: const Icon(Icons.checklist),
              label: Text(l10n.chooseProjects),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(l10n.projectFilterHelp, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _ProjectPickDialog extends ConsumerStatefulWidget {
  const _ProjectPickDialog();

  @override
  ConsumerState<_ProjectPickDialog> createState() => _ProjectPickDialogState();
}

class _ProjectPickDialogState extends ConsumerState<_ProjectPickDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = ref.watch(projectFilterProvider);
    final projects = [
      for (final p in ref.watch(projectsProvider).value ?? const <Project>[])
        if (projectMatches(p, _query)) p,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AlertDialog(
      title: Text(l10n.chooseProjects),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchProjects),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final p in projects)
                    CheckboxListTile(
                      dense: true,
                      value: ids.contains(p.id),
                      onChanged: (_) => ref.read(projectFilterProvider.notifier).toggle(p.id),
                      title: Text(p.name),
                      subtitle: Text([p.contractor, l10n.clientsCountShort(p.clientIds.length)].where((s) => s.isNotEmpty).join(' · ')),
                      secondary: ProjectStageChip(stage: p.stage),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => ref.read(projectFilterProvider.notifier).clear(), child: Text(l10n.clearFilters)),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done)),
      ],
    );
  }
}

/// Client page: the projects the client is linked to.
class ClientProjectsSection extends ConsumerWidget {
  const ClientProjectsSection({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!canUseProjects(ref.watch(currentUserProvider).value)) return const SizedBox.shrink();
    final projects = ref.watch(clientProjectsProvider(clientId));
    return Column(
      children: [
        for (final p in projects)
          ListTile(
            dense: true,
            leading: const Icon(Icons.apartment),
            title: Text(p.name, style: Theme.of(context).textTheme.bodyLarge),
            subtitle: p.contractor.isEmpty ? null : Text(p.contractor),
            trailing: ProjectStageChip(stage: p.stage),
            onTap: () => context.push('/projects/${p.id}'),
          ),
        if (projects.isEmpty) ListTile(dense: true, title: Text(l10n.noProjectsForClient)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => context.push('/projects/new?client=$clientId'),
            icon: const Icon(Icons.add),
            label: Text(l10n.addProject),
          ),
        ),
      ],
    );
  }
}
