import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_user.dart';
import '../../core/place_buttons.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';
import '../../core/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/clients_repository.dart';
import '../users/users_repository.dart';
import '../products/product.dart';
import '../products/product_widgets.dart';
import '../products/products_repository.dart';
import 'project.dart';
import 'project_parties.dart';
import 'project_widgets.dart';
import 'projects_repository.dart';

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, AppUser> _usersById(WidgetRef ref) => {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};

/// Projects (user request 2026-11-17): every project the sales team
/// follows, with search, stage chips and "Led by me".
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _query = '';
  ProjectStage? _stage;
  bool _mine = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final all = ref.watch(projectsProvider).value;
    final users = _usersById(ref);
    final searched = [
      for (final p in all ?? const <Project>[])
        if (projectMatches(p, _query) && (!_mine || p.leadId == me?.id)) p,
    ];
    final shown = [
      for (final p in searched)
        if (_stage == null || p.stage == _stage) p,
    ];
    final mine = (all ?? const <Project>[]).where((p) => p.leadId == me?.id).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projects),
        actions: [
          IconButton(icon: const Icon(Icons.map_outlined), tooltip: l10n.clientMap, onPressed: () => context.go('/map')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addProject),
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.searchProjects,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('${l10n.statusAll} (${searched.length})'),
                        selected: _stage == null,
                        onSelected: (_) => setState(() => _stage = null),
                      ),
                      for (final s in ProjectStage.values)
                        ChoiceChip(
                          avatar: Icon(projectStageIcon(s), size: 18, color: projectStageColor(s)),
                          label: Text('${projectStageLabel(l10n, s)} (${searched.where((p) => p.stage == s).length})'),
                          selected: _stage == s,
                          onSelected: (_) => setState(() => _stage = _stage == s ? null : s),
                        ),
                      if (mine > 0)
                        FilterChip(
                          avatar: const Icon(Icons.person, size: 18),
                          label: Text('${l10n.ledByMe} ($mine)'),
                          selected: _mine,
                          onSelected: (v) => setState(() => _mine = v),
                        ),
                    ],
                  ),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(all.isEmpty ? l10n.noProjectsYet : l10n.noMatches, textAlign: TextAlign.center),
                  ),
                for (final p in shown) _ProjectCard(project: p, lead: users[p.leadId]),
              ],
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.lead});

  final Project project;
  final AppUser? lead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = project;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/projects/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.apartment, color: projectStageColor(p.stage)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: theme.textTheme.titleMedium),
                    if (p.contractor.isNotEmpty) Text(p.contractor, style: theme.textTheme.bodyMedium),
                    Text(
                      [
                        l10n.projectLeadIs(lead?.name ?? '?'),
                        l10n.clientsCountShort(p.clientIds.length),
                        if (p.materials.isNotEmpty) l10n.materialsCount(p.materials.length),
                        if (p.sampleCount > 0) l10n.samplesCount(p.sampleCount),
                        if (!p.hasLocation) l10n.noLocation,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ProjectStageChip(stage: p.stage),
            ],
          ),
        ),
      ),
    );
  }
}

/// One project: stage, lead, location, designer / contact, clients,
/// materials (proposed / approved), samples and history.
class ProjectScreen extends ConsumerWidget {
  const ProjectScreen({super.key, required this.id});

