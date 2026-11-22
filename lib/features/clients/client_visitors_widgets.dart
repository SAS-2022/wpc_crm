import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/city_areas.dart';
import '../../core/providers.dart';
import '../../core/saudi_cities.dart';
import '../../l10n/app_localizations.dart';
import '../plan/add_task_sheet.dart' show addClientToTodayPlan;
import '../users/people_filter.dart' show territoryRegionsProvider;
import '../users/users_repository.dart';
import 'client.dart';
import 'client_locations_section.dart' show locationLabel;
import 'client_tags.dart';
import 'client_visitors.dart';
import 'transfer.dart' show transferTargets;
import 'clients_repository.dart';
import 'person_style.dart';

/// "Showroom · Olaya Street · Riyadh": a location's label, its address and
/// the nearest city, so several showrooms can be told apart.
String locationPlaceLabel(Client c, ClientLocation l, Map<String, ClientTag> types, String lang, AppLocalizations l10n) {
  final index = c.allLocations.indexWhere((x) => x.id == l.id);
  final city = nearestSaudiCity(l.lat, l.lng)?.label(lang);
  final address = l.address.trim();
  return [
    locationLabel(l, index < 0 ? 0 : index, types, lang, l10n),
    if (address.isNotEmpty) address,
    if (city != null && !address.contains(city)) city,
  ].join(' · ');
}

/// Client page section "Also visited by" (2026-11-21, user): the people asked
/// to visit some of the client's locations though it isn't theirs. KAM /
/// sales manager / GM add, change and remove them and put the visit on their
/// plan for today; the visitor sees a note that they visit it for the owner.
/// Hidden when there is nothing to show.
class ClientVisitorsSection extends ConsumerWidget {
  const ClientVisitorsSection({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final byId = {for (final u in users) u.id: u};
    final types = ref.watch(locationTypesByIdProvider);
    final linked = linkedGroupOf(client, ref.watch(clientsProvider).value ?? const <Client>[]);
    final canEdit = canAssignVisitors(me, client, byId) && (client.hasLocation || linked.isNotEmpty);
    final owner = byId[client.assignedTo]?.name ?? l10n.unassigned;

    String placesOf(VisitAssignment a) {
      final locs = locationsFor(client, a.uid);
      if (a.locationIds.isEmpty) return l10n.allLocations;
      if (locs.isEmpty) return l10n.visitorLocationsGone;
      return locs.map((l) => locationPlaceLabel(client, l, types, lang, l10n)).join('\n');
    }

    // The visitor: whose client it is and where they go.
    if (isVisitorOf(client, me.id)) {
      final a = assignmentOf(client, me.id)!;
      return ListTile(
        leading: Icon(Icons.add_location_alt_outlined, color: theme.colorScheme.primary),
        title: Text(l10n.visitingForOwner(owner)),
        subtitle: Text(placesOf(a)),
      );
    }
    if (client.visitAssignments.isEmpty && !canEdit) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in client.visitAssignments)
          ListTile(
            leading: PersonBadge(userId: a.uid, name: byId[a.uid]?.name ?? '?'),
            title: Text(byId[a.uid]?.name ?? l10n.deletedUser),
            subtitle: Text(placesOf(a)),
            trailing: !canEdit
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (byId[a.uid] case final u? when u.active)
                      _PlanTodayButton(client: client, visitor: u, me: me),
                    IconButton(
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, ref, me, users, linked, a),
                    ),
                    IconButton(
                      tooltip: l10n.remove,
                      icon: const Icon(Icons.close),
                      onPressed: () => ref.read(clientsRepositoryProvider).setVisitAssignments(
                            client,
                            [for (final x in client.visitAssignments) if (x.uid != a.uid) x],
                            byId: me.id,
                          ),
                    ),
                  ]),
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => _edit(context, ref, me, users, linked, null),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l10n.addVisitor),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AppUser me,
    List<AppUser> users,
    List<Client> linked,
    VisitAssignment? current,
  ) async {
    final result = await showDialog<_VisitorChoice>(
      context: context,
      builder: (_) => _VisitorDialog(client: client, linked: linked, me: me, users: users, current: current),
    );
    if (result == null) return;
    final repo = ref.read(clientsRepositoryProvider);
    // This client: given the ticked locations, or taken off when none.
    final here = withVisitor(client, result.uid, result.locationIds, byId: me.id);
    if (current != null && current.uid != result.uid) here.removeWhere((a) => a.uid == current.uid);
    await repo.setVisitAssignments(client, here, byId: me.id);
    // Linked companies / showrooms ticked: every location (a location list
    // set on that client's own page is kept); unticked ones taken off.
    for (final c in linked) {
      final had = assignmentOf(c, result.uid);
      final want = result.linkedIds.contains(c.id);
      if (want == (had != null)) continue;
      await repo.setVisitAssignments(c, withVisitor(c, result.uid, want ? const [] : null, byId: me.id), byId: me.id);
    }
  }
}

