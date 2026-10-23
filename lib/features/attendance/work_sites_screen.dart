import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../clients/location_picker_screen.dart';
import '../users/users_repository.dart';
import 'work_sites.dart';

/// More → Work sites (sales manager / GM): places people check in at, with
/// the people who work there.
class WorkSitesScreen extends ConsumerWidget {
  const WorkSitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sites = ref.watch(workSitesProvider).value ?? const <WorkSite>[];
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    void open(WorkSite? site) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => WorkSiteEditor(site: site)));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.workSites)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => open(null),
        icon: const Icon(Icons.add_location_alt),
        label: Text(l10n.addWorkSite),
      ),
      body: sites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noWorkSites, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final s in sites)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Snapshot of the place and its check-in circle.
                        SiteSnapshot(point: LatLng(s.lat, s.lng), radius: s.radius),
                        ListTile(
                          leading: Icon(Icons.apartment, color: s.active ? null : Theme.of(context).disabledColor),
                          title: Text(s.name),
                          subtitle: Text(
                            [
                              l10n.peopleCount(users.where((u) => u.active && u.workSiteIds.contains(s.id)).length),
                              l10n.radiusMeters(s.radius.round()),
                              if (!s.active) l10n.inactive,
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => open(s),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Add / edit a work site: name, point on the map, radius, the people who
/// work there.
class WorkSiteEditor extends ConsumerStatefulWidget {
  const WorkSiteEditor({super.key, this.site});

  final WorkSite? site;

  @override
  ConsumerState<WorkSiteEditor> createState() => _WorkSiteEditorState();
}

class _WorkSiteEditorState extends ConsumerState<WorkSiteEditor> {
  late final _name = TextEditingController(text: widget.site?.name ?? '');
  late LatLng? _point = widget.site == null ? null : LatLng(widget.site!.lat, widget.site!.lng);
  late double _radius = widget.site?.radius ?? defaultSiteRadius;
  late bool _active = widget.site?.active ?? true;
  Set<String>? _people;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(List<AppUser> users) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_name.text.trim().isEmpty || _point == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.workSiteNeedsNameAndPlace)));
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await saveWorkSite(
        WorkSite(id: '', name: _name.text.trim(), lat: _point!.latitude, lng: _point!.longitude, radius: _radius, active: _active),
        id: widget.site?.id,
      );
      final before = {
        for (final u in users)
          if (u.workSiteIds.contains(id)) u.id,
      };
      final after = _people ?? before;
      await assignWorkSite(id, assign: after.difference(before).toList(), unassign: before.difference(after).toList());
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(List<AppUser> users) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final site = widget.site!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.deleteWorkSiteConfirm(site.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await assignWorkSite(
      site.id,
      assign: const [],
      unassign: [
        for (final u in users)
          if (u.workSiteIds.contains(site.id)) u.id,
      ],
    );
    await deleteWorkSite(site.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final users = [
      for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
        if (u.active) u,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final id = widget.site?.id;
    final people =
        _people ??
        {
          for (final u in users)
            if (id != null && u.workSiteIds.contains(id)) u.id,
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site == null ? l10n.addWorkSite : l10n.editWorkSite),
        actions: [
          if (widget.site != null)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: _busy ? null : () => _delete(users)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.name, hintText: l10n.workSiteNameHint),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.place, color: _point == null ? theme.colorScheme.error : theme.colorScheme.primary),
            title: Text(
              _point == null ? l10n.workSiteNoPlace : '${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
            ),
            trailing: OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: Text(l10n.pickOnMap),
              onPressed: () async {
                final picked = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _point)),
                );
                if (picked != null) setState(() => _point = picked);
              },
            ),
          ),
          if (_point != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SiteSnapshot(key: ValueKey(_point), point: _point!, radius: _radius),
            ),
            const SizedBox(height: 12),
          ],
          Text(l10n.radiusMeters(_radius.round()), style: theme.textTheme.labelLarge),
          Slider(
            value: _radius,
            min: 100,
            max: 500,
            divisions: 8,
            label: '${_radius.round()} m',
            onChanged: (v) => setState(() => _radius = v),
          ),
          Text(l10n.radiusHelp, style: theme.textTheme.bodySmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.active),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 8),
          Text(l10n.peopleAtSite(people.length), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Only people who need attendance (user form switch).
              for (final u in users)
                if (u.needsAttendance || people.contains(u.id))
                  FilterChip(
                    label: Text('${u.name} · ${u.role.label(l10n)}'),
                    selected: people.contains(u.id),
                    onSelected: (on) => setState(() => _people = on ? ({...people, u.id}) : ({...people}..remove(u.id))),
                  ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () => _save(users),
            child: BusyLabel(busy: _busy, child: Text(l10n.save)),
          ),
        ],
      ),
    );
  }
}

/// A small fixed map of a work site (2026-10-23): satellite view with the
/// pin and the check-in circle. No gestures; Android draws it as a still
/// image (lite mode). On the web the map would take the clicks, so it
/// ignores them and the row below opens the site.
class SiteSnapshot extends StatelessWidget {
  const SiteSnapshot({super.key, required this.point, required this.radius, this.height = 150});

  final LatLng point;
  final double radius;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: IgnorePointer(
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: point, zoom: radius <= 200 ? 16.5 : 15.5),
          mapType: MapType.hybrid,
          liteModeEnabled: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          markers: {Marker(markerId: const MarkerId('site'), position: point)},
          circles: {
            Circle(
              circleId: const CircleId('radius'),
              center: point,
              radius: radius,
              strokeWidth: 2,
              strokeColor: color,
              fillColor: color.withValues(alpha: 0.18),
            ),
          },
        ),
      ),
    );
  }
}
