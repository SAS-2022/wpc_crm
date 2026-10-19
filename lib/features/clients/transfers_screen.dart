import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../home/dashboard_cards.dart';
import '../home/stats.dart';
import '../users/users_repository.dart';
import '../visits/call_chip.dart';
import '../visits/visit.dart';
import 'client_status_widgets.dart';
import 'clients_repository.dart';
import 'transfer_watch.dart';
import 'visit_rules.dart';
import '../plan/plan_task.dart';

/// KAM / managers: clients moved from one salesperson to another and whether
/// the new salesperson has visited or called them since. A KAM sees moves to
/// or from their team and themselves.
class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  int _days = 30;
  bool _notVisitedOnly = false;

  /// New salesperson filter; null = everyone.
  String? _person;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final byId = {for (final u in users) u.id: u};
    String nameOf(String? id) => id == null ? l10n.unassigned : byId[id]?.name ?? '?';

    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day).subtract(Duration(days: _days));
    // Visits of every month from the start of the period.
    final months = <String>[
      for (var m = DateTime(since.year, since.month); !m.isAfter(now); m = DateTime(m.year, m.month + 1))
        monthKey(m),
    ];
    final visits = ref.watch(rangeVisitsProvider((null, months.join(',')))).value ?? const <Visit>[];
    final clients = ref.watch(clientsProvider).value ?? const [];
    final team = me.role.isAdmin ? null : {me.id, for (final u in teamOf(me, users)) u.id};
    final all = transferWatchRows(clients: clients, visits: visits, since: since, now: now, people: team);
    final targets = {for (final r in all) r.transfer.toId!};
    if (_person != null && !targets.contains(_person)) _person = null;
    final rows = [
      for (final r in all)
        if ((_person == null || r.transfer.toId == _person) && (!_notVisitedOnly || !r.contacted)) r,
    ];
    final visited = all.where((r) => r.contacted).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.transferredClients)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text(l10n.transfersHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final d in const [30, 60, 90])
                ChoiceChip(
                  label: Text(l10n.lastNDays(d)),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
              FilterChip(
                avatar: const Icon(Icons.hourglass_empty, size: 16),
                label: Text(l10n.transfersNotVisitedOnly),
                selected: _notVisitedOnly,
                showCheckmark: false,
                onSelected: (v) => setState(() => _notVisitedOnly = v),
              ),
              if (targets.length > 1)
                DropdownButton<String?>(
                  value: _person,
                  underline: const SizedBox.shrink(),
                  hint: Text(l10n.newSalesperson),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l10n.everyone)),
                    for (final id in targets.toList()..sort((a, b) => nameOf(a).compareTo(nameOf(b))))
                      DropdownMenuItem(value: id, child: Text(nameOf(id))),
                  ],
                  onChanged: (v) => setState(() => _person = v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.transfersSummary(all.length, visited, all.length - visited), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(l10n.transfersNone)),
            ),
          for (final r in rows) _TransferTile(row: r, nameOf: nameOf, locale: locale),
        ],
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.row, required this.nameOf, required this.locale});

  final TransferWatch row;
  final String Function(String?) nameOf;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = row.transfer;
    final first = row.firstContact;
    final day = DateFormat.yMMMd(locale);
    final Color color;
    final String status;
    if (first != null) {
      color = first.isCall ? callColor : statusRecentColor;
      status = first.isCall
          ? l10n.transferCalledAfter(day.format(first.checkedInAt!), row.days)
          : l10n.transferVisitedAfter(day.format(first.checkedInAt!), row.days);
    } else {
      // Red after two weeks without a visit, amber before.
      color = row.days >= 14 ? statusOverdueColor : const Color(0xFFB07800);
      status = l10n.transferNotVisited(row.days);
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => context.push('/clients/${row.client.id}'),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(first == null ? Icons.hourglass_empty : (first.isCall ? Icons.call : Icons.where_to_vote), color: color),
        ),
        title: Text(row.client.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${nameOf(t.fromId)} → ${nameOf(t.toId)}', style: theme.textTheme.bodyMedium),
            Text(status, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
            Text(
              [
                l10n.transferMovedBy(nameOf(t.byId), day.format(t.at!)),
                if (row.movedAgain) l10n.transferMovedAgain,
                if (!row.client.isActive) clientStatusLabel(l10n, row.client.status),
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