/// What the dialog picked: the person, this client's locations (null = not
/// this client; empty = all) and the linked clients they visit too.
typedef _VisitorChoice = ({String uid, List<String>? locationIds, Set<String> linkedIds});

/// Puts the client on the visitor's plan for today, at one of their
/// locations (a menu when they have several).
class _PlanTodayButton extends ConsumerWidget {
  const _PlanTodayButton({required this.client, required this.visitor, required this.me});

  final Client client;
  final AppUser visitor;
  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final types = ref.watch(locationTypesByIdProvider);
    final locs = locationsFor(client, visitor.id);
    Future<void> plan(ClientLocation? l) async {
      final messenger = ScaffoldMessenger.of(context);
      await addClientToTodayPlan(ref, me, client, owner: visitor, locationId: l?.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.addedToPlanOf(visitor.name))));
    }

    if (locs.length <= 1) {
      return IconButton(
        tooltip: l10n.addToPlanOfToday(visitor.name),
        icon: const Icon(Icons.playlist_add),
        onPressed: () => plan(locs.firstOrNull),
      );
    }
    return PopupMenuButton<ClientLocation>(
      tooltip: l10n.addToPlanOfToday(visitor.name),
      icon: const Icon(Icons.playlist_add),
      onSelected: plan,
      itemBuilder: (_) => [
        for (final l in locs) PopupMenuItem(value: l, child: Text(locationPlaceLabel(client, l, types, lang, l10n))),
      ],
    );
  }
}

/// Pick the person and the locations they visit. New: locations in the
/// person's usual region (where most of their clients are) start ticked.
class _VisitorDialog extends ConsumerStatefulWidget {
  const _VisitorDialog({required this.client, required this.linked, required this.me, required this.users, this.current});

  final Client client;
  final List<Client> linked;
  final AppUser me;
  final List<AppUser> users;
  final VisitAssignment? current;

  @override
  ConsumerState<_VisitorDialog> createState() => _VisitorDialogState();
}

