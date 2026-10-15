import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'client_widgets.dart';
import 'clients_repository.dart';
import 'transfer_dialog.dart';
import 'visit_rules.dart';

enum _Status { all, recent, dueSoon, overdue, noLocation }

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _query = '';
  _Status _status = _Status.all;

  /// Hidden clients instead of the visible ones (KAM / managers).
  bool _showHidden = false;

  /// Ids ticked for hiding / showing; null when not selecting.
  Set<String>? _selected;
  bool _busy = false;

  bool _matches(Client c, VisitRules rules, DateTime now, _Status status) => switch (status) {
    _Status.all => true,
    _Status.recent => visitStatus(c, rules, now) == VisitStatus.recent,
    _Status.dueSoon => visitStatus(c, rules, now) == VisitStatus.dueSoon,
    _Status.overdue => visitStatus(c, rules, now) == VisitStatus.overdue,
    _Status.noLocation => !c.hasLocation,
  };

  void _toggle(String id) => setState(() {
    final selected = _selected ??= {};
    if (!selected.remove(id)) selected.add(id);
  });

  /// Hides the ticked clients (after confirming), or in the hidden view
  /// shows them again.
  Future<void> _applyToSelected() async {
    final l10n = AppLocalizations.of(context);
    final me = ref.read(currentUserProvider).value;
    final ids = _selected?.toList() ?? const <String>[];
    if (me == null || ids.isEmpty) return;
    final hide = !_showHidden;
    if (hide) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.hideClientsTitle(ids.length)),
          content: Text(l10n.hideClientBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.hideClient)),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(clientsRepositoryProvider).setHiddenMany(ids, hidden: hide, by: me.id);
      messenger.showSnackBar(
        SnackBar(content: Text(hide ? l10n.clientsHiddenCount(ids.length) : l10n.clientsUnhiddenCount(ids.length))),
      );
      if (mounted) setState(() => _selected = null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Moves the ticked clients to another sales executive.
  Future<void> _transferSelected(List<Client> ticked) async {
    setState(() => _busy = true);
    try {
      final done = await showTransferDialog(context, ref, ticked);
      if (done && mounted) setState(() => _selected = null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final supervisor = me?.role.isSupervisor ?? false;
    final users = {for (final u in ref.watch(usersProvider).value ?? const []) u.id: u};
    final hidden = supervisor ? ref.watch(filteredHiddenClientsProvider) : const <Client>[];
    if (hidden.isEmpty) _showHidden = false;
    final clients = _showHidden ? AsyncValue.data(hidden) : ref.watch(filteredClientsProvider);
    final now = DateTime.now();
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;

    final searched = (clients.value ?? const <Client>[])
        .where(
          (c) =>
              _query.isEmpty ||
              c.nameKey.contains(_query) ||
              c.city.toLowerCase().contains(_query) ||
              c.vat.contains(_query),
        )
        .toList();
    final list = searched.where((c) => _matches(c, rules, now, _status)).toList();
    final selected = _selected;
    // Ticked clients that are still in the list (filters may have changed).
    final ticked = selected == null
        ? const <String>{}
        : {
            for (final c in list)
              if (selected.contains(c.id)) c.id,
          };

    final appBar = selected != null
        ? AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancel,
              onPressed: () => setState(() => _selected = null),
            ),
            title: Text(l10n.selectedCount(ticked.length)),
            actions: [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: l10n.selectAll,
                onPressed: () => setState(() => _selected = {for (final c in list) c.id}),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: l10n.transferClients,
                onPressed: ticked.isEmpty || _busy
                    ? null
                    : () => _transferSelected([for (final c in list) if (ticked.contains(c.id)) c]),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: FilledButton.icon(
                  onPressed: ticked.isEmpty || _busy
                      ? null
                      : () {
                          _selected = ticked;
                          _applyToSelected();
                        },
                  icon: Icon(_showHidden ? Icons.visibility : Icons.visibility_off),
                  label: Text(_showHidden ? l10n.unhideClient : l10n.hideClient),
                ),
              ),
            ],
          )
        : AppBar(
            title: Text(l10n.clients),
            actions: [
              if (supervisor)
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: l10n.selectClients,
                  onPressed: () => setState(() => _selected = {}),
                ),
              IconButton(icon: const Icon(Icons.map), tooltip: l10n.map, onPressed: () => context.go('/map')),
              if (me?.role.isAdmin ?? false)
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  tooltip: l10n.importClients,
                  onPressed: () => context.go('/import'),
                ),
            ],
          );

    int count(_Status s) => searched.where((c) => _matches(c, rules, now, s)).length;
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final (s, label, color) in [
            (_Status.all, l10n.statusAll, null),
            (_Status.recent, l10n.statusRecent, statusRecentColor),
            (_Status.dueSoon, l10n.statusDueSoon, statusDueSoonColor),
            (_Status.overdue, l10n.statusOverdue, statusOverdueColor),
            (_Status.noLocation, l10n.noLocation, Colors.grey),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                avatar: color == null ? null : Icon(Icons.circle, size: 12, color: color),
                label: Text('$label (${count(s)})'),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
              ),
            ),
          // Only KAM / managers, and only when some clients are hidden.
          if (hidden.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                avatar: const Icon(Icons.visibility_off, size: 16),
                label: Text('${l10n.hiddenClients} (${hidden.length})'),
                selected: _showHidden,
                showCheckmark: false,
                onSelected: (v) => setState(() {
                  _showHidden = v;
                  _selected = _selected == null ? null : {};
                }),
              ),
            ),
        ],
      ),
    );
    final planned = ref.watch(plannedTodayProvider).keys.toSet();

    return Scaffold(
      floatingActionButton: selected != null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/clients/new'),
              icon: const Icon(Icons.add_business),
              label: Text(l10n.addClient),
            ),
      appBar: appBar,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.search),
              onChanged: (v) => setState(() => _query = Client.normalizeName(v)),
            ),
          ),
          if (supervisor) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SalesFilterDropdown()),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: clients.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
              data: (_) {
                if (list.isEmpty) {
                  return Column(
                    children: [
                      chips,
                      Expanded(child: Center(child: Text(l10n.noClients))),
                    ],
                  );
                }
                return Column(
                  children: [
                    chips,
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l10n.clientsCount(
                          list.length,
                          list.where((c) => visitStatus(c, rules, now) == VisitStatus.recent).length,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          final exec = users[c.assignedTo]?.name ?? l10n.unassigned;
                          return _ClientTile(
                            client: c,
                            exec: exec,
                            status: visitStatus(c, rules, now),
                            planned: planned.contains(c.id),
                            now: now,
                            selected: selected?.contains(c.id),
                            onSelect: () => _toggle(c.id),
                            onLongPress: supervisor && selected == null ? () => _toggle(c.id) : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One client row: category badge in its visit colour (blue when on today's
/// plan, as on the map), and a status pill with the days since the last visit.
class _ClientTile extends StatelessWidget {
  const _ClientTile({
    required this.client,
    required this.exec,
    required this.status,
    required this.planned,
    required this.now,
    this.selected,
    this.onSelect,
    this.onLongPress,
  });

  final Client client;
  final String exec;
  final VisitStatus status;
  final bool planned;
  final DateTime now;

  /// Tick state while selecting; null when not selecting.
  final bool? selected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = planned ? plannedColor : visitStatusColor(status);
    final last = client.lastVisitAt;
    final since = last == null ? l10n.never : l10n.daysAgo(now.difference(last).inDays);
    final label = planned ? l10n.plannedToday : visitStatusLabel(status, l10n);
    // Yellow needs dark text to stay readable.
    final pillText = color == statusDueSoonColor ? const Color(0xFF7A5200) : color;

    return ListTile(
      selected: selected ?? false,
      leading: CategoryBadge(category: client.category, color: color, size: 36),
      title: Text(client.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: [client.city, exec].where((s) => s.isNotEmpty).join(' · ')),
            if (!client.hasLocation) ...[
              const TextSpan(text: '  '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.location_off, size: 14, color: theme.colorScheme.onSurfaceVariant),
              ),
              TextSpan(text: ' ${l10n.noLocation}'),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selected != null
          ? Checkbox(value: selected, onChanged: (_) => onSelect?.call())
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(color: pillText, fontWeight: FontWeight.w700),
                  ),
                  Text(since, style: theme.textTheme.labelSmall?.copyWith(color: pillText, fontSize: 10)),
                ],
              ),
            ),
      onTap: selected != null ? onSelect : () => context.push('/clients/${client.id}'),
      onLongPress: onLongPress,
    );
  }
}
