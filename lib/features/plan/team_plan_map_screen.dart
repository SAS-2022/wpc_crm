import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/app_user.dart';
import '../../core/map_controls.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/clients_repository.dart';
import '../clients/person_style.dart';
import '../clients/visit_rules.dart';
import '../home/dashboard_cards.dart';
import '../users/users_repository.dart';
import 'plan_repository.dart';
import 'plan_task.dart';
import 'route_order.dart';

/// Every team member's planned visits for one day on one map (user request
/// 2026-10-19): pins in the person's colour numbered in their shortest order,
/// a dashed line per person, a green ring when visited and a yellow one
/// while waiting for approval. Legend chips show / hide people.
class TeamPlanMapScreen extends ConsumerStatefulWidget {
  const TeamPlanMapScreen({super.key, required this.date});

  /// 'yyyy-MM-dd'.
  final String date;

  @override
  ConsumerState<TeamPlanMapScreen> createState() => _TeamPlanMapScreenState();
}

class _TeamPlanMapScreenState extends ConsumerState<TeamPlanMapScreen> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  });
  bool _fitted = false;

  /// People hidden with the legend chips.
  final _hidden = <String>{};

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _goToMe() async {
    final me = await locateMe();
    if (me == null || !mounted) return;
    _map?.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
  }

  void _fit(List<LatLng> points) {
    if (_map != null && points.isNotEmpty) fitPoints(_map!, points);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final team = {for (final u in teamOf(me, users)) u.id: u, if (me.role.isTracked) me.id: me};
    final styles = ref.watch(personStylesProvider);
    final clients = {for (final c in ref.watch(allClientsProvider).value ?? const <Client>[]) c.id: c};
    final all = ref.watch(teamDayTasksProvider(widget.date)).value ?? const <PlanTask>[];

    // Each person's located visits, in their shortest order.
    final routes = <String, List<PlanTask>>{};
    var missing = 0;
    final byOwner = <String, List<PlanTask>>{};
    for (final t in all) {
      if (t.isVisit && t.approval != TaskApproval.rejected && team.containsKey(t.ownerId)) {
        (byOwner[t.ownerId] ??= []).add(t);
      }
    }
    for (final MapEntry(key: uid, value: tasks) in byOwner.entries) {
      final numbers = planStopNumbers(tasks, clients);
      routes[uid] = inRouteOrder(tasks, numbers).where((t) => numbers.containsKey(t.id)).toList();
      missing += tasks.length - routes[uid]!.length;
    }
    final people = routes.keys.toList()..sort((a, b) => team[a]!.name.compareTo(team[b]!.name));
    // The picked location of each stop, else the client's main one.
    LatLng at(PlanTask t) => LatLng(planStop(t, clients)!.lat, planStop(t, clients)!.lng);
    final shown = [for (final uid in people) if (!_hidden.contains(uid)) uid];
    final points = [for (final uid in shown) for (final t in routes[uid]!) at(t)];
    Color colorOf(String uid) => (styles[uid] ?? unassignedStyle).color;

    if (_map != null && !_fitted && points.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
    }
    final day = DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(DateTime.parse(widget.date));

    return Scaffold(
      appBar: AppBar(title: Text('${l10n.teamPlans} · $day')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 11),
            mapType: ref.watch(mapTypeProvider),
            padding: const EdgeInsets.only(top: 96),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) => setState(() => _map = controller),
            polylines: {
              for (final uid in shown)
                if (routes[uid]!.length > 1)
                  Polyline(
                    polylineId: PolylineId(uid),
                    points: [for (final t in routes[uid]!) at(t)],
                    color: colorOf(uid).withValues(alpha: 0.7),
                    width: 3,
                    patterns: [PatternItem.dash(14), PatternItem.gap(8)],
                  ),
            },
            markers: {
              for (final uid in shown)
                for (final (i, t) in routes[uid]!.indexed)
                  Marker(
                    markerId: MarkerId(t.id),
                    position: at(t),
                    anchor: const Offset(0.5, 0.5),
                    icon: _icons.circle(
                      context: context,
                      fill: colorOf(uid),
                      text: '${i + 1}',
                      ring: t.done
                          ? statusRecentColor
                          : t.approval == TaskApproval.pending
                              ? statusDueSoonColor
                              : Colors.white,
                      ringWidth: t.done || t.approval == TaskApproval.pending ? 4 : 2,
                      size: 34,
                    ),
                    onTap: () => _showItem(team[uid]!, t, clients[t.clientId]!, i + 1),
                  ),
            },
          ),
          PositionedDirectional(
            end: 12,
            bottom: 32,
            child: MapControls(map: _map, onMyLocation: _goToMe, onFitAll: points.isEmpty ? null : () => _fit(points)),
          ),
          PositionedDirectional(
            top: 8,
            start: 8,
            end: 8,
            child: PointerInterceptor(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (people.isEmpty)
                        Text(l10n.nothingPlanned)
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final uid in people)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(end: 6),
                                  child: FilterChip(
                                    visualDensity: VisualDensity.compact,
                                    showCheckmark: false,
                                    avatar: Icon(Icons.circle, size: 12, color: colorOf(uid)),
                                    label: Text(
                                      '${team[uid]!.name} (${routes[uid]!.where((t) => t.done).length}/${routes[uid]!.length})',
                                    ),
                                    selected: !_hidden.contains(uid),
                                    onSelected: (on) => setState(() => on ? _hidden.remove(uid) : _hidden.add(uid)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          for (final (color, label) in [
                            (statusRecentColor, l10n.done),
                            (statusDueSoonColor, l10n.waitingApproval),
                          ])
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.radio_button_unchecked, size: 14, color: color),
                                const SizedBox(width: 4),
                                Text(label, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          if (missing > 0) Text(l10n.planClientsWithoutLocation(missing), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showItem(AppUser owner, PlanTask t, Client c, int number) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => PointerInterceptor(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$number. ${c.name}', style: Theme.of(context).textTheme.titleMedium),
                Text([owner.name, if (c.city.isNotEmpty) c.city].join(' · ')),
                if (t.title.isNotEmpty) Text(t.title),
                Text(t.done
                    ? l10n.done
                    : t.approval == TaskApproval.pending
                        ? l10n.waitingApproval
                        : l10n.toDo),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheet);
                        context.push('/clients/${c.id}');
                      },
                      child: Text(l10n.details),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(sheet);
                        context.push('/plan/${owner.id}?date=${widget.date}');
                      },
                      child: Text(l10n.openPlan),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