class _VisitorDialogState extends ConsumerState<_VisitorDialog> {
  String? _uid;
  bool _all = false;
  final _ticked = <String>{};
  final _linked = <String>{};

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    if (c != null) {
      _uid = c.uid;
      _all = c.locationIds.isEmpty;
      _ticked.addAll(c.locationIds);
      _linked.addAll([for (final l in widget.linked) if (assignmentOf(l, c.uid) != null) l.id]);
    }
  }

  void _pick(String? uid, Map<String, SaudiRegion> regions) {
    setState(() {
      _uid = uid;
      if (widget.current != null) return;
      final region = uid == null ? null : regions[uid];
      bool near(Client c) => region != null && c.allLocations.any((l) => region.contains(l.lat, l.lng));
      _ticked
        ..clear()
        ..addAll([
          for (final l in widget.client.allLocations)
            if (region != null && region.contains(l.lat, l.lng)) l.id,
        ]);
      // Linked companies / showrooms in their region, or they already visit.
      _linked
        ..clear()
        ..addAll([
          for (final c in widget.linked)
            if (near(c) || (uid != null && assignmentOf(c, uid) != null)) c.id,
        ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final types = ref.watch(locationTypesByIdProvider);
    final regions = ref.watch(territoryRegionsProvider);
    final taken = {for (final a in widget.client.visitAssignments) if (a.uid != widget.current?.uid) a.uid};
    final people = [
      for (final u in visitorCandidates(widget.me, widget.client, widget.users))
        if (!taken.contains(u.id)) u,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final locations = widget.client.allLocations;
    final here = locations.isNotEmpty && (_all || _ticked.isNotEmpty);
    // A linked client the person owns needs no visit request.
    final linked = [for (final c in widget.linked) if (c.assignedTo != _uid && c.hasLocation) c];
    final valid = _uid != null && (here || _linked.any((id) => linked.any((c) => c.id == id)) || widget.current != null);
    return AlertDialog(
      title: Text(l10n.addVisitor),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _uid,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.salesExecutive),
                items: [
                  for (final u in people)
                    DropdownMenuItem(
                      value: u.id,
                      child: Text(
                        [u.name, if (regions[u.id] case final r?) r.label(l10n)].join(' · '),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: widget.current != null ? null : (v) => _pick(v, regions),
              ),
              const SizedBox(height: 8),
              Text(l10n.visitorHelp, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (locations.isNotEmpty) Text(widget.client.name, style: Theme.of(context).textTheme.titleSmall),
              if (locations.isNotEmpty) SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.allLocations),
                value: _all,
                onChanged: (v) => setState(() => _all = v),
              ),
              if (!_all)
                for (final l in locations)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _ticked.contains(l.id),
                    title: Text(locationPlaceLabel(widget.client, l, types, lang, l10n)),
                    onChanged: (v) => setState(() => v == true ? _ticked.add(l.id) : _ticked.remove(l.id)),
                  ),
              // The main company / branches (showrooms) linked with it.
              if (linked.isNotEmpty) ...[
                const Divider(),
                Text(l10n.visitorLinkedClients, style: Theme.of(context).textTheme.titleSmall),
                for (final c in linked)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _linked.contains(c.id),
                    title: Text(c.name),
                    subtitle: Text([
                      if (c.allLocations.isNotEmpty) locationPlaceLabel(c, c.allLocations.first, types, lang, l10n),
                      if (c.allLocations.length > 1) l10n.locationsCount(c.allLocations.length),
                      widget.users.where((u) => u.id == c.assignedTo).firstOrNull?.name ?? l10n.unassigned,
                    ].join(' · ')),
                    onChanged: (v) => setState(() => v == true ? _linked.add(c.id) : _linked.remove(c.id)),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: !valid
              ? null
              : () => Navigator.pop<_VisitorChoice>(context, (
                    uid: _uid!,
                    locationIds: !here
                        ? null
                        : _all
                            ? const <String>[]
                            : [for (final l in locations) if (_ticked.contains(l.id)) l.id],
                    linkedIds: {for (final c in linked) if (_linked.contains(c.id)) c.id},
                  )),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Map select mode (2026-11-21, user): give the picked location pins of one
/// or more clients to a salesperson to visit. Their existing locations on
/// each client are kept and the picked ones added; clients the person owns,
/// or that [me] may not assign, are skipped. True when saved.
Future<bool> askToVisitLocations(BuildContext context, WidgetRef ref, AppUser me, Map<Client, Set<String>> picked) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final users = ref.read(usersProvider).value ?? const <AppUser>[];
  final byId = {for (final u in users) u.id: u};
  final allowed = {
    for (final e in picked.entries)
      if (canAssignVisitors(me, e.key, byId)) e.key: e.value,
  };
  if (allowed.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.askToVisitNotAllowed)));
    return false;
  }
  final people = [...transferTargets(me, users)]..sort((a, b) => a.name.compareTo(b.name));
  final regions = ref.read(territoryRegionsProvider);
  final locationCount = allowed.values.fold(0, (n, s) => n + s.length);
  final uid = await showDialog<String>(
    context: context,
    builder: (dialog) {
      String? chosen;
      return StatefulBuilder(
        builder: (context, setState) {
          final owned = chosen == null ? 0 : allowed.keys.where((c) => c.assignedTo == chosen).length;
          return AlertDialog(
            title: Text(l10n.askToVisit),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.askToVisitSummary(allowed.length, locationCount)),
                  if (allowed.length < picked.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l10n.askToVisitSkipped(picked.length - allowed.length),
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: chosen,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.salesExecutive),
                    items: [
                      for (final u in people)
                        DropdownMenuItem(
                          value: u.id,
                          child: Text([u.name, if (regions[u.id] case final r?) r.label(l10n)].join(' · '),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => chosen = v),
                  ),
                  if (owned > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l10n.askToVisitOwnSkipped(owned), style: Theme.of(context).textTheme.bodySmall),
                    ),
                  const SizedBox(height: 8),
                  Text(l10n.visitorHelp, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: chosen == null ? null : () => Navigator.pop(dialog, chosen),
                child: Text(l10n.save),
              ),
            ],
          );
        },
      );
    },
  );
  if (uid == null) return false;
  final repo = ref.read(clientsRepositoryProvider);
  var saved = 0;
  for (final e in allowed.entries) {
    final c = e.key;
    if (c.assignedTo == uid) continue;
    final had = assignmentOf(c, uid);
    // Already every location: stays so; else their old ones + the picked ones.
    final ids = had != null && had.locationIds.isEmpty
        ? const <String>[]
        : [
            for (final l in c.allLocations)
              if (e.value.contains(l.id) || (had?.locationIds.contains(l.id) ?? false)) l.id,
          ];
    await repo.setVisitAssignments(c, withVisitor(c, uid, ids, byId: me.id), byId: me.id);
    saved++;
  }
  messenger.showSnackBar(SnackBar(content: Text(l10n.askToVisitDone(byId[uid]?.name ?? '', saved))));
  return true;
}
