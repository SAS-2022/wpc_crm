import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/client_widgets.dart';
import '../clients/clients_repository.dart';
import '../clients/visit_rules.dart';
import '../users/users_repository.dart';
import '../clients/client_tags.dart';
import 'call_chip.dart';
import 'visit.dart';
import 'visits_repository.dart';

enum _Period { today, week, month, all }

/// A salesperson's visits and calls on one day, shown as a sub-header.
typedef PersonGroup = ({String uid, int visits, int calls});

/// The rows of the visits list: a day (DateTime) before each day's visits,
/// and with [byPerson] a [PersonGroup] before each salesperson's visits of
/// that day (people by name, their visits newest first). [list] is newest first.
List<Object> visitListItems(
  List<Visit> list, {
  required DateTime now,
  required bool byPerson,
  required String Function(String uid) nameOf,
}) {
  final days = <DateTime, List<Visit>>{};
  for (final v in list) {
    final t = v.checkedInAt ?? now; // pending server time = just now
    days.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(v);
  }
  final items = <Object>[];
  for (final MapEntry(key: day, value: visits) in days.entries) {
    items.add(day);
    if (!byPerson) {
      items.addAll(visits);
      continue;
    }
    final people = <String, List<Visit>>{};
    for (final v in visits) {
      people.putIfAbsent(v.salesExecId, () => []).add(v);
    }
    final order = people.keys.toList()..sort((a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()));
    for (final uid in order) {
      final mine = people[uid]!;
      final calls = mine.where((v) => v.isCall).length;
      items.add((uid: uid, visits: mine.length - calls, calls: calls));
      items.addAll(mine);
    }
  }
  return items;
}

/// Own visits for sales executives; everyone's (filterable) for KAM / managers.
/// Search, period and visitor filters, a summary strip, and visits grouped by
/// day. "New visit" picks a client and opens the check-in.
class VisitsScreen extends ConsumerStatefulWidget {
  const VisitsScreen({super.key});

  @override
  ConsumerState<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends ConsumerState<VisitsScreen> {
  /// null = everyone.
  String? _visitor;
  _Period _period = _Period.all;
  String _query = '';

  /// null = visits and calls.
  VisitType? _type;

  bool _inPeriod(Visit v, DateTime now) {
    final t = v.checkedInAt ?? now; // pending server time = just now
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _Period.today => !t.isBefore(today),
      _Period.week => !t.isBefore(today.subtract(Duration(days: today.weekday % 7))), // weeks start on Sunday
      _Period.month => t.year == now.year && t.month == now.month,
      _Period.all => true,
    };
  }

