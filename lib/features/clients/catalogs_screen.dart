import 'package:cloud_firestore/cloud_firestore.dart';
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
import '../visits/visit.dart';
import 'catalog_monitor.dart';
import 'client.dart';
import 'clients_repository.dart';
import 'given_items.dart';
import 'given_items_widgets.dart';
import '../../core/search_text.dart';

/// Every visit and call of the clients [key] (ids joined by ','), for the
/// visit totals of the clients table.
final _clientVisitsProvider = FutureProvider.autoDispose.family<List<Visit>, String>((ref, key) async {
  final ids = key.split(',').where((id) => id.isNotEmpty).toList();
  final batches = await Future.wait([
    for (var i = 0; i < ids.length; i += 30)
      FirebaseFirestore.instance
          .collection('visits')
          .where('clientId', whereIn: ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30))
          .get(),
  ]);
  return [
    for (final s in batches)
      for (final doc in s.docs) Visit.fromDoc(doc),
  ];
});

enum _Period { thisMonth, lastMonth, custom }

/// Clients table columns that sort (the item columns sort by total given).
enum _Col { client, salesperson, city, item0, item1, item2, item3, lastVisit, visits, calls }

/// Hand-overs table columns that sort.
enum _HCol { date, client, item, qty, salesperson }

/// Catalogs & stands (`/catalogs`, user request 2026-11-01; KAM: their
/// team's clients and hand-overs, sales manager / GM: all). Two tables
/// (user 2026-11-01: "look like a table, a clearer view"):
/// - Clients: a row per client, a column per item (total given, last date,
///   due colour), last visit, visits, calls; filtered by salesperson, client
///   name, item, status and city.
/// - Given in a period: totals per salesperson, then every hand-over.
class CatalogsScreen extends ConsumerStatefulWidget {
  const CatalogsScreen({super.key});

  @override
  ConsumerState<CatalogsScreen> createState() => _CatalogsScreenState();
}

class _CatalogsScreenState extends ConsumerState<CatalogsScreen> {
  // Clients table.
  final _search = TextEditingController();

  /// Clients who got this item; null = any.
  GivenItem? _item;

  /// Status of [_item] (any item when null: the most urgent).
  GivenStatus? _status;

  /// Client owner: null = everyone, '' = unassigned.
  String? _owner;
  String? _city;
  _Col _sort = _Col.client;
  bool _ascending = true;
  int _rowsPerPage = 25;

  // Given in a period.
  final _periodSearch = TextEditingController();
  _Period _period = _Period.thisMonth;
  StatsRange _range = StatsRange.month(DateTime.now());
  GivenItem? _periodItem;

  /// The giver; null = everyone.
  String? _giver;
  _HCol _hSort = _HCol.date;
  bool _hAscending = false;
  int _hRowsPerPage = 25;

  @override
  void dispose() {
    _search.dispose();
    _periodSearch.dispose();
    super.dispose();
  }

