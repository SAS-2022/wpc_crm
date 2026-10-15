import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/clients_repository.dart';
import '../users/users_repository.dart';
import 'import_plan.dart';
import 'import_service.dart';
import 'location_import.dart';
import 'odoo_parser.dart';

/// Sheet of client name (or Tax ID) + location → updates existing clients'
/// locations, and optionally adds the unmatched rows as new clients.
/// Sales manager / GM only.
class LocationImportScreen extends ConsumerStatefulWidget {
  const LocationImportScreen({super.key});

  @override
  ConsumerState<LocationImportScreen> createState() => _LocationImportScreenState();
}

class _LocationImportScreenState extends ConsumerState<LocationImportScreen> {
  String? _progress;
  String? _error;
  String _fileName = '';
  LocationPlan? _plan;
  bool _resolverUnavailable = false;
  bool _replaceExisting = false;
  bool _addNew = false;
  bool _committing = false;

  List<LocationUpdate> get _toApply =>
      _plan!.updates.where((u) => _replaceExisting || !u.replacesExisting).toList();

  List<NewLocationClient> get _toAdd => _addNew ? _plan!.newClients : const [];

  /// Odoo salesperson text → app user, through `users.odooName`.
  Map<String, String> get _uidBySalesperson => {
        for (final u in ref.read(usersProvider).value ?? const [])
          if (u.active && u.odooName.isNotEmpty) normalizeSalesperson(u.odooName): u.id,
      };

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    setState(() {
      _progress = l10n.importReading;
      _error = null;
      _plan = null;
      _addNew = false;
    });
    try {
      final rows = parseLocationTable(readTable(file.name, await file.readAsBytes()));
      final clients = await ref.read(allClientsProvider.future).timeout(const Duration(seconds: 60));

      final shortLinks = {
        for (final r in rows)
          if (r.coords == null && isShortLink(r.link)) r.link,
      }.toList();
      var resolved = (coords: <String, Coords>{}, available: true);
      if (shortLinks.isNotEmpty) {
        setState(() => _progress = l10n.importResolving(0, shortLinks.length));
        resolved = await resolveShortLinks(shortLinks, (done) {
          if (mounted) setState(() => _progress = l10n.importResolving(done, shortLinks.length));
        });
      }

      final plan = buildLocationPlan(rows: rows, clients: clients, resolvedLinks: resolved.coords);
      setState(() {
        _fileName = file.name;
        _plan = plan;
        _resolverUnavailable = !resolved.available;
        _progress = null;
      });
    } on LocationParseException {
      setState(() {
        _error = l10n.locationSheetColumns;
        _progress = null;
      });
    } catch (e) {
      setState(() {
        _error = l10n.errorWithMessage('$e');
        _progress = null;
      });
    }
  }

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context);
    final updates = _toApply;
    final adds = _toAdd;
    setState(() {
      _committing = true;
      _error = null;
    });
    try {
      final repo = ref.read(clientsRepositoryProvider);
      await repo.updateLocations(updates);
      if (adds.isNotEmpty) {
        await repo.createFromLocationSheet(
          adds,
          uidBySalesperson: _uidBySalesperson,
          fileName: _fileName,
          importedBy: ref.read(currentUserProvider).value!.id,
          defaultCategory: 'B',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(adds.isEmpty
            ? l10n.locationsUpdated(updates.length)
            : l10n.importApplyDone(adds.length, updates.length)),
      ));
      context.go('/clients');
    } catch (e) {
      setState(() => _error = l10n.errorWithMessage('$e'));
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the client list live while this screen is open (see ImportScreen).
    ref.watch(allClientsProvider);
    final users = ref.watch(usersProvider).value ?? const [];
    final l10n = AppLocalizations.of(context);
    final plan = _plan;
    final busy = _progress != null || _committing;
    String label(LocationRow r) => '#${r.rowNumber} ${r.name.isNotEmpty ? r.name : r.vat}';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importLocationsOnly)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l10n.locationSheetColumns),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _pick,
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.chooseFile),
          ),
          if (_progress != null) ...[
            const SizedBox(height: 24),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_progress!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (plan != null) ...[
            const SizedBox(height: 16),
            Text(_fileName, style: Theme.of(context).textTheme.titleMedium),
            if (_resolverUnavailable)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(l10n.shortLinksUnavailable),
                ),
              ),
            _Section(l10n.locationsToSet, [
              for (final u in plan.updates)
                if (!u.replacesExisting) '${u.client.name}  (${u.coords.lat.toStringAsFixed(5)}, ${u.coords.lng.toStringAsFixed(5)})',
            ]),
            _Section(l10n.locationsToReplace, [
              for (final u in plan.updates)
                if (u.replacesExisting) '${u.client.name}  (${u.coords.lat.toStringAsFixed(5)}, ${u.coords.lng.toStringAsFixed(5)})',
            ]),
            ListTile(title: Text(l10n.importUnchanged), trailing: Text('${plan.unchanged}')),
            _Section(l10n.clientNotFound, [for (final r in plan.notFound) label(r)]),
            _Section(l10n.sameNameSeveralClients, [for (final r in plan.ambiguous) label(r)]),
            _Section(l10n.locationUnreadable, [for (final r in plan.unreadable) '${label(r)} — ${r.link}']),
            if (plan.updates.any((u) => u.replacesExisting))
              CheckboxListTile(
                value: _replaceExisting,
                onChanged: (v) => setState(() => _replaceExisting = v ?? false),
                title: Text(l10n.replaceExistingLocations),
              ),
            if (plan.newClients.isNotEmpty)
              CheckboxListTile(
                value: _addNew,
                onChanged: (v) => setState(() => _addNew = v ?? false),
                title: Text(l10n.addUnmatchedClients(plan.newClients.length)),
                subtitle: Text(l10n.newClientsAssignedTo(
                  {
                    for (final r in plan.newClients)
                      users.where((u) => u.id == _uidBySalesperson[normalizeSalesperson(r.row.salesperson)]).firstOrNull?.name ??
                          l10n.unassigned,
                  }.join(', '),
                  plan.newClients.where((r) => r.coords == null).length,
                )),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy || (_toApply.isEmpty && _toAdd.isEmpty) ? null : _commit,
              child: _committing
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_toAdd.isEmpty
                      ? l10n.updateLocationsButton(_toApply.length)
                      : l10n.importApplyButton(_toAdd.length, _toApply.length)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.lines);

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title),
      trailing: Text('${lines.length}'),
      enabled: lines.isNotEmpty,
      children: [
        for (final line in lines.take(300)) ListTile(dense: true, title: Text(line)),
        if (lines.length > 300) ListTile(dense: true, title: Text('… +${lines.length - 300}')),
      ],
    );
  }
}