  final String id;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  Future<void> _changeStage(BuildContext context, Project p, ProjectStage stage) async {
    final l10n = AppLocalizations.of(context);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.moveProjectToStage(projectStageLabel(l10n, stage))),
        content: TextField(
          controller: note,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.noteOptional),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, () => setProjectStage(p, stage, note: note.text));
  }

  Future<void> _changeLead(BuildContext context, WidgetRef ref, Project p) async {
    final l10n = AppLocalizations.of(context);
    final people = [
      for (final u in ref.read(usersProvider).value ?? const <AppUser>[])
        if (u.active && u.can.isSales) u,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(l10n.changeProjectLead),
        children: [
          for (final u in people)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, u.id),
              child: Row(
                children: [
                  Icon(u.id == p.leadId ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${u.name} · ${u.role.label(l10n)}')),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == p.leadId || !context.mounted) return;
    await _run(context, () => setProjectLead(p, picked));
  }

  Future<void> _delete(BuildContext context, Project p) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.deleteProjectQ(p.name)),
        content: Text(l10n.deleteProjectBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final router = GoRouter.of(context);
    await _run(context, () async {
      await deleteProject(p.id);
      router.pop();
    });
  }

  /// Decor of our collection (+ optional product), then proposed / approved.
  Future<void> _addMaterial(BuildContext context, WidgetRef ref, Project p) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDecorPicker(context);
    if (picked == null || !context.mounted) return;
    final label = materialLabel(ref.read(decorsByKeyProvider), ref.read(productsByIdProvider), picked.$1, picked.$2, '');
    var status = MaterialStatus.proposed;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addMaterial),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.palette_outlined), title: Text(label)),
                const SizedBox(height: 8),
                SegmentedButton<MaterialStatus>(
                  segments: [
                    for (final s in MaterialStatus.values)
                      ButtonSegment(value: s, label: Text(materialStatusLabel(l10n, s))),
                  ],
                  selected: {status},
                  onSelectionChanged: (v) => setState(() => status = v.first),
                ),
                TextField(controller: note, decoration: InputDecoration(labelText: l10n.noteOptional)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.add)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, () => addProjectMaterial(p, picked.$1, status, productId: picked.$2, note: note.text));
  }

  Future<void> _addSample(BuildContext context, WidgetRef ref, Project p) async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final decors = ref.read(decorsByKeyProvider);
    final products = ref.read(productsByIdProvider);
    // Starts on the project's first material (its sample product when it has one).
    var decor = p.materials.isEmpty ? '' : p.materials.first.materialId;
    var product = '';
    if (decors[decor] case final d?) {
      product = d.products.where((x) => x.type == ProductType.sample).firstOrNull?.id ?? '';
    } else {
      decor = '';
    }
    var day = DateTime.now();
    final qty = TextEditingController(text: '1');
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.recordSamples),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(decor.isEmpty ? l10n.otherSample : materialLabel(decors, products, decor, product, '')),
                    subtitle: Text(l10n.material),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final picked = await showDecorPicker(context, sampleFirst: true, initialDecor: decor.isEmpty ? null : decor);
                      if (picked != null) setState(() => (decor, product) = picked);
                    },
                  ),
                  if (decor.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => setState(() => (decor, product) = ('', '')),
                        child: Text(l10n.otherSample),
                      ),
                    ),
                  TextFormField(
                    controller: qty,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.quantity),
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? l10n.required : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(DateFormat.yMMMd(lang).format(day)),
                    subtitle: Text(l10n.date),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: day,
                        firstDate: DateTime(DateTime.now().year - 5),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => day = picked);
                    },
                  ),
                  TextFormField(
                    controller: note,
                    decoration: InputDecoration(labelText: decor.isEmpty ? l10n.sampleDescription : l10n.noteOptional),
                    validator: (v) => decor.isEmpty && (v ?? '').trim().isEmpty ? l10n.required : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(dialog, true);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context, () async {
      final moved = await addProjectSample(p,
          materialId: decor, productId: product, day: _day(day), qty: int.parse(qty.text), note: note.text);
      if (moved != null) messenger.showSnackBar(SnackBar(content: Text(l10n.projectMovedTo(projectStageLabel(l10n, moved)))));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(currentUserProvider).value;
    final p = ref.watch(projectProvider(id));
    final loaded = ref.watch(projectsProvider).hasValue;
    final users = _usersById(ref);
    final decors = ref.watch(decorsByKeyProvider);
    final products = ref.watch(productsByIdProvider);
    final noProducts = ref.watch(productsProvider).value?.isEmpty ?? false;
    final admin = canChangeProjectLead(me);
    String nameOf(String uid) => users[uid]?.name ?? (uid.isEmpty ? '' : l10n.deletedUser);
    String materialName(String decor, String product) => materialLabel(decors, products, decor, product, l10n.removedMaterial);
    String when(DateTime? d) => d == null ? '' : DateFormat.yMMMd(lang).add_jm().format(d);

    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: loaded ? Text(l10n.projectNotFound) : const CircularProgressIndicator()),
      );
    }

    Widget section(String title, List<Widget> children, {Widget? action}) => Card(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary))),
                      ?action,
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
        );
    Widget row(IconData icon, String label, String value, {VoidCallback? onTap}) => value.isEmpty
        ? const SizedBox.shrink()
        : ListTile(
            dense: true,
            leading: Icon(icon),
            title: Text(value, style: theme.textTheme.bodyLarge),
            subtitle: Text(label),
            onTap: onTap,
          );

    final approved = p.materials.where((m) => m.status == MaterialStatus.approved).toList();
    final proposed = p.materials.where((m) => m.status == MaterialStatus.proposed).toList();

    Widget materialTile(ProjectMaterial m) => ListTile(
          dense: true,
          leading: Icon(m.status == MaterialStatus.approved ? Icons.check_circle : Icons.lightbulb_outline,
              color: m.status == MaterialStatus.approved ? Colors.green.shade700 : null),
          title: Text(materialName(m.materialId, m.productId), style: theme.textTheme.bodyLarge),
          subtitle: Text([if (m.note.isNotEmpty) m.note, nameOf(m.byId), when(m.at)].where((s) => s.isNotEmpty).join(' · ')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _run(
                  context,
                  () => saveProjectMaterials(p, [
                    for (final x in p.materials)
                      x.id == m.id
                          ? x.copyWith(status: m.status == MaterialStatus.approved ? MaterialStatus.proposed : MaterialStatus.approved)
                          : x,
                  ]),
                ),
                child: Text(m.status == MaterialStatus.approved ? l10n.markProposed : l10n.markApproved),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.delete,
                onPressed: () => _run(context, () => saveProjectMaterials(p, [for (final x in p.materials) if (x.id != m.id) x])),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: l10n.edit, onPressed: () => context.push('/projects/${p.id}/edit')),
          if (admin)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'lead' ? _changeLead(context, ref, p) : _delete(context, p),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'lead', child: ListTile(leading: const Icon(Icons.manage_accounts), title: Text(l10n.changeProjectLead))),
                PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l10n.deleteProject))),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        children: [
          // Stage: tap another one to move the project there.
          section(l10n.projectStage, [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ProjectStage.values)
                    ChoiceChip(
                      avatar: Icon(projectStageIcon(s), size: 18, color: p.stage == s ? null : projectStageColor(s)),
                      label: Text(projectStageLabel(l10n, s)),
                      selected: p.stage == s,
                      selectedColor: projectStageColor(s).withValues(alpha: 0.25),
                      onSelected: p.stage == s ? null : (_) => _changeStage(context, p, s),
                    ),
                ],
              ),
            ),
          ]),
          section(l10n.projectDetails, [
            row(Icons.apartment, l10n.projectName, p.name),
            ListTile(
              dense: true,
              leading: const Icon(Icons.star_outline),
              title: Text(nameOf(p.leadId), style: theme.textTheme.bodyLarge),
              subtitle: Text(l10n.projectLead),
              trailing: admin
                  ? TextButton(onPressed: () => _changeLead(context, ref, p), child: Text(l10n.change))
                  : null,
            ),
            row(Icons.person_add_alt, l10n.addedBy, [nameOf(p.createdBy), when(p.createdAt)].where((s) => s.isNotEmpty).join(' · ')),
          ]),
          section(l10n.projectLocation, [
            row(Icons.place, l10n.address, p.address),
            if (p.hasLocation)
              ListTile(
                dense: true,
                leading: const Icon(Icons.my_location),
                title: Text('${p.lat!.toStringAsFixed(5)}, ${p.lng!.toStringAsFixed(5)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.directions),
                  tooltip: l10n.directions,
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              )
            else
              ListTile(
                dense: true,
                leading: Icon(Icons.location_off_outlined, color: theme.disabledColor),
                title: Text(l10n.projectNoLocation),
                trailing: TextButton(onPressed: () => context.push('/projects/${p.id}/edit'), child: Text(l10n.edit)),
              ),
          ]),
          // Contractors, designer offices, consultants: a card each (2026-11-17).
          for (final kind in PartyKind.values)
            if (p.partiesOf(kind) case final list when list.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    Icon(partyKindIcon(kind), size: 18, color: partyKindColor(kind)),
                    const SizedBox(width: 8),
                    Text(partyKindPlural(l10n, kind), style: theme.textTheme.titleSmall?.copyWith(color: partyKindColor(kind))),
                  ],
                ),
              ),
              for (final party in list) PartyCard(party: party),
              const SizedBox(height: 4),
            ],
          // Linked clients as branches of the project (2026-11-17).
          section(
            l10n.linkedClientsCount(p.clientIds.length),
            [ProjectClientsTree(project: p)],
            action: TextButton(onPressed: () => context.push('/projects/${p.id}/edit'), child: Text(l10n.edit)),
          ),
          section(
            l10n.materialsFromCollection,
            [
              if (p.materials.isEmpty) ListTile(dense: true, title: Text(l10n.noMaterialsYet)),
              if (approved.isNotEmpty) _SubHeading(l10n.materialApproved),
              for (final m in approved) materialTile(m),
              if (proposed.isNotEmpty) _SubHeading(l10n.materialProposed),
              for (final m in proposed) materialTile(m),
              if (noProducts)
                ListTile(dense: true, leading: const Icon(Icons.info_outline), title: Text(admin ? l10n.materialsEmptyAdmin : l10n.materialsEmpty)),
            ],
            action: TextButton.icon(
              onPressed: noProducts ? null : () => _addMaterial(context, ref, p),
              icon: const Icon(Icons.add),
              label: Text(l10n.add),
            ),
          ),
          section(
            l10n.samplesSubmitted,
            [
              if (p.samples.isEmpty) ListTile(dense: true, title: Text(l10n.noSamplesYet)),
              for (final s in p.samplesNewestFirst)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 14, child: Text('${s.qty}', style: theme.textTheme.labelMedium)),
                  title: Text(s.materialId.isEmpty && s.productId.isEmpty ? s.note : materialName(s.materialId, s.productId), style: theme.textTheme.bodyLarge),
                  subtitle: Text([
                    if (DateTime.tryParse(s.day) case final d?) DateFormat.yMMMd(lang).format(d),
                    nameOf(s.byId),
                    if ((s.materialId.isNotEmpty || s.productId.isNotEmpty) && s.note.isNotEmpty) s.note,
                  ].where((x) => x.isNotEmpty).join(' · ')),
                  trailing: s.byId == me?.id || admin
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.delete,
                          onPressed: () => _run(context, () => deleteProjectSample(p, s.id)),
                        )
                      : null,
                ),
            ],
            action: TextButton.icon(onPressed: () => _addSample(context, ref, p), icon: const Icon(Icons.add), label: Text(l10n.add)),
          ),
          if (p.notes.isNotEmpty) section(l10n.notes, [row(Icons.notes, l10n.notes, p.notes)]),
          section(l10n.projectHistory, [
            for (final c in p.stageLog.reversed)
              ListTile(
                dense: true,
                leading: Icon(projectStageIcon(c.stage), color: projectStageColor(c.stage)),
                title: Text(projectStageLabel(l10n, c.stage), style: theme.textTheme.bodyLarge),
                subtitle: Text([nameOf(c.byId), when(c.at), if (c.note.isNotEmpty) c.note].where((s) => s.isNotEmpty).join(' · ')),
              ),
            for (final c in p.leadLog.reversed)
              ListTile(
                dense: true,
                leading: const Icon(Icons.manage_accounts),
                title: Text(l10n.leadChanged(nameOf(c.fromId), nameOf(c.toId)), style: theme.textTheme.bodyLarge),
                subtitle: Text([nameOf(c.byId), when(c.at)].where((s) => s.isNotEmpty).join(' · ')),
              ),
          ]),
        ],
      ),
    );
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