  Future<void> _setPeriod(_Period period) async {
    final now = DateTime.now();
    if (period != _Period.custom) {
      setState(() {
        _period = period;
        _range = StatsRange.month(period == _Period.thisMonth ? now : DateTime(now.year, now.month - 1));
      });
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end.isAfter(now) ? now : _range.end),
    );
    if (picked != null) {
      setState(() {
        _period = _Period.custom;
        _range = StatsRange(picked.start, picked.end);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final byId = {for (final u in users) u.id: u};
    String nameOf(String? id) => id == null || id.isEmpty ? l10n.unassigned : byId[id]?.name ?? l10n.deletedUser;

    // KAM: their team and themselves; managers: everyone.
    final team = me.can.isAdmin ? null : {me.id, for (final u in teamOf(me, users)) u.id};
    final allClients = ref.watch(clientsProvider).value ?? const <Client>[];
    final clients = team == null ? allClients : allClients.where((c) => team.contains(c.assignedTo)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.catalogsPage),
          bottom: TabBar(tabs: [Tab(text: l10n.clients), Tab(text: l10n.catalogsGivenInPeriod)]),
        ),
        body: TabBarView(
          children: [
            _clientsTab(context, clients, nameOf),
            // Every client: a team member's hand-over to someone else's client counts too.
            _periodTab(context, allClients, team, nameOf),
          ],
        ),
      ),
    );
  }

  Widget _clientsTab(BuildContext context, List<Client> clients, String Function(String?) nameOf) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final rules = ref.watch(givenItemRulesProvider).value ?? GivenItemRules.defaults;

    final withItems = clients.where((c) => c.given.isNotEmpty).toList();
    final ids = (withItems.map((c) => c.id).toList()..sort()).join(',');
    final visitsAsync = ref.watch(_clientVisitsProvider(ids));
    final all = catalogClientRows(
      clients: withItems,
      visits: visitsAsync.value ?? const <Visit>[],
      rules: rules,
      now: now,
    );

    final owners = {for (final r in all) r.client.assignedTo ?? ''}.toList()
      ..sort((a, b) => nameOf(a).compareTo(nameOf(b)));
    final cities = {for (final r in all) if (r.client.city.trim().isNotEmpty) r.client.city.trim()}.toList()..sort();
    if (_owner != null && !owners.contains(_owner)) _owner = null;
    if (_city != null && !cities.contains(_city)) _city = null;
    final query = foldSearch(_search.text);
    GivenStatus statusOf(CatalogClientRow r) =>
        _item == null ? r.status : givenStatus(r.client.given[_item], _item!, rules, now);
    final rows = [
      for (final r in all)
        if ((_item == null || r.client.given.containsKey(_item)) &&
            (_status == null || statusOf(r) == _status) &&
            (_owner == null || (r.client.assignedTo ?? '') == _owner) &&
            (_city == null || r.client.city.trim() == _city) &&
            (query.isEmpty ||
                searchHas(r.client.name, query) ||
                r.client.aliases.any((a) => searchHas(a, query))))
          r,
    ];
    final never = DateTime(0);
    int compare(CatalogClientRow a, CatalogClientRow b) => switch (_sort) {
          _Col.client => a.client.name.toLowerCase().compareTo(b.client.name.toLowerCase()),
          _Col.salesperson => nameOf(a.client.assignedTo).compareTo(nameOf(b.client.assignedTo)),
          _Col.city => a.client.city.compareTo(b.client.city),
          _Col.item0 || _Col.item1 || _Col.item2 || _Col.item3 => () {
              final item = GivenItem.values[_sort.index - _Col.item0.index];
              return (a.client.given[item]?.total ?? 0).compareTo(b.client.given[item]?.total ?? 0);
            }(),
          _Col.lastVisit => (a.lastVisitAt ?? never).compareTo(b.lastVisitAt ?? never),
          _Col.visits => a.visits.compareTo(b.visits),
          _Col.calls => a.calls.compareTo(b.calls),
        };
    rows.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));

    final filtered = _item != null || _status != null || _owner != null || _city != null || query.isNotEmpty;
    void sortBy(_Col c, bool ascending) => setState(() {
          _sort = c;
          _ascending = ascending;
        });
    DataColumn column(_Col c, Widget label, {bool numeric = false, String? tooltip}) => DataColumn(
          label: label,
          numeric: numeric,
          tooltip: tooltip,
          onSort: (_, asc) => sortBy(c, asc),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Text(l10n.catalogsClientsHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.clientName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            _Filter<String?>(
              label: l10n.salesperson,
              value: _owner,
              allLabel: l10n.everyone,
              options: [for (final id in owners) (id, nameOf(id))],
              onChanged: (v) => setState(() => _owner = v),
            ),
            _Filter<GivenItem?>(
              label: l10n.catalogsType,
              value: _item,
              allLabel: l10n.catalogsAllTypes,
              options: [
                for (final item in GivenItem.values)
                  (item, '${givenItemLabel(l10n, item)} (${withItems.where((c) => c.given.containsKey(item)).length})'),
              ],
              onChanged: (v) => setState(() => _item = v),
            ),
            _Filter<GivenStatus?>(
              label: l10n.catalogsStatus,
              value: _status,
              allLabel: l10n.catalogsAnyStatusShort,
              options: [
                (GivenStatus.due, l10n.givenDue),
                (GivenStatus.dueSoon, l10n.givenDueSoon),
                (GivenStatus.ok, l10n.catalogsUpToDate),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            if (cities.length > 1)
              _Filter<String?>(
                label: l10n.city,
                value: _city,
                allLabel: l10n.catalogsAllCities,
                options: [for (final c in cities) (c, c)],
                onChanged: (v) => setState(() => _city = v),
              ),
            if (filtered)
              TextButton.icon(
                onPressed: () => setState(() {
                  _search.clear();
                  _item = null;
                  _status = null;
                  _owner = null;
                  _city = null;
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: Text(l10n.clearFilters),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (visitsAsync.isLoading) const LinearProgressIndicator(),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text(l10n.catalogsNoClients)),
          )
        else
          PaginatedDataTable(
            header: Text(l10n.catalogsClientsShown(rows.length), style: theme.textTheme.titleMedium),
            showCheckboxColumn: false,
            showFirstLastButtons: true,
            columnSpacing: 20,
            horizontalMargin: 12,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 52,
            headingRowHeight: 48,
            sortColumnIndex: _sort.index,
            sortAscending: _ascending,
            rowsPerPage: _rowsPerPage,
            availableRowsPerPage: const [10, 25, 50, 100],
            onRowsPerPageChanged: (n) => setState(() => _rowsPerPage = n ?? _rowsPerPage),
            columns: [
              column(_Col.client, Text(l10n.clients)),
              column(_Col.salesperson, Text(l10n.salesperson)),
              column(_Col.city, Text(l10n.city)),
              for (final item in GivenItem.values)
                column(
                  _Col.values[_Col.item0.index + item.index],
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(givenItemIcon(item), size: 18),
                    const SizedBox(width: 4),
                    Text(givenItemLabel(l10n, item)),
                  ]),
                  tooltip: l10n.catalogsItemColumnHelp,
                ),
              column(_Col.lastVisit, Text(l10n.lastVisit)),
              column(_Col.visits, Text(l10n.visits), numeric: true),
              column(_Col.calls, Text(l10n.catalogsCalls), numeric: true),
            ],
            source: _ClientsSource(
              rows: rows,
              nameOf: nameOf,
              rules: rules,
              now: now,
              locale: locale,
              l10n: l10n,
              theme: theme,
              highlight: _item,
              visitsLoaded: visitsAsync.hasValue,
              onOpen: (id) => context.push('/clients/$id'),
            ),
          ),
      ],
    );
  }

  Widget _periodTab(BuildContext context, List<Client> clients, Set<String>? team, String Function(String?) nameOf) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final day = DateFormat.yMMMd(locale);

    // Visits saved by app builds before the hand-over log carry `given` only.
    final visits = ref.watch(rangeVisitsProvider((null, _range.months.join(',')))).value ?? const <Visit>[];
    final all = [
      for (final h in handoversIn(clients: clients, visits: visits, range: _range))
        if (team == null || team.contains(h.byId) || team.contains(h.client.assignedTo)) h,
    ];
    final query = foldSearch(_periodSearch.text);
    final matching = [
      for (final h in all)
        if ((_periodItem == null || h.item == _periodItem) &&
            (query.isEmpty || searchHas(h.client.name, query)))
          h,
    ];
    final totals = handoverTotals(matching);
    final givers = {for (final h in all) h.byId}.toList()..sort((a, b) => nameOf(a).compareTo(nameOf(b)));
    if (_giver != null && !givers.contains(_giver)) _giver = null;
    final list = [
      for (final h in matching)
        if (_giver == null || h.byId == _giver) h,
    ];
    int compare(Handover a, Handover b) => switch (_hSort) {
          _HCol.date => a.at.compareTo(b.at),
          _HCol.client => a.client.name.toLowerCase().compareTo(b.client.name.toLowerCase()),
          _HCol.item => a.item.index.compareTo(b.item.index),
          _HCol.qty => a.qty.compareTo(b.qty),
          _HCol.salesperson => nameOf(a.byId).compareTo(nameOf(b.byId)),
        };
    list.sort((a, b) => _hAscending ? compare(a, b) : compare(b, a));
    final grand = HandoverTotals('');
    for (final t in totals) {
      t.byItem.forEach((k, v) => grand.byItem[k] = (grand.byItem[k] ?? 0) + v);
      grand.clientIds.addAll(t.clientIds);
    }
    final items = _periodItem == null ? GivenItem.values : [_periodItem!];

    DataRow totalsRow(HandoverTotals t, {required bool total}) {
      final style = total ? const TextStyle(fontWeight: FontWeight.bold) : null;
      return DataRow(
        selected: !total && _giver == t.byId,
        onSelectChanged: total ? null : (_) => setState(() => _giver = _giver == t.byId ? null : t.byId),
        cells: [
          DataCell(Text(total ? l10n.reportTotal : nameOf(t.byId), style: style)),
          for (final item in items) DataCell(Text('${t.byItem[item] ?? 0}', style: style)),
          DataCell(Text('${t.clientIds.length}', style: style)),
          if (_periodItem == null) DataCell(Text('${t.total}', style: style)),
        ],
      );
    }

    DataColumn hColumn(_HCol c, String label, {bool numeric = false}) => DataColumn(
          label: Text(label),
          numeric: numeric,
          onSort: (_, asc) => setState(() {
            _hSort = c;
            _hAscending = asc;
          }),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Text(l10n.catalogsPeriodHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (p, label) in [
              (_Period.thisMonth, l10n.thisMonth),
              (_Period.lastMonth, l10n.lastMonth),
              (_Period.custom, l10n.customRange),
            ])
              ChoiceChip(label: Text(label), selected: _period == p, onSelected: (_) => _setPeriod(p)),
            Text('${day.format(_range.start)} – ${day.format(_range.end)}', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                controller: _periodSearch,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.clientName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            _Filter<String?>(
              label: l10n.salesperson,
              value: _giver,
              allLabel: l10n.everyone,
              options: [for (final id in givers) (id, nameOf(id))],
              onChanged: (v) => setState(() => _giver = v),
            ),
            _Filter<GivenItem?>(
              label: l10n.catalogsType,
              value: _periodItem,
              allLabel: l10n.catalogsAllTypes,
              options: [for (final item in GivenItem.values) (item, givenItemLabel(l10n, item))],
              onChanged: (v) => setState(() => _periodItem = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (totals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text(l10n.reportNoCatalogs)),
          )
        else ...[
          Text(l10n.catalogsBySalesperson, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Card(
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 20,
                columns: [
                  DataColumn(label: Text(l10n.salesperson)),
                  for (final item in items)
                    DataColumn(
                      numeric: true,
                      label: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(givenItemIcon(item), size: 18),
                        const SizedBox(width: 4),
                        Text(givenItemLabel(l10n, item)),
                      ]),
                    ),
                  DataColumn(numeric: true, label: Text(l10n.clients)),
                  if (_periodItem == null) DataColumn(numeric: true, label: Text(l10n.reportTotal)),
                ],
                rows: [
                  for (final t in totals) totalsRow(t, total: false),
                  if (totals.length > 1) totalsRow(grand, total: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (list.isNotEmpty)
            PaginatedDataTable(
              header: Text(l10n.catalogsHandovers(list.length), style: theme.textTheme.titleMedium),
              showCheckboxColumn: false,
              showFirstLastButtons: true,
              columnSpacing: 20,
              horizontalMargin: 12,
              sortColumnIndex: _hSort.index,
              sortAscending: _hAscending,
              rowsPerPage: _hRowsPerPage,
              availableRowsPerPage: const [10, 25, 50, 100],
              onRowsPerPageChanged: (n) => setState(() => _hRowsPerPage = n ?? _hRowsPerPage),
              columns: [
                hColumn(_HCol.date, l10n.catalogsDate),
                hColumn(_HCol.client, l10n.clients),
                hColumn(_HCol.item, l10n.catalogsType),
                hColumn(_HCol.qty, l10n.quantity, numeric: true),
                hColumn(_HCol.salesperson, l10n.salesperson),
                DataColumn(label: Text(l10n.catalogsHow)),
              ],
              source: _HandoversSource(
                rows: list,
                nameOf: nameOf,
                day: day,
                l10n: l10n,
                onOpen: (id) => context.push('/clients/$id'),
              ),
            ),
        ],
      ],
    );
  }
}

/// A labelled dropdown filter ("Salesperson: Everyone").
class _Filter<T> extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final String allLabel;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        filled: active,
        fillColor: active ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: [
            DropdownMenuItem<T>(value: null as T, child: Text(allLabel)),
            for (final (v, text) in options) DropdownMenuItem<T>(value: v, child: Text(text)),
          ],
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}

