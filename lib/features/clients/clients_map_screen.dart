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
import 'client_widgets.dart';
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

  /// KAM / managers: pins coloured by salesperson instead of visit status.
  bool _byPerson = false;

  @override
  void dispose() {
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
    final located = (ref.watch(filteredClientsProvider).value ?? const <Client>[]).where((c) => c.hasLocation).toList();
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final filter = ref.watch(salesFilterProvider);
    final planned = {
      for (final e in ref.watch(plannedTodayProvider).entries)
        if (filter == null || e.value == filter) e.key,
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
    final users = {for (final u in ref.watch(usersProvider).value ?? const []) u.id: u};
    // Salesperson legend: everyone with clients on the map, most clients first.
    final perPerson = <String?, int>{};
    for (final c in located) {
      perPerson[c.assignedTo] = (perPerson[c.assignedTo] ?? 0) + 1;
    }
    final legend = perPerson.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    int count(_Status s) => s == _Status.all ? located.length : located.where((c) => statusOf(c) == s).length;
    final clients = _status == _Status.all ? located : located.where((c) => statusOf(c) == _status).toList();
    final points = [for (final c in clients) LatLng(c.lat!, c.lng!)];

    // Re-centre on the visible clients when a filter changes what is shown
    // (not on first load, which starts at the user's location).
    final signature = Object.hashAll(clients.map((c) => c.id));
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
            minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
            // Keeps the Google logo and fitted markers clear of the filter card.
            padding: EdgeInsets.only(top: (me?.role.isSupervisor ?? false) ? 120 : 64),
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
                Marker(
                  markerId: MarkerId(c.id),
                  position: LatLng(c.lat!, c.lng!),
                  anchor: const Offset(0.5, 0.5),
                  icon: _icons.circle(
                    context: context,
                    fill: colorOf(c),
                    // Salesperson mode: their initials; otherwise the category letter.
                    text: byPerson ? styleOf(c).initials : c.category,
                    // Dark letter on yellow, white on the darker colours.
                    textColor: !byPerson && colorOf(c) == statusDueSoonColor ? Colors.black87 : Colors.white,
                  ),
                  onTap: () => _showClient(context, c),
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
                      if (me?.role.isSupervisor ?? false) ...[
                        Row(
                          children: [
                            const Icon(Icons.filter_alt_outlined),
                            const SizedBox(width: 8),
                            const Expanded(child: SalesFilterDropdown()),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text(l10n.colourBy, style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SegmentedButton<bool>(
                                  showSelectedIcon: false,
                                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                                  segments: [
                                    ButtonSegment(value: false, label: Text(l10n.visitStatus)),
                                    ButtonSegment(value: true, label: Text(l10n.salesperson)),
                                  ],
                                  selected: {byPerson},
                                  onSelectionChanged: (s) => setState(() {
                                    _byPerson = s.first;
                                    // The status filter's chips are hidden in this mode.
                                    _status = _Status.all;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Salesperson colours: legend chips, tap to show one person.
                      if (byPerson)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final MapEntry(key: uid, value: n) in legend)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 6),
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: Icon(Icons.circle, size: 12, color: (styles[uid] ?? unassignedStyle).color),
                                    label: Text('${uid == null ? l10n.unassigned : users[uid]?.name ?? '?'} ($n)'),
                                    selected: filter != null && filter == (uid ?? unassignedFilter),
                                    onSelected: (on) =>
                                        ref.read(salesFilterProvider.notifier).set(on ? uid ?? unassignedFilter : null),
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
          PositionedDirectional(
            end: 12,
            bottom: 32,
            child: MapControls(map: _map, onMyLocation: _goToMe, onFitAll: () => _fit(points)),
          ),
        ],
      ),
    );
  }

  void _showClient(BuildContext context, Client c) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c.name, style: Theme.of(context).textTheme.titleMedium),
              if (c.city.isNotEmpty) Text(c.city),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final name =
                      ref.read(usersProvider).value?.where((u) => u.id == c.assignedTo).firstOrNull?.name ??
                      l10n.unassigned;
                  return Row(
                    children: [
                      PersonBadge(userId: c.assignedTo, name: name, size: 24),
                      const SizedBox(width: 8),
                      Expanded(child: Text(name)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheet);
                        context.push('/clients/${c.id}');
                      },
                      child: Text(l10n.details),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheet);
                        context.push('/clients/${c.id}/visit');
                      },
                      icon: const Icon(Icons.add_location_alt),
                      label: Text(l10n.addVisit),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