/// Add ([id] null) or edit a project's details and linked clients. Stage,
/// materials and samples are changed on the project page.
class ProjectEditScreen extends ConsumerStatefulWidget {
  const ProjectEditScreen({super.key, this.id, this.clientId});

  final String? id;

  /// New project from a client page: that client is linked.
  final String? clientId;

  @override
  ConsumerState<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends ConsumerState<ProjectEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final List<PartyDraft> _parties = [];
  final _notes = TextEditingController();
  LatLng? _point;
  List<String> _clientIds = [];
  Map<String, String> _clientNames = {};
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _address, _notes]) {
      c.dispose();
    }
    for (final d in _parties) {
      d.dispose();
    }
    super.dispose();
  }

  void _load(Project? p, Map<String, Client> clients) {
    if (_loaded) return;
    if (widget.id != null && p == null) return;
    _loaded = true;
    if (p == null) {
      // A new project starts with an empty contractor card (required).
      _parties.add(PartyDraft(id: _newPartyId(), kind: PartyKind.contractor));
      if (widget.clientId case final cid? when clients[cid] != null) {
        _clientIds = [cid];
        _clientNames = {cid: clients[cid]!.name};
      }
      return;
    }
    _name.text = p.name;
    _parties.addAll(p.parties.map(PartyDraft.of));
    if (!_parties.any((d) => d.kind == PartyKind.contractor)) {
      _parties.insert(0, PartyDraft(id: _newPartyId(), kind: PartyKind.contractor, name: p.contractor));
    }
    _address.text = p.address;
    _notes.text = p.notes;
    _point = p.hasLocation ? LatLng(p.lat!, p.lng!) : null;
    _clientIds = [...p.clientIds];
    _clientNames = {...p.clientNames};
  }

  String _newPartyId() => '${DateTime.now().microsecondsSinceEpoch}_${_parties.length}';

  Future<void> _pickClients() async {
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _ClientPickDialog(initial: _clientIds.toSet()),
    );
    if (picked == null) return;
    final clients = ref.read(clientsByIdProvider);
    setState(() {
      // Keep the order; new ones at the end.
      _clientIds = [..._clientIds.where(picked.contains), ...picked.where((id) => !_clientIds.contains(id))];
      for (final id in _clientIds) {
        if (clients[id] case final c?) _clientNames[id] = c.name;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final id = await saveProject(
        id: widget.id,
        name: _name.text,
        parties: [for (final d in _parties) d.toParty()],
        lat: _point?.latitude,
        lng: _point?.longitude,
        address: _address.text,
        notes: _notes.text,
        clientIds: _clientIds,
        clientNames: _clientNames,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
      if (widget.id == null) {
        router.pushReplacement('/projects/$id');
      } else {
        router.pop();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = widget.id == null ? null : ref.watch(projectProvider(widget.id!));
    final clients = ref.watch(clientsByIdProvider);
    _load(p, clients);
    if (!_loaded) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    final allProjects = ref.watch(projectsProvider).value ?? const <Project>[];
    final suggestions = {for (final k in PartyKind.values) k: partySuggestions(k, allProjects, clients.values)};
    final firstContractor = _parties.where((d) => d.kind == PartyKind.contractor).firstOrNull;

    Widget partiesOf(PartyKind kind) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(kind == PartyKind.contractor ? partyKindPlural(l10n, kind) : '${partyKindPlural(l10n, kind)} (${l10n.optional})'),
            for (final d in _parties.where((d) => d.kind == kind))
              PartyEditorCard(
                key: ValueKey(d.id),
                draft: d,
                suggestions: suggestions[kind]!,
                required: d == firstContractor,
                onChanged: () => setState(() {}),
                // The first contractor stays (a project needs one).
                onRemove: d == firstContractor
                    ? null
                    : () => setState(() {
                          _parties.remove(d);
                          d.dispose();
                        }),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _parties.add(PartyDraft(id: _newPartyId(), kind: kind))),
                icon: Icon(partyKindIcon(kind)),
                label: Text(addPartyLabel(l10n, kind)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );

    Widget field(TextEditingController c, String label, {IconData? icon, bool required = false, TextInputType? type, int maxLines = 1}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(labelText: required ? '$label *' : label, prefixIcon: icon == null ? null : Icon(icon)),
            validator: required ? (v) => (v ?? '').trim().isEmpty ? l10n.required : null : null,
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? l10n.addProject : l10n.editProject)),
      body: Form(
        key: _form,
        // Not a ListView: off-screen fields would be skipped by validate().
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  field(_name, l10n.projectName, icon: Icons.apartment, required: true),
                  partiesOf(PartyKind.contractor),
                  heading(l10n.projectLocation),
                  Text(
                    _point == null
                        ? l10n.projectLocationLater
                        : '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PlaceButtons(point: _point, onPicked: (pt) => setState(() => _point = pt)),
                      if (_point != null)
                        TextButton.icon(
                          onPressed: () => setState(() => _point = null),
                          icon: const Icon(Icons.location_off_outlined),
                          label: Text(l10n.clearLocationButton),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  field(_address, l10n.address, icon: Icons.place),
                  partiesOf(PartyKind.designer),
                  partiesOf(PartyKind.consultant),
                  heading(l10n.linkedClientsCount(_clientIds.length)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final id in _clientIds)
                        InputChip(
                          avatar: const Icon(Icons.store_outlined, size: 16),
                          label: Text(clients[id]?.name ?? _clientNames[id] ?? '?'),
                          onDeleted: () => setState(() => _clientIds.remove(id)),
                        ),
                      TextButton.icon(onPressed: _pickClients, icon: const Icon(Icons.add), label: Text(l10n.linkClients)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  field(_notes, l10n.notes, icon: Icons.notes, maxLines: 4),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _busy ? null : _save, child: BusyLabel(busy: _busy, child: Text(l10n.save))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Search and tick clients (those the person can read).
class _ClientPickDialog extends ConsumerStatefulWidget {
  const _ClientPickDialog({required this.initial});

  final Set<String> initial;

  @override
  ConsumerState<_ClientPickDialog> createState() => _ClientPickDialogState();
}

class _ClientPickDialogState extends ConsumerState<_ClientPickDialog> {
  late final Set<String> _picked = {...widget.initial};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(clientsProvider).value ?? const <Client>[];
    final shown = [
      // Picked first, then the matches (at most 100 shown).
      ...all.where((c) => _picked.contains(c.id)),
      ...all
          .where((c) => !_picked.contains(c.id) && _query.trim().isNotEmpty && (searchHas(c.name, _query) || c.aliases.any((a) => searchHas(a, _query)) || searchHas(c.city, _query)))
          .take(100),
    ];
    return AlertDialog(
      title: Text(l10n.linkClients),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchClients),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: shown.isEmpty
                  ? Center(child: Text(l10n.typeToSearchClients, textAlign: TextAlign.center))
                  : ListView(
                      children: [
                        for (final c in shown)
                          CheckboxListTile(
                            dense: true,
                            value: _picked.contains(c.id),
                            onChanged: (v) => setState(() => v == true ? _picked.add(c.id) : _picked.remove(c.id)),
                            title: Text(c.name),
                            subtitle: c.city.isEmpty ? null : Text(c.city),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _picked), child: Text(l10n.done)),
      ],
    );
  }
}