class _ClientsSource extends DataTableSource {
  _ClientsSource({
    required this.rows,
    required this.nameOf,
    required this.rules,
    required this.now,
    required this.locale,
    required this.l10n,
    required this.theme,
    required this.highlight,
    required this.visitsLoaded,
    required this.onOpen,
  });

  final List<CatalogClientRow> rows;
  final String Function(String?) nameOf;
  final GivenItemRules rules;
  final DateTime now;
  final String locale;
  final AppLocalizations l10n;
  final ThemeData theme;

  /// The item filtered on: its column is tinted.
  final GivenItem? highlight;
  final bool visitsLoaded;
  final ValueChanged<String> onOpen;

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final r = rows[index];
    final c = r.client;
    final day = DateFormat.yMMMd(locale);
    final small = theme.textTheme.bodySmall;
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget twoLines(String top, String? bottom, {Color? color, bool bold = false}) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(top, style: TextStyle(color: color, fontWeight: bold ? FontWeight.w600 : null)),
            if (bottom != null) Text(bottom, style: small?.copyWith(color: color ?? muted)),
          ],
        );
    final last = r.lastVisitAt;
    return DataRow(
      onSelectChanged: (_) => onOpen(c.id),
      cells: [
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        )),
        DataCell(Text(nameOf(c.assignedTo))),
        DataCell(Text(c.city)),
        for (final item in GivenItem.values)
          DataCell(() {
            final g = c.given[item];
            if (g == null) return Text('–', style: TextStyle(color: muted));
            final status = givenStatus(g, item, rules, now);
            final color = givenStatusColor(status);
            final note = switch (status) {
              GivenStatus.due => ' · ${l10n.givenDue}',
              GivenStatus.dueSoon => ' · ${l10n.givenDueSoon}',
              _ => '',
            };
            return Container(
              color: highlight == item ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25) : null,
              child: twoLines('${g.total}', g.at == null ? null : '${day.format(g.at!)}$note',
                  color: color, bold: status == GivenStatus.due),
            );
          }()),
        DataCell(!visitsLoaded
            ? const Text('…')
            : last == null
                ? Text(l10n.catalogsNeverVisited, style: TextStyle(color: theme.colorScheme.error))
                : twoLines(day.format(last), l10n.daysAgo(now.difference(last).inDays))),
        DataCell(Text(visitsLoaded ? '${r.visits}' : '…')),
        DataCell(Text(visitsLoaded ? '${r.calls}' : '…')),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

  @override
  int get selectedRowCount => 0;
}

class _HandoversSource extends DataTableSource {
  _HandoversSource({required this.rows, required this.nameOf, required this.day, required this.l10n, required this.onOpen});

  final List<Handover> rows;
  final String Function(String?) nameOf;
  final DateFormat day;
  final AppLocalizations l10n;
  final ValueChanged<String> onOpen;

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final h = rows[index];
    return DataRow(
      onSelectChanged: (_) => onOpen(h.client.id),
      cells: [
        DataCell(Text(day.format(h.at))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(h.client.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        )),
        DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(givenItemIcon(h.item), size: 18),
          const SizedBox(width: 6),
          Text(givenItemLabel(l10n, h.item)),
        ])),
        DataCell(Text('${h.qty}')),
        DataCell(Text(nameOf(h.byId))),
        DataCell(Text(h.atVisit ? l10n.givenAtVisit : l10n.givenRecordedByHand)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

  @override
  int get selectedRowCount => 0;
}
