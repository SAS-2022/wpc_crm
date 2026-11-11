import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/person_style.dart' show initialsOf;
import 'org_chart.dart';
import 'users_repository.dart';

/// Employee chart (`/users/chart`, icon on the Users page, 2026-11-11): a
/// tree from the GM down (pan / pinch to zoom; tap a manager's arrow to fold
/// their branch) or, with the list icon, the same as an indented list
/// (easier on phones). Tap a person for their details.
class OrgChartScreen extends ConsumerStatefulWidget {
  const OrgChartScreen({super.key});

  @override
  ConsumerState<OrgChartScreen> createState() => _OrgChartScreenState();
}

class _OrgChartScreenState extends ConsumerState<OrgChartScreen> {
  final _folded = <String>{};
  bool _list = false;
  final _view = TransformationController();

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() => _folded.contains(id) ? _folded.remove(id) : _folded.add(id));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orgChart),
        actions: [
          IconButton(
            tooltip: _list ? l10n.orgChartTree : l10n.orgChartList,
            icon: Icon(_list ? Icons.account_tree_outlined : Icons.format_list_bulleted),
            onPressed: () => setState(() => _list = !_list),
          ),
          if (!_list)
            IconButton(
              tooltip: l10n.orgChartReset,
              icon: const Icon(Icons.center_focus_strong_outlined),
              onPressed: () => _view.value = Matrix4.identity(),
            ),
          IconButton(
            tooltip: _folded.isEmpty ? l10n.orgChartFoldAll : l10n.orgChartUnfoldAll,
            icon: Icon(_folded.isEmpty ? Icons.unfold_less : Icons.unfold_more),
            onPressed: () {
              final all = users.value ?? const <AppUser>[];
              setState(() {
                if (_folded.isEmpty && me != null) {
                  // Keep the top level open.
                  for (final r in orgChartFor(me, all)) {
                    for (final c in r.children) {
                      if (c.children.isNotEmpty) _folded.add(c.user.id);
                    }
                  }
                } else {
                  _folded.clear();
                }
              });
            },
          ),
        ],
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
        data: (all) {
          if (me == null) return const SizedBox.shrink();
          final roots = orgChartFor(me, all);
          if (roots.isEmpty) return Center(child: Text(l10n.noUsers));
          final byId = {for (final u in all) u.id: u};
          void open(OrgNode n) => _showPerson(context, me, n, byId);
          if (_list) {
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [for (final r in roots) ..._listRows(r, 0, open)],
            );
          }
          return InteractiveViewer(
            transformationController: _view,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(600),
            minScale: 0.2,
            maxScale: 2.5,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in roots)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _branch(r, open)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _listRows(OrgNode n, int depth, void Function(OrgNode) open) {
    final folded = _folded.contains(n.user.id);
    return [
      Padding(
        padding: EdgeInsetsDirectional.only(start: 12.0 + depth * 24),
        child: _PersonRow(
          node: n,
          folded: folded,
          onTap: () => open(n),
          onToggle: n.children.isEmpty ? null : () => _toggle(n.user.id),
        ),
      ),
      if (!folded)
        for (final c in n.children) ..._listRows(c, depth + 1, open),
    ];
  }

  /// A manager's card, and under it their people: those without people of
  /// their own stacked in columns, managers as branches next to them.
  Widget _branch(OrgNode n, void Function(OrgNode) open) {
    final folded = _folded.contains(n.user.id);
    final card = _PersonCard(
      node: n,
      folded: folded,
      onTap: () => open(n),
      onToggle: n.children.isEmpty ? null : () => _toggle(n.user.id),
    );
    if (folded || n.children.isEmpty) return card;
    final leaves = [for (final c in n.children) if (c.children.isEmpty) c];
    final branches = [for (final c in n.children) if (c.children.isNotEmpty) c];
    final items = <Widget>[
      if (leaves.isNotEmpty) _leafGroup(leaves, open),
      for (final b in branches) _branch(b, open),
    ];
    final line = Theme.of(context).colorScheme.outline;
    Widget stub() => Center(child: Container(width: 2, height: 16, color: line));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        stub(),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The line across, from the first child's middle to the last's.
                    SizedBox(
                      height: 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: ColoredBox(color: i == 0 ? Colors.transparent : line)),
                          Expanded(child: ColoredBox(color: i == items.length - 1 ? Colors.transparent : line)),
                        ],
                      ),
                    ),
                    stub(),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Center(child: items[i])),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// People without a team, up to 6 a column.
  Widget _leafGroup(List<OrgNode> leaves, void Function(OrgNode) open) {
    const perColumn = 6;
    final columns = [
      for (var i = 0; i < leaves.length; i += perColumn)
        leaves.sublist(i, (i + perColumn).clamp(0, leaves.length)),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final col in columns)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final n in col)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PersonCard(node: n, folded: false, onTap: () => open(n), compact: true),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _showPerson(BuildContext context, AppUser me, OrgNode n, Map<String, AppUser> byId) {
    final l10n = AppLocalizations.of(context);
    final u = n.user;
    final mayEdit = me.can.isAdmin || me.can.editableRoles.contains(u.role) || me.hasRole(UserRole.hr);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _Avatar(user: u),
                title: Text(u.name, style: Theme.of(sheet).textTheme.titleMedium),
                subtitle: Text(u.role.label(l10n)),
              ),
              if (u.phone.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone_outlined), title: Text(u.phone)),
              if (n.children.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(l10n.orgChartTeam(n.children.length, n.teamSize)),
                ),
              if (n.alsoUnder.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.call_split),
                  title: Text(l10n.orgChartAlsoUnder(n.alsoUnder.map((id) => byId[id]?.name ?? '').join(', '))),
                ),
              if (mayEdit && me.can.managesUsers) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.orgChartOpenUser),
                  onPressed: () {
                    Navigator.pop(sheet);
                    context.push('/users/${u.id}');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, this.radius = 18});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = _groupColor(user.role);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      foregroundColor: Colors.white,
      child: Text(initialsOf(user.name), style: TextStyle(fontSize: radius * 0.75, fontWeight: FontWeight.w600)),
    );
  }
}

