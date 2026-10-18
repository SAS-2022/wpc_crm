import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/map_controls.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/clients_repository.dart';
import '../clients/visit_rules.dart';
import '../notifications/notifications.dart';
import '../users/users_repository.dart';
import 'plan_repository.dart';
import 'plan_task.dart';
import 'route_order.dart';

/// The clients of one day's plan as numbered markers: blue = planned,
/// yellow = waiting for approval, green = visited. KAM / managers can
/// approve or remove items from here.
class PlanMapScreen extends ConsumerStatefulWidget {
  const PlanMapScreen({super.key, required this.userId, required this.date});

  final String userId;
  final String date;

  @override
  ConsumerState<PlanMapScreen> createState() => _PlanMapScreenState();
}

class _PlanMapScreenState extends ConsumerState<PlanMapScreen> {
  GoogleMapController? _map;
  late final _icons = MarkerIcons(() {
    if (mounted) setState(() {});
  });
  bool _fitted = false;

  Future<void> _goToMe() async {
    final me = await locateMe();
    if (me == null || !mounted) return;
    _map?.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Color _color(PlanTask t) => t.done
      ? statusRecentColor
      : t.approval == TaskApproval.pending
      ? statusDueSoonColor
      : plannedColor;

  void _fit(List<LatLng> points) {
    if (_map != null) fitPoints(_map!, points);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final owner = (ref.watch(usersProvider).value ?? const <AppUser>[]).where((u) => u.id == widget.userId).firstOrNull;
    final clients = {for (final c in ref.watch(allClientsProvider).value ?? const <Client>[]) c.id: c};
    final tasks = (ref.watch(dayTasksProvider((widget.userId, widget.date))).value ?? const <PlanTask>[])
        .where((t) => t.isVisit && t.approval != TaskApproval.rejected)
        .toList();
    // Numbered in the shortest order through the stops.
    final numbers = planStopNumbers(tasks, clients);
    final located = inRouteOrder(tasks, numbers).where((t) => numbers.containsKey(t.id)).toList();
    final points = [for (final t in located) LatLng(clients[t.clientId]!.lat!, clients[t.clientId]!.lng!)];
    final missing = tasks.length - located.length;

    if (_map != null && !_fitted && points.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(points));
    }
    final day = DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(DateTime.parse(widget.date));

    return Scaffold(
      appBar: AppBar(title: Text(owner == null ? day : '${owner.name} · $day')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: defaultMapCenter, zoom: 11),
            // Keeps the Google logo and fitted markers clear of the legend card.
            padding: const EdgeInsets.only(top: 72),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) => setState(() => _map = controller),
            // The suggested order, as a thin line from stop to stop.
            polylines: {
              if (points.length > 1)
                Polyline(
                  polylineId: const PolylineId('order'),
                  points: points,
                  color: plannedColor.withValues(alpha: 0.6),
                  width: 3,
                  patterns: [PatternItem.dash(14), PatternItem.gap(8)],
                ),
            },
            markers: {
              for (final (i, t) in located.indexed)
                Marker(
                  markerId: MarkerId(t.id),
                  position: points[i],
                  anchor: const Offset(0.5, 0.5),
                  icon: _icons.circle(
                    context: context,
                    fill: _color(t),
                    text: '${i + 1}',
                    textColor: _color(t) == statusDueSoonColor ? Colors.black87 : Colors.white,
                    size: 34,
                  ),
                  onTap: () => _showItem(me, owner, t, clients[t.clientId]!, i + 1),
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
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          for (final (color, label) in [
                            (plannedColor, l10n.plannedToday),
                            (statusDueSoonColor, l10n.waitingApproval),
                            (statusRecentColor, l10n.done),
                          ])
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(label, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                        ],
                      ),
                      if (points.length > 2) ...[
                        const SizedBox(height: 4),
                        Text(l10n.shortestOrderHint, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (missing > 0) ...[
                        const SizedBox(height: 4),
                        Text(l10n.planClientsWithoutLocation(missing), style: Theme.of(context).textTheme.bodySmall),
                      ],
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

  void _showItem(AppUser? me, AppUser? owner, PlanTask t, Client c, int number) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(planRepositoryProvider);
    final canManage = me?.role.isSupervisor ?? false;
    Future<void> notify(NotificationType type) => me == null || owner == null
        ? Future.value()
        : sendNotifications(
            toIds: [owner.id],
            type: type,
            fromId: me.id,
            ownerId: owner.id,
            date: widget.date,
            count: 1,
          );

    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$number. ${c.name}', style: Theme.of(context).textTheme.titleMedium),
              if (c.city.isNotEmpty) Text(c.city),
              if (t.title.isNotEmpty) Text(t.title),
              Text(
                t.done
                    ? l10n.done
                    : t.approval == TaskApproval.pending
                    ? l10n.waitingApproval
                    : l10n.toDo,
              ),
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
                  if (canManage && t.approval == TaskApproval.pending)
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(sheet);
                        await repo.setApproval(t.id, TaskApproval.approved, me!.id);
                        await notify(NotificationType.planApproved);
                      },
                      child: Text(l10n.approve),
                    ),
                  if (canManage)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: () async {
                        Navigator.pop(sheet);
                        await repo.delete(t.id);
                        if (owner?.id != me?.id) await notify(NotificationType.planChanged);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.removeFromPlan),
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
