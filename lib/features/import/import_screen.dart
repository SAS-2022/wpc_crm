import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/clients_repository.dart';
import '../clients/visit_rules.dart';
import '../users/users_repository.dart';
import 'import_plan.dart';
import 'import_service.dart';
import 'odoo_parser.dart';

/// Odoo export → preview of changes → commit. Sales manager / GM only.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  String _defaultCategory = defaultCategory;
  String? _progress;
  String? _error;
  String _fileName = '';
  ImportPlan? _plan;
  List<String> _unknownSalespeople = const [];
  bool _resolverUnavailable = false;
  bool _committing = false;

  /// Only fill empty contact person / client type / company ID of existing clients.
  bool _fillOnly = false;

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'csv']);
    if (files.isEmpty) return;
    final file = files.first;
    setState(() {
      _progress = l10n.importReading;
      _error = null;
      _plan = null;
    });
    try {
      final rows = parseOdooTable(readTable(file.name, await file.readAsBytes()));
      final existing = await ref.read(allClientsProvider.future).timeout(const Duration(seconds: 60));
      final users = await ref.read(usersProvider.future).timeout(const Duration(seconds: 60));
      final salespersonToUid = uidBySalesperson(users);

      // Short links already turned into a location don't need the server again.
      final knownPins = {
        for (final c in existing)
          if (c.hasLocation) c.googlePin,
      };
      final shortLinks = _fillOnly
          ? const <String>[]
          : {
              for (final r in rows)
                if (isShortLink(r.pinUrl) && !knownPins.contains(r.pinUrl)) r.pinUrl,
            }.toList();
      var resolved = (coords: <String, Coords>{}, available: true);
      if (shortLinks.isNotEmpty) {
        setState(() => _progress = l10n.importResolving(0, shortLinks.length));
        resolved = await resolveShortLinks(shortLinks, (done) {
          if (mounted) setState(() => _progress = l10n.importResolving(done, shortLinks.length));
        });
      }

      final plan = buildPlan(
        rows: rows,
        existing: existing,
        resolvedPins: resolved.coords,
        salespersonToUid: salespersonToUid,
        fillOnly: _fillOnly,
      );
      setState(() {
        _fileName = file.name;
        _plan = plan;
        _resolverUnavailable = !resolved.available;
        _unknownSalespeople = {
          for (final r in rows)
            if (r.salesperson.isNotEmpty && !salespersonToUid.containsKey(normalizeSalesperson(r.salesperson)))
              r.salesperson,
        }.toList()..sort();
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
    final plan = _plan!;
    setState(() {
      _committing = true;
      _error = null;
    });
    try {
      await ref
          .read(clientsRepositoryProvider)
          .commitImport(
            plan,
            fileName: _fileName,
            importedBy: ref.read(currentUserProvider).value!.id,
            defaultCategory: _defaultCategory,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importDone(plan.creates.length, plan.updates.length))));
      context.go('/clients');
    } catch (e) {
      setState(() => _error = l10n.errorWithMessage('$e'));
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the lists live while this screen is open; unwatched providers are
    // paused, which would leave the import waiting forever.
    ref.watch(allClientsProvider);
    ref.watch(usersProvider);
    final l10n = AppLocalizations.of(context);
    final plan = _plan;
    final busy = _progress != null || _committing;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importClients)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.importFillOnly),
            subtitle: Text(l10n.importFillOnlyHint),
            value: _fillOnly,
            onChanged: busy
                ? null
                : (v) => setState(() {
                    _fillOnly = v;
                    // The preview was built for the other mode.
                    _plan = null;
                  }),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _pick,
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.importPickFile),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => context.push('/import/locations'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(l10n.importLocationsOnly),
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
                child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.importResolverUnavailable)),
              ),
            if (_fillOnly) ...[
              // Fill mode: how many clients get each field; nothing else is written.
              for (final (key, label) in [
                ('contactPerson', l10n.contactPerson),
                ('clientType', l10n.clientType),
                ('companyId', l10n.companyId),
              ])
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text(label),
                  trailing: Text('${plan.updates.where((w) => w.data.containsKey(key)).length}'),
                ),
              _Section(l10n.importUpdated, [
                // Few fields: show the values themselves.
                for (final w in plan.updates) '${w.name}  (${w.data.values.join(' · ')})',
              ]),
              ListTile(title: Text(l10n.importUnchanged), trailing: Text('${plan.unchanged}')),
            ] else ...[
              _Section(l10n.importNew, [for (final w in plan.creates) w.name]),
              _Section(l10n.importUpdated, [
                for (final w in plan.updates) '${w.name}  (${w.data.keys.join(', ')})',
              ]),
              ListTile(title: Text(l10n.importUnchanged), trailing: Text('${plan.unchanged}')),
              _Section(l10n.importDuplicates, [
                for (final g in plan.mergedDuplicates) '${g.first.vat}: ${g.map((r) => r.name).join(' | ')}',
              ]),
              _Section(l10n.importUnresolved, [
                for (final r in plan.newWithUnreadablePin) '#${r.rowNumber} ${r.name} — ${r.pinUrl}',
              ]),
              _Section(l10n.importNoLocation, [for (final r in plan.newWithoutPin) '#${r.rowNumber} ${r.name}']),
              _Section(l10n.importLinkedContacts, [for (final r in plan.linkedContacts) '#${r.rowNumber} ${r.name}']),
              _Section(l10n.importUnknownSalespeople, _unknownSalespeople),
            ],
            if (!_fillOnly) ...[
              const SizedBox(height: 16),
              Text(l10n.importDefaultCategory, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [for (final c in clientCategories) ButtonSegment(value: c, label: Text(c))],
                selected: {_defaultCategory},
                onSelectionChanged: (s) => setState(() => _defaultCategory = s.first),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy || (plan.creates.isEmpty && plan.updates.isEmpty) ? null : _commit,
              child: _committing
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.importConfirm),
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
