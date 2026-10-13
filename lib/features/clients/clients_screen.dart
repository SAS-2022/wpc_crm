import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'client_widgets.dart';
import 'clients_repository.dart';
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

  bool _matches(Client c, VisitRules rules, DateTime now, _Status status) => switch (status) {
        _Status.all => true,
        _Status.recent => visitStatus(c, rules, now) == VisitStatus.recent,
        _Status.dueSoon => visitStatus(c, rules, now) == VisitStatus.dueSoon,
        _Status.overdue => visitStatus(c, rules, now) == VisitStatus.overdue,
        _Status.noLocation => !c.hasLocation,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const []) u.id: u};
    final clients = ref.watch(filteredClientsProvider);
    final now = DateTime.now();
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clients/new'),
        icon: const Icon(Icons.add_business),
        label: Text(l10n.addClient),
      ),
      appBar: AppBar(
        title: Text(l10n.clients),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            tooltip: l10n.map,
            onPressed: () => context.go('/map'),
          ),
          if (me?.role.isAdmin ?? false)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: l10n.importClients,
              onPressed: () => context.go('/import'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.search,
              ),
              onChanged: (v) => setState(() => _query = Client.normalizeName(v)),
            ),
          ),
          if (me?.role.isSupervisor ?? false)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SalesFilterDropdown(),
            ),
          Expanded(
            child: clients.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
              data: (all) {
                final searched = _query.isEmpty
                    ? all
                    : all
                        .where((c) =>
                            c.nameKey.contains(_query) ||
                            c.city.toLowerCase().contains(_query) ||
                            c.vat.contains(_query))
                        .toList();
                final list = searched.where((c) => _matches(c, rules, now, _status)).toList();
                final planned = ref.watch(plannedTodayProvider).keys.toSet();
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
                    ],
                  ),
                );
                if (list.isEmpty) {
                  return Column(children: [chips, Expanded(child: Center(child: Text(l10n.noClients)))]);
                }
                return Column(
                  children: [
                    chips,
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(l10n.clientsCount(
                        list.length,
                        list.where((c) => visitStatus(c, rules, now) == VisitStatus.recent).length,
                      )),
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
  });

  final Client client;
  final String exec;
  final VisitStatus status;
  final bool planned;
  final DateTime now;

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
      leading: CategoryBadge(category: client.category, color: color, size: 36),
      title: Text(client.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text.rich(
        TextSpan(children: [
          TextSpan(text: [client.city, exec].where((s) => s.isNotEmpty).join(' · ')),
          if (!client.hasLocation) ...[
            const TextSpan(text: '  '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.location_off, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
            TextSpan(text: ' ${l10n.noLocation}'),
          ],
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: pillText, fontWeight: FontWeight.w700)),
            Text(since, style: theme.textTheme.labelSmall?.copyWith(color: pillText, fontSize: 10)),
          ],
        ),
      ),
      onTap: () => context.push('/clients/${client.id}'),
    );
  }
}