/// One colour per part of the company, so branches read at a glance.
Color _groupColor(UserRole r) => switch (r) {
      UserRole.gm => const Color(0xFF37474F),
      UserRole.salesManager || UserRole.kam || UserRole.salesExec => const Color(0xFF1565C0),
      UserRole.logisticsManager || UserRole.warehouseSupervisor || UserRole.driver => const Color(0xFF6D4C41),
      UserRole.factoryManager || UserRole.operator || UserRole.engineer => const Color(0xFF00897B),
      UserRole.worker => const Color(0xFF8D6E63),
      UserRole.hr || UserRole.accounting || UserRole.procurement => const Color(0xFF7B1FA2),
      UserRole.unknown => Colors.grey,
    };

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.node, required this.folded, required this.onTap, this.onToggle, this.compact = false});

  final OrgNode node;
  final bool folded;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final u = node.user;
    final accent = _groupColor(u.role);
    return SizedBox(
      width: compact ? 190 : 210,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: accent.withValues(alpha: 0.6), width: compact ? 1 : 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 10),
            child: Row(
              children: [
                _Avatar(user: u, radius: compact ? 15 : 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
                      Text(u.role.label(l10n), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (onToggle != null)
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Column(
                        children: [
                          Icon(folded ? Icons.expand_more : Icons.expand_less, size: 20),
                          Text('${node.teamSize}', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.node, required this.folded, required this.onTap, this.onToggle});

  final OrgNode node;
  final bool folded;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final u = node.user;
    return ListTile(
      dense: true,
      leading: _Avatar(user: u, radius: 16),
      title: Text(u.name),
      subtitle: Text(u.role.label(l10n)),
      onTap: onTap,
      trailing: onToggle == null
          ? null
          : TextButton.icon(
              onPressed: onToggle,
              icon: Icon(folded ? Icons.expand_more : Icons.expand_less),
              label: Text('${node.teamSize}'),
            ),
    );
  }
}
