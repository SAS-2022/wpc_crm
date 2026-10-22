import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/map_controls.dart';
import '../../core/providers.dart';
import '../users/users_repository.dart';
import '../../l10n/app_localizations.dart';
import 'client.dart';
import 'client_locations_section.dart';
import 'client_sheet.dart';
import 'client_tags.dart';
import 'client_filters.dart';
import '../plan/plan_selection.dart';
import 'client_search.dart';
import 'client_widgets.dart';
import 'transfer_dialog.dart';
import 'clients_repository.dart';
import 'person_style.dart';
import 'visit_rules.dart';

/// Map filter. [planned] = on today's plan; it shows blue and takes
/// precedence over the visit status colour.
enum _Status { all, recent, dueSoon, overdue, planned }

class ClientsMapScreen extends ConsumerStatefulWidget {
  const ClientsMapScreen({super.key});

  @override
  ConsumerState<ClientsMapScreen> createState() => _ClientsMapScreenState();
}

class _ClientsMapScreenState extends ConsumerState<ClientsMapScreen> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  });
  _Status _status = _Status.all;
  int? _fittedTo;

  /// Search on the map (same fields as the Clients list); the map zooms to
  /// the results once typing pauses (user request 2026-10-20).
  final _search = TextEditingController();
  ClientQuery _query = ClientQuery('');
  Timer? _searchDelay;

  void _onSearch(String v) {
    _searchDelay?.cancel();
    _searchDelay = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = ClientQuery(v));
    });
    setState(() {}); // the clear button
  }

  /// KAM / managers: pins coloured by salesperson instead of visit status.
  bool _byPerson = false;

  /// Web, KAM / managers: tapping pins picks clients to move or plan together.
  bool _selecting = false;
  final _selected = <String>{};

  /// Client id → the location pin tapped, for clients with several
  /// locations (planned there; otherwise the main one).
  final _selectedAt = <String, String>{};
  bool _moving = false;

  /// This pin is the picked one: for a client with several locations only
  /// the location tapped, not all of its pins.
  bool _isPicked(Client c, ClientLocation loc) =>
      _selected.contains(c.id) &&
      (c.locations.length == 1 || (_selectedAt[c.id] ?? ClientLocation.mainId) == loc.id);

  /// Each picked client onto its salesperson's plan for a chosen day.
  Future<void> _planSelected(List<Client> all) async {
    final picked = [for (final c in all) if (_selected.contains(c.id)) c];
    setState(() => _moving = true);
    final done = await addSelectionToPlans(context, ref, picked, locations: _selectedAt);
    if (!mounted) return;
    setState(() {
      _moving = false;
      if (done) _selected.clear();
    });
  }

  Future<void> _moveSelected(List<Client> all) async {
    final picked = [for (final c in all) if (_selected.contains(c.id)) c];
    setState(() => _moving = true);
    final moved = await showTransferDialog(context, ref, picked);
    if (!mounted) return;
    setState(() {
      _moving = false;
      if (moved) _selected.clear();
    });
  }

  @override
  void dispose() {
    _searchDelay?.cancel();
    _search.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _fit(List<LatLng> points) {
    if (_map != null) fitPoints(_map!, points, padding: 48);
  }

  /// Centres on the user at street level (zoom 15).
  Future<void> _goToMe() async {
    final me = await locateMe();
    if (me == null || !mounted) return;
    _map?.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final now = DateTime.now();
    final users = {for (final u in ref.watch(usersProvider).value ?? const []) u.id: u};
    final located = (ref.watch(filteredClientsProvider).value ?? const <Client>[])
        .where((c) => c.hasLocation)
        .where((c) => _query.isEmpty || searchClient(c, _query, salesperson: users[c.assignedTo]?.name ?? '') != null)
        .toList();
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final filter = ref.watch(salesFilterProvider);
    final planned = {
      for (final e in ref.watch(plannedTodayProvider).entries)
        if (filter.isEmpty || filter.contains(e.value)) e.key,
    };
    _Status statusOf(Client c) => planned.contains(c.id)
        ? _Status.planned
        : switch (visitStatus(c, rules, now)) {
            VisitStatus.recent => _Status.recent,
            VisitStatus.dueSoon => _Status.dueSoon,
            VisitStatus.overdue => _Status.overdue,
          };
    final styles = ref.watch(personStylesProvider);
    PersonStyle styleOf(Client c) => styles[c.assignedTo] ?? unassignedStyle;
    final byPerson = _byPerson && (me?.role.isSupervisor ?? false);
    Color colorOf(Client c) => byPerson
        ? styleOf(c).color
        : planned.contains(c.id)
        ? plannedColor
        : clientColor(c, rules, now);
    // Salesperson legend: everyone with clients on the map, most clients first.
    final perPerson = <String?, int>{};
    for (final c in located) {
      perPerson[c.assignedTo] = (perPerson[c.assignedTo] ?? 0) + 1;
    }
    final legend = perPerson.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    int count(_Status s) => s == _Status.all ? located.length : located.where((c) => statusOf(c) == s).length;
    final clients = _status == _Status.all ? located : located.where((c) => statusOf(c) == _status).toList();
    // One pin per location (main, factory, showroom, …), all in the client's colour.
    final points = [for (final c in clients) for (final l in c.locations) LatLng(l.lat, l.lng)];
    final types = ref.watch(locationTypesByIdProvider);
    // Moving clients from the map: web dashboard, KAM / managers.
    final canSelect = kIsWeb && (me?.role.isSupervisor ?? false);
    final lang = Localizations.localeOf(context).languageCode;

    // Re-centre on the visible clients when a filter changes (not on first
    // load, which starts at the user's location, and not when the data
    // changes, e.g. after moving clients to another salesperson).
    final signature = Object.hash(
      _status,
      filter,
      ref.watch(clientTypeFilterProvider),
      Object.hashAllUnordered(ref.watch(tagFilterProvider)),
      Object.hashAllUnordered(ref.watch(givenDueFilterProvider)),
      _query.text,
    );
    if (_fittedTo == null && clients.isNotEmpty) {
      _fittedTo = signature;
    } else if (_map != null && _fittedTo != null && signature != _fittedTo) {
      _fittedTo = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.map),
        actions: [
          IconButton(icon: const Icon(Icons.list), tooltip: l10n.clients, onPressed: () => context.go('/clients')),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 15),
            mapType: ref.watch(mapTypeProvider),
            minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
            // Keeps the Google logo and fitted markers clear of the filter card.
            padding: EdgeInsets.only(top: ((me?.role.isSupervisor ?? false) ? 120 : 64) + 52),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              setState(() => _map = controller);
              _goToMe();
            },
            markers: {
              for (final c in clients)
                for (final (i, loc) in c.locations.indexed)
                  Marker(
                    markerId: MarkerId('${c.id}/${loc.id}'),
                    position: LatLng(loc.lat, loc.lng),
                    anchor: const Offset(0.5, 0.5),
                    icon: _icons.circle(
                      context: context,
                      fill: colorOf(c),
                      // Picked for moving: thick dark ring, slightly bigger.
                      ring: _isPicked(c, loc) ? Colors.black : Colors.white,
                      ringWidth: _isPicked(c, loc) ? 5 : 2,
                      size: _isPicked(c, loc) ? 38 : 30,
                      // Salesperson mode: their initials; otherwise the category letter.
                      text: byPerson ? styleOf(c).initials : c.category,
                      // Dark letter on yellow, white on the darker colours.
                      textColor: !byPerson && colorOf(c) == statusDueSoonColor ? Colors.black87 : Colors.white,
                    ),
                    onTap: () => _selecting
                        ? setState(() {
                            if (_isPicked(c, loc)) {
                              _selected.remove(c.id);
                              _selectedAt.remove(c.id);
                            } else {
                              // The pin tapped: that location goes on the plan
                              // (another pin of a picked client switches to it).
                              _selected.add(c.id);
                              if (c.locations.length > 1) _selectedAt[c.id] = loc.id;
                            }
                          })
                        : showClientSheet(
                            context,
                            ref,
                            c,
                            c.locations.length > 1 ? locationLabel(loc, i, types, lang, l10n) : null,
                            null,
                            canSelect
                                ? () => setState(() {
                                      _selecting = true;
                                      _selected.add(c.id);
                                      if (c.locations.length > 1) _selectedAt[c.id] = loc.id;
                                    })
                                : null,
                            c.locations.length > 1 ? loc : null,
                          ),
                  ),
            },
          ),
          PositionedDirectional(
            top: 8,
            start: 8,
            end: 8,
            child: PointerInterceptor(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: _onSearch,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n.searchClientsHint,
                          // How many matched, or none.
                          helperText: _query.isEmpty
                              ? null
                              : clients.isEmpty
                                  ? l10n.noClientsFound
                                  : l10n.searchResultsOnMap(clients.length),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: l10n.clear,
                                  onPressed: () {
                                    _search.clear();
                                    _onSearch('');
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const ClientFiltersButton(),
                            if (canSelect) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: l10n.selectClientsToMove,
                                isSelected: _selecting,
                                icon: const Icon(Icons.checklist),
                                onPressed: () => setState(() {
                                  _selecting = !_selecting;
                                  _selected.clear();
                                }),
                              ),
                            ],
                            if (me?.role.isSupervisor ?? false) ...[
                              const SizedBox(width: 12),
                              Text(l10n.colourBy, style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(width: 8),
                              // Two segments when there's room (web); on phones a
                              // menu button, since the segments' labels wrapped.
                              Expanded(
                                child: LayoutBuilder(builder: (context, c) {
                                  void choose(bool person) => setState(() {
                                        _byPerson = person;
                                        // The status filter's chips are hidden in this mode.
                                        _status = _Status.all;
                                      });
                                  if (c.maxWidth >= 260) {
                                    return SegmentedButton<bool>(
                                      showSelectedIcon: false,
                                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                                      segments: [
                                        ButtonSegment(value: false, label: Text(l10n.visitStatus)),
                                        ButtonSegment(value: true, label: Text(l10n.salesperson)),
                                      ],
                                      selected: {byPerson},
                                      onSelectionChanged: (s) => choose(s.first),
                                    );
                                  }
                                  return Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: PopupMenuButton<bool>(
                                      tooltip: l10n.colourBy,
                                      initialValue: byPerson,
                                      onSelected: choose,
                                      itemBuilder: (_) => [
                                        PopupMenuItem(value: false, child: Text(l10n.visitStatus)),
                                        PopupMenuItem(value: true, child: Text(l10n.salesperson)),
                                      ],
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
                                        ),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Flexible(
                                            child: Text(
                                              byPerson ? l10n.salesperson : l10n.visitStatus,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down),
                                        ]),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Padding(padding: EdgeInsets.only(bottom: 4), child: ActiveClientFilters(compact: true)),
                      // Salesperson colours: legend chips, tap to show one person.
                      if (byPerson)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final MapEntry(key: uid, value: n) in legend)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 6),
                                  child: FilterChip(
                                    showCheckmark: false,
                                    visualDensity: VisualDensity.compact,
                                    avatar: Icon(Icons.circle, size: 12, color: (styles[uid] ?? unassignedStyle).color),
                                    label: Text('${uid == null ? l10n.unassigned : users[uid]?.name ?? '?'} ($n)'),
                                    selected: filter.contains(uid ?? unassignedFilter),
                                    onSelected: (_) => ref.read(salesFilterProvider.notifier).toggle(uid ?? unassignedFilter),
                                  ),
                                ),
                            ],
                          ),
                        )
                      // Status filter; the coloured dots double as the map legend.
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (st, label, color) in [
                                (_Status.all, l10n.statusAll, null),
                                (_Status.recent, l10n.statusRecent, statusRecentColor),
                                (_Status.dueSoon, l10n.statusDueSoon, statusDueSoonColor),
                                (_Status.overdue, l10n.statusOverdue, statusOverdueColor),
                                (_Status.planned, l10n.plannedToday, plannedColor),
                              ])
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 6),
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: color == null ? null : Icon(Icons.circle, size: 12, color: color),
                                    label: Text('$label (${count(st)})'),
                                    selected: _status == st,
                                    onSelected: (_) => setState(() => _status = st),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_selecting)
            PositionedDirectional(
              start: 12,
              end: 72,
              bottom: 24,
              child: PointerInterceptor(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _selected.isEmpty ? l10n.tapPinsToSelect : l10n.selectedCount(_selected.length),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        FilledButton.icon(
                          onPressed: _selected.isEmpty || _moving ? null : () => _planSelected(located),
                          icon: const Icon(Icons.playlist_add),
                          label: Text(l10n.addToPlan),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _selected.isEmpty || _moving ? null : () => _moveSelected(located),
                          icon: const Icon(Icons.swap_horiz),
                          label: Text(l10n.moveToSalesperson),
                        ),
                        if (_selected.isNotEmpty)
                          TextButton(onPressed: () => setState(_selected.clear), child: Text(l10n.clear)),
                        TextButton(
                          onPressed: () => setState(() {
                            _selecting = false;
                            _selected.clear();
                          }),
                          child: Text(l10n.done),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          PositionedDirectional(
            end: 12,
            bottom: 32,
            child: MapControls(map: _map, onMyLocation: _goToMe, onFitAll: () => _fit(points)),
          ),
        ],
      ),
    );
  }
}
