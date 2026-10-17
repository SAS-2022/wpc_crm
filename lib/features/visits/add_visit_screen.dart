import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/location.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../clients/client.dart';
import '../clients/client_locations_section.dart';
import '../clients/client_tags.dart';
import '../clients/clients_repository.dart';
import '../plan/checklist.dart';
import '../plan/plan_repository.dart';
import '../plan/plan_task.dart';
import 'app_calls.dart';
import 'visit.dart';
import 'visits_repository.dart';

/// Check in at a client: GPS position, notes and optional photos. Saving turns
/// the marker green. With [call], logs a phone call instead: no position, and
/// marked "from the app" with its length when it was dialled from the app.
class AddVisitScreen extends ConsumerStatefulWidget {
  const AddVisitScreen({super.key, required this.clientId, this.call = false});

  final String clientId;
  final bool call;

  @override
  ConsumerState<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends ConsumerState<AddVisitScreen> {
  final _notes = TextEditingController();
  final _files = <PendingFile>[];
  Position? _position;
  LocationProblem? _problem;
  bool _locating = true;
  bool _setClientLocation = true;
  bool _busy = false;

  /// Call mode: the call dialled from the app for this client, if any.
  AppCall? _appCall;

  /// Location chosen by the user; null = the one nearest to the phone.
  String? _locationId;

  @override
  void initState() {
    super.initState();
    if (widget.call) {
      _appCall = ref.read(appCallProvider.notifier).finishedFor(widget.clientId);
    } else {
      _locate();
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _problem = null;
    });
    try {
      final result = await currentPosition();
      if (!mounted) return;
      setState(() {
        _position = result.position;
        _problem = result.problem;
      });
    } catch (_) {
      if (mounted) setState(() => _problem = LocationProblem.serviceOff);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Where the visit is: the chosen location, else the one nearest to the
  /// phone, else the main one.
  ClientLocation? _location(Client client) =>
      client.locations.where((l) => l.id == _locationId).firstOrNull ??
      (_position == null ? null : nearestLocation(client, _position!.latitude, _position!.longitude)) ??
      client.locations.firstOrNull;

  double? _distance(Client client) {
    final at = _location(client);
    return _position == null || at == null
        ? null
        : Geolocator.distanceBetween(_position!.latitude, _position!.longitude, at.lat, at.lng);
  }

  Future<void> _save(Client client) async {
    final l10n = AppLocalizations.of(context);
    if (_notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.call ? l10n.callNotesRequired : l10n.visitNotesRequired)));
      return;
    }
    final distance = _distance(client);
    if (!widget.call && distance != null && distance > visitRadiusMeters) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(l10n.farFromClientWarning(formatDistance(distance))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.saveAnyway)),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final userId = ref.read(currentUserProvider).value!.id;
      final repo = ref.read(visitsRepositoryProvider);
      final String visitId;
      if (widget.call) {
        visitId = await repo.addCall(client: client, userId: userId, notes: _notes.text.trim(), appCall: _appCall);
        ref.read(appCallProvider.notifier).clear();
      } else {
        visitId = await repo.add(
          client: client,
          userId: userId,
          position: _position!,
          notes: _notes.text.trim(),
          setClientLocation: !client.hasLocation && _setClientLocation,
          location: _location(client),
        );
      }
      // The visit is saved; a failed photo shows an error but the visit stays.
      final attachments = ref.read(attachmentsRepositoryProvider);
      for (final f in _files) {
        try {
          await attachments.upload((parent: AttachmentParent.visits, id: visitId), f, userId);
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(widget.call ? l10n.callSaved : l10n.visitSaved)));
      if (mounted) context.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(allClientsProvider).value?.where((c) => c.id == widget.clientId).firstOrNull;
    if (client == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final distance = _distance(client);
    final error = Theme.of(context).colorScheme.error;
    final me = ref.watch(currentUserProvider).value;
    // Tasks for this client on today's plan: ticked here, saved at once.
    final planned = me == null
        ? const <PlanTask>[]
        : (ref.watch(dayTasksProvider((me.id, dayKey(DateTime.now())))).value ?? const <PlanTask>[])
            .where((t) => t.clientId == client.id && t.approval == TaskApproval.approved && t.checklist.isNotEmpty)
            .toList();

    final Widget locationStatus;
    if (widget.call) {
      final call = _appCall;
      locationStatus = call == null
          ? ListTile(leading: const Icon(Icons.call), title: Text(l10n.callLoggedByHand))
          : ListTile(
              leading: Icon(Icons.phone_forwarded, color: Colors.green.shade600),
              title: Text(l10n.callFromApp),
              subtitle: Text(l10n.callDuration(formatCallDuration(call.seconds))),
              // Not this call (e.g. the client called back later): log it by hand.
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.notThisCall,
                onPressed: () => setState(() => _appCall = null),
              ),
            );
    } else if (_locating) {
      locationStatus = ListTile(
        leading: const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text(l10n.gettingLocation),
      );
    } else if (_position == null) {
      locationStatus = ListTile(
        leading: Icon(Icons.location_off, color: error),
        title: Text(_problem == LocationProblem.denied ? l10n.locationPermissionDenied : l10n.locationUnavailable),
        trailing: TextButton(onPressed: _locate, child: Text(l10n.retry)),
      );
    } else {
      final far = distance != null && distance > visitRadiusMeters;
      final types = ref.watch(locationTypesByIdProvider);
      final lang = Localizations.localeOf(context).languageCode;
      final nearest = nearestLocation(client, _position!.latitude, _position!.longitude);
      locationStatus = Column(
        children: [
          // Several locations (factory, showroom, …): which one is this visit at.
          if (client.locations.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _location(client)?.id,
                decoration: InputDecoration(labelText: l10n.visitLocation),
                items: [
                  for (final (i, l) in client.locations.indexed)
                    DropdownMenuItem(
                      value: l.id,
                      child: Text([
                        locationLabel(l, i, types, lang, l10n),
                        if (l.id == nearest?.id) l10n.nearestLocation,
                      ].join(' · ')),
                    ),
                ],
                onChanged: (v) => setState(() => _locationId = v),
              ),
            ),
          ListTile(
            leading: Icon(Icons.my_location, color: far ? error : Colors.green.shade600),
            title: Text(distance == null
                ? l10n.locationAccuracy(_position!.accuracy.round())
                : l10n.distanceFromClient(formatDistance(distance))),
            subtitle: distance == null ? null : Text(l10n.locationAccuracy(_position!.accuracy.round())),
            trailing: IconButton(icon: const Icon(Icons.refresh), tooltip: l10n.retry, onPressed: _locate),
          ),
          if (_position!.isMocked)
            ListTile(
              leading: Icon(Icons.warning_amber, color: error),
              title: Text(l10n.mockedLocationWarning, style: TextStyle(color: error)),
            ),
          if (!client.hasLocation)
            CheckboxListTile(
              value: _setClientLocation,
              onChanged: (v) => setState(() => _setClientLocation = v ?? false),
              title: Text(l10n.setClientLocationHere),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.call ? l10n.logCall : l10n.addVisit)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(client.name, style: Theme.of(context).textTheme.titleLarge),
          if (client.city.isNotEmpty) Text(client.city),
          const SizedBox(height: 8),
          Card(child: locationStatus),
          const SizedBox(height: 16),
          if (planned.isNotEmpty) ...[
            Text(l10n.tasks, style: Theme.of(context).textTheme.titleMedium),
            for (final t in planned)
              PlanChecklist(
                task: t,
                canTick: true,
                canEdit: true,
                onChanged: (items) => ref.read(planRepositoryProvider).setChecklist(t.id, items),
              ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _notes,
            minLines: 5,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: widget.call ? l10n.callNotes : l10n.visitNotes,
              hintText: widget.call ? l10n.callNotesHint : l10n.visitNotesHint,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, f) in _files.indexed)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: f.contentType.startsWith('image/')
                          ? Image.memory(f.bytes, width: 72, height: 72, fit: BoxFit.cover, cacheWidth: 216)
                          : Container(
                              width: 72,
                              height: 72,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.insert_drive_file),
                            ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: InkWell(
                        onTap: _busy ? null : () => setState(() => _files.removeAt(i)),
                        child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)),
                      ),
                    ),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final picked = await pickAttachments(context);
                        if (mounted) setState(() => _files.addAll(picked));
                      },
                icon: const Icon(Icons.add_a_photo),
                label: Text(_files.isEmpty ? l10n.addAttachment : l10n.visitPhotos(_files.length)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy || (!widget.call && _position == null) ? null : () => _save(client),
            icon: const Icon(Icons.check),
            label: Text(widget.call ? l10n.saveCall : l10n.saveVisit),
          ),
        ],
      ),
    );
  }
}