  /// Picks a client and opens the check-in, or with [call] the call log.
  Future<void> _newVisit({bool call = false}) async {
    final clientId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ClientPickerSheet(),
    );
    if (clientId != null && mounted) context.push(call ? '/visits/call/$clientId' : '/visits/new/$clientId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final allUsers = ref.watch(usersProvider).value ?? const <AppUser>[];
    final users = {for (final u in allUsers) u.id: u};
    final visitors = allUsers.where((u) => u.active && u.role.isTracked).toList();
    final visits = ref.watch(visitsProvider);
    final hidden = ref.watch(hiddenClientIdsProvider);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final locationTypes = ref.watch(locationTypesByIdProvider);

    final periodLabels = {
      _Period.today: l10n.today,
      _Period.week: l10n.thisWeek,
      _Period.month: l10n.thisMonth,
      _Period.all: l10n.allTime,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.visits)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'logCall',
            tooltip: l10n.logCall,
            onPressed: () => _newVisit(call: true),
            child: const Icon(Icons.add_call),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'newVisit',
            onPressed: _newVisit,
            icon: const Icon(Icons.add_location_alt),
            label: Text(l10n.newVisit),
          ),
        ],
      ),
      body: visits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
        data: (all) {
          final q = _query.trim().toLowerCase();
          final list = all
              .where((v) => !hidden.contains(v.clientId))
              .where((v) => _visitor == null || v.salesExecId == _visitor || v.kamId == _visitor)
              .where((v) => _inPeriod(v, now))
              .where((v) => _type == null || v.type == _type)
              .where((v) => q.isEmpty || v.clientName.toLowerCase().contains(q) || v.notes.toLowerCase().contains(q))
              .toList();
          final flagged = list.where((v) => v.isFlagged).length;
          final calls = list.where((v) => v.isCall).length;
          final withKam = list.where((v) => v.kamId != null).length;

          // By day; within a day by salesperson when the list shows everyone.
          final byPerson = (me?.role.isSupervisor ?? false) && _visitor == null;
          final items = visitListItems(
            list,
            now: now,
            byPerson: byPerson,
            nameOf: (uid) => users[uid]?.name ?? '',
          );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SearchBar(
                    hintText: l10n.searchVisits,
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final p in _Period.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(periodLabels[p]!),
                            selected: _period == p,
                            onSelected: (_) => setState(() => _period = p),
                          ),
                        ),
                      const SizedBox(width: 8),
                      for (final (type, label, icon) in [
                        (null, l10n.visitsAndCalls, null),
                        (VisitType.visit, l10n.visits, Icons.where_to_vote),
                        (VisitType.call, l10n.calls, Icons.call),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            avatar: icon == null ? null : Icon(icon, size: 18),
                            label: Text(label),
                            selected: _type == type,
                            onSelected: (_) => setState(() => _type = type),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if ((me?.role.isSupervisor ?? false) && visitors.isNotEmpty)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            avatar: const Icon(Icons.groups, size: 18),
                            label: Text(l10n.everyone),
                            selected: _visitor == null,
                            onSelected: (_) => setState(() => _visitor = null),
                          ),
                        ),
                        for (final u in visitors)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: FilterChip(
                              avatar: _Initials(name: u.name, radius: 12),
                              label: Text(u.name),
                              selected: _visitor == u.id,
                              showCheckmark: false,
                              onSelected: (on) => setState(() => _visitor = on ? u.id : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _StatTile(icon: Icons.event_available, label: l10n.visitsTotal, value: list.length - calls, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      _StatTile(icon: Icons.call, label: l10n.calls, value: calls, color: callColor),
                      const SizedBox(width: 8),
                      _StatTile(icon: Icons.flag, label: l10n.flaggedVisits, value: flagged, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      _StatTile(icon: Icons.groups, label: l10n.withKamCount, value: withKam, color: Colors.teal),
                    ],
                  ),
                ),
              ),
              if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    title: all.isEmpty ? l10n.noVisits : l10n.noMatchingVisits,
                    hint: all.isEmpty ? l10n.noVisitsHint : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 96), // room for the button
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => switch (items[i]) {
                      final DateTime day => _DayHeader(day: day, now: now, locale: locale),
                      final PersonGroup g => _PersonHeader(
                          name: users[g.uid]?.name ?? '?',
                          visits: g.visits,
                          calls: g.calls,
                        ),
                      final Visit v => _VisitCard(
                          visit: v,
                          place: locationTypes[v.locationTypeId]?.label(locale.split('_').first),
                          visitor: users[v.salesExecId]?.name ?? '',
                          kam: users[v.kamId]?.name,
                          locale: locale,
                        ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

extension on Visit {
  bool get isFar => !isCall && distanceMeters != null && distanceMeters! > visitRadiusMeters;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text('$value', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now, required this.locale});

  final DateTime day;
  final DateTime now;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? l10n.today
        : day == today.subtract(const Duration(days: 1))
            ? l10n.yesterday
            : DateFormat.MMMEd(locale).format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "Sami Mansour · 4 visits · 1 call" above one person's visits of a day.
class _PersonHeader extends StatelessWidget {
  const _PersonHeader({required this.name, required this.visits, required this.calls});

  final String name;
  final int visits;
  final int calls;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: Row(children: [
        _Initials(name: name, radius: 11),
        const SizedBox(width: 8),
        Flexible(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Text(
          [l10n.visitsCount(visits), if (calls > 0) l10n.callsCount(calls)].join(' · '),
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.visitor,
    required this.kam,
    required this.locale,
    this.place,
  });

  final Visit visit;

  /// Which of the client's locations (Factory, Showroom, …), when labelled.
  final String? place;
  final String visitor;
  final String? kam;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = visit.isCall
        ? callColor
        : visit.isFlagged
            ? scheme.error
            : Colors.green.shade600;
    final time = visit.checkedInAt == null ? '' : DateFormat.jm(locale).format(visit.checkedInAt!);

    Widget chip(IconData icon, String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/visits/${visit.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        child: Icon(
                          visit.isCall
                              ? Icons.call
                              : visit.isFlagged
                                  ? Icons.wrong_location
                                  : Icons.where_to_vote,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    place == null ? visit.clientName : '${visit.clientName} · $place',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (time.isNotEmpty)
                                  Text(time, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                              ],
                            ),
                            if (visitor.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(children: [
                                  _Initials(name: visitor, radius: 9),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(visitor,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                                  ),
                                ]),
                              ),
                            if (visit.notes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(visit.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                              ),
                            if (visit.isCall) Padding(padding: const EdgeInsets.only(top: 6), child: CallChip(visit: visit)),
                            if (kam != null || visit.isFlagged)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (kam != null) chip(Icons.groups, l10n.withKam(kam!), Colors.teal),
                                    if (visit.isFar)
                                      chip(Icons.social_distance, l10n.farFlag(formatDistance(visit.distanceMeters!)), scheme.error),
                                    if (visit.mocked) chip(Icons.gps_off, l10n.fakeGpsFlag, scheme.error),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.radius});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letters = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p.characters.first).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(letters.toUpperCase(),
          style: TextStyle(fontSize: radius * 0.8, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Searchable list of the clients the user can visit; pops the chosen id.
class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet();

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final now = DateTime.now();
    final q = Client.normalizeName(_query);
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[])
        .where((c) =>
            q.isEmpty ||
            c.nameKey.contains(q) ||
            c.aliases.any((a) => Client.normalizeName(a).contains(q)) ||
            c.city.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      builder: (_, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.chooseClient, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                SearchBar(
                  autoFocus: true,
                  hintText: l10n.search,
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: clients.isEmpty
                ? Center(child: Text(l10n.noClients))
                : ListView.builder(
                    controller: scroll,
                    itemCount: clients.length,
                    itemBuilder: (_, i) {
                      final c = clients[i];
                      return ListTile(
                        leading: CategoryBadge(category: c.category, color: clientColor(c, rules, now), size: 36),
                        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [if (c.city.isNotEmpty) c.city, if (!c.hasLocation) l10n.noLocation].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, c.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
