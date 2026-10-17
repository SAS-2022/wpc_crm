import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_user.dart';
import '../../core/location.dart';
import '../../core/providers.dart';
import '../../core/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../import/import_service.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'client_locations_section.dart';
import 'client_tags.dart';
import 'clients_repository.dart';
import 'location_picker_screen.dart';
import 'transfer.dart';
import 'visit_rules.dart';

/// Add (clientId == null) or edit a client. Sales execs edit contact details,
/// location and notes of their own clients and add new clients for
/// themselves; KAM / managers also set category and assignment.
class ClientEditScreen extends ConsumerStatefulWidget {
  const ClientEditScreen({super.key, required this.clientId});

  final String? clientId;

  @override
  ConsumerState<ClientEditScreen> createState() => _ClientEditScreenState();
}

class _ClientEditScreenState extends ConsumerState<ClientEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _contactPerson = TextEditingController();
  final _email = TextEditingController();
  final _vat = TextEditingController();
  final _companyId = TextEditingController();

  /// [clientTypeCompany], [clientTypeIndividual] or '' (not set).
  String _clientType = '';

  /// Label of the main location (`mainLocationType`).
  String _mainType = '';
  final _notes = TextEditingController();
  String? _assignedTo;

  /// The client as loaded (null when adding); a changed assignment is saved
  /// as a transfer of it.
  Client? _original;
  String _category = defaultCategory;
  Set<String> _tagIds = {};
  bool _loaded = false;
  bool _busy = false;
  bool _locating = false;

  List<TextEditingController> get _controllers => [
    _name,
    _phone,
    _mobile,
    _address,
    _city,
    _lat,
    _lng,
    _contactPerson,
    _email,
    _vat,
    _companyId,
    _notes,
  ];

  bool get _isNew => widget.clientId == null;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Client c) {
    _name.text = c.name;
    _phone.text = c.phone;
    _mobile.text = c.mobile;
    _address.text = c.address;
    _city.text = c.city;
    _lat.text = c.lat?.toString() ?? '';
    _lng.text = c.lng?.toString() ?? '';
    _category = c.category;
    _tagIds = {...c.tagIds};
    _assignedTo = c.assignedTo;
    _original = c;
    _contactPerson.text = c.contactPerson;
    _email.text = c.email;
    _vat.text = c.vat;
    _companyId.text = c.companyId;
    _clientType = c.clientType;
    _mainType = c.mainLocationType;
    _notes.text = c.notes;
    _loaded = true;
  }

  void _setCoords(double lat, double lng) => setState(() {
    _lat.text = lat.toStringAsFixed(6);
    _lng.text = lng.toStringAsFixed(6);
  });

  Future<void> _useMyLocation() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    try {
      final result = await currentPosition();
      final p = result.position;
      if (p != null) {
        _setCoords(p.latitude, p.longitude);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.problem == LocationProblem.denied
                  ? l10n.locationPermissionDenied
                  : l10n.locationUnavailable,
            ),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.locationUnavailable)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pasteLink() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = await showTextInputDialog(
      context,
      title: l10n.pasteMapsLink,
      hint: l10n.pasteMapsLinkHint,
      confirmLabel: l10n.useThisLocation,
    );
    if (text == null || text.trim().isEmpty) return;
    setState(() => _locating = true);
    try {
      final coords = await coordsFromPastedText(text);
      if (coords == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.linkUnreadable)));
      } else {
        _setCoords(coords.lat, coords.lng);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: lat != null && lng != null ? LatLng(lat, lng) : null,
        ),
      ),
    );
    if (picked != null) _setCoords(picked.latitude, picked.longitude);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final me = ref.read(currentUserProvider).value!;
    final manage = me.role.isSupervisor;
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'contactPerson': _contactPerson.text.trim(),
      'phone': _phone.text.trim(),
      'mobile': _mobile.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(),
      'city': _city.text.trim(),
      'lat': double.tryParse(_lat.text.trim()),
      'lng': double.tryParse(_lng.text.trim()),
      'mainLocationType': _mainType,
      'notes': _notes.text.trim(),
      if (manage || _isNew) 'vat': _vat.text.replaceAll(RegExp(r'\s'), ''),
      if (manage || _isNew) 'companyId': _companyId.text.replaceAll(RegExp(r'\s'), ''),
      if (manage || _isNew) 'clientType': _clientType,
      if (manage || _isNew) 'category': _category,
      if (manage) 'tagIds': _tagIds.toList(),
      // A sales exec's new client is theirs. A changed assignment of an
      // existing client is saved as a transfer below.
      if (_isNew) 'assignedTo': manage ? _assignedTo : me.id,
    };
    // Main coordinates cleared while extra locations exist: the first extra
    // one becomes the main location instead of all of them disappearing.
    final existing = ref.read(allClientsProvider).value?.where((c) => c.id == widget.clientId).firstOrNull;
    if (data['lat'] == null && existing != null && existing.extraLocations.isNotEmpty) {
      data.addAll(locationsUpdate(existing.extraLocations));
    }

    if (_isNew) {
      final clients = ref.read(allClientsProvider).value ?? const <Client>[];
      final key = Client.normalizeName(data['name'] as String);
      final vat = data['vat'] as String;
      final duplicate = clients
          .where(
            (c) =>
                c.nameKey == key ||
                c.aliases.any((a) => Client.normalizeName(a) == key) ||
                (vat.isNotEmpty && c.vat == vat),
          )
          .firstOrNull;
      if (duplicate != null) {
        final go = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(l10n.possibleDuplicate),
            content: Text(l10n.possibleDuplicateBody(duplicate.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(l10n.addAnyway),
              ),
            ],
          ),
        );
        if (go != true) return;
      }
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(clientsRepositoryProvider);
      if (_isNew) {
        final id = await repo.create(data, createdBy: me.id);
        messenger.showSnackBar(SnackBar(content: Text(l10n.clientAdded)));
        if (mounted) context.pushReplacement('/clients/$id');
      } else {
        await repo.update(widget.clientId!, data);
        final original = _original;
        if (manage && original != null && _assignedTo != original.assignedTo) {
          await repo.transfer([original], toId: _assignedTo, by: me);
        }
        messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
        if (mounted) context.pop();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorWithMessage('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final manage =
        ref.watch(currentUserProvider).value?.role.isSupervisor ?? false;
    final locationTypes = ref.watch(tagListProvider(TagList.locationTypes)).value ?? defaultLocationTypes;
    if (!_loaded && !_isNew) {
      final client = ref
          .watch(allClientsProvider)
          .value
          ?.where((c) => c.id == widget.clientId)
          .firstOrNull;
      if (client == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      _fill(client);
    }
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final owner = _original?.assignedTo;
    // A KAM assigns only within their team; when the client belongs to
    // someone else the assignment can't be changed here.
    final canAssign = me != null && (_isNew || canTransferFrom(me, owner, {for (final u in users) u.id: u}));
    final targets = me == null ? const <AppUser>[] : transferTargets(me, users);
    final execs = [...targets, ...users.where((u) => u.id == owner && !targets.contains(u))];
    final offerUnassigned = _isNew || owner == null || (me != null && canUnassign(me));

    String? coordinate(String? v, double max) {
      if (v == null || v.trim().isEmpty) return null;
      final n = double.tryParse(v.trim());
      return n == null || n.abs() > max ? l10n.invalidNumber : null;
    }

    Widget field(
      TextEditingController c,
      String label, {
      String? Function(String?)? validator,
      TextInputType? type,
      int maxLines = 1,
    }) => TextFormField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      minLines: 1,
      textCapitalization: type == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? l10n.addClient : l10n.editClient)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            field(
              _name,
              l10n.clientName,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            if (manage || _isNew) ...[
              DropdownButtonFormField<String>(
                initialValue: _clientType,
                decoration: InputDecoration(labelText: l10n.clientType),
                items: [
                  DropdownMenuItem(value: '', child: Text(l10n.notSet)),
                  DropdownMenuItem(value: clientTypeCompany, child: Text(l10n.clientTypeCompany)),
                  DropdownMenuItem(value: clientTypeIndividual, child: Text(l10n.clientTypeIndividual)),
                ],
                onChanged: (v) => setState(() => _clientType = v ?? ''),
              ),
              field(_vat, l10n.vat, type: TextInputType.number),
              field(_companyId, l10n.companyId, type: TextInputType.number),
            ],
            section(l10n.contact),
            field(_contactPerson, l10n.contactPerson),
            field(_phone, l10n.phone, type: TextInputType.phone),
            field(_mobile, l10n.mobile, type: TextInputType.phone),
            field(
              _email,
              l10n.email,
              type: TextInputType.emailAddress,
              validator: (v) => v == null || v.trim().isEmpty || v.contains('@')
                  ? null
                  : l10n.invalidEmail,
            ),
            section(l10n.locationSection),
            field(_address, l10n.address),
            field(_city, l10n.city),
            // Label of the main location; more locations are added on the client page.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: locationTypes.any((t) => t.id == _mainType) ? _mainType : '',
                decoration: InputDecoration(
                  labelText: l10n.mainLocationType,
                  helperText: l10n.moreLocationsOnClientPage,
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text(l10n.noLocationType)),
                  for (final t in locationTypes)
                    DropdownMenuItem(value: t.id, child: Text(t.label(Localizations.localeOf(context).languageCode))),
                ],
                onChanged: (v) => setState(() => _mainType = v ?? ''),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: field(
                    _lat,
                    l10n.latitude,
                    type: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => coordinate(v, 90),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: field(
                    _lng,
                    l10n.longitude,
                    type: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) => coordinate(v, 180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(l10n.useMyLocation),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(l10n.pickOnMap),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _locating ? null : _pasteLink,
              icon: const Icon(Icons.link),
              label: Text(l10n.pasteMapsLink),
            ),
            // More locations (factory, showroom, …), saved right away.
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(l10n.otherLocations, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (_isNew)
              ListTile(dense: true, leading: const Icon(Icons.info_outline), title: Text(l10n.saveClientFirstForLocations))
            else if (ref.watch(allClientsProvider).value?.where((c) => c.id == widget.clientId).firstOrNull
                case final client?)
              ClientLocationsList(client: client, canEdit: true, extrasOnly: true),
            section(l10n.notes),
            field(_notes, l10n.notes, maxLines: 5),
            if (manage) ...[
              section(l10n.salesSection),
              Text(
                l10n.category,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  for (final c in clientCategories)
                    ButtonSegment(value: c, label: Text(c)),
                ],
                selected: {_category},
                onSelectionChanged: (s) => setState(() => _category = s.first),
              ),
              Builder(
                builder: (context) {
                  final rule =
                      (ref.watch(visitRulesProvider).value ??
                              VisitRules.defaults)
                          .of(_category);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.categoryRule(
                        _category,
                        rule.greenDays,
                        rule.yellowDays,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(l10n.clientTags, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in ref.watch(clientTagsProvider).value ?? defaultClientTags)
                    FilterChip(
                      label: Text(t.label(Localizations.localeOf(context).languageCode)),
                      selected: _tagIds.contains(t.id),
                      onSelected: (on) => setState(() => on ? _tagIds.add(t.id) : _tagIds.remove(t.id)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: execs.any((u) => u.id == _assignedTo)
                    ? _assignedTo
                    : null,
                decoration: InputDecoration(labelText: l10n.salesExecutive),
                items: [
                  if (offerUnassigned) DropdownMenuItem(value: null, child: Text(l10n.unassigned)),
                  for (final u in execs)
                    DropdownMenuItem(value: u.id, child: Text(u.name)),
                ],
                onChanged: canAssign ? (v) => setState(() => _assignedTo = v) : null,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
