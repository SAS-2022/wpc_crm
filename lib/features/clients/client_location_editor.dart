import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/location.dart';
import '../../core/text_input_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../import/import_service.dart';
import 'client.dart';
import 'client_tags.dart';
import 'location_picker_screen.dart';

/// Add or change one of a client's locations: its label (Office, Factory, …),
/// position (my location, pick on the map or a pasted Maps link) and, for
/// extra locations, an address. Pops the edited [ClientLocation].
class ClientLocationEditor extends ConsumerStatefulWidget {
  const ClientLocationEditor({super.key, required this.clientName, this.location});

  final String clientName;

  /// null = a new location.
  final ClientLocation? location;

  @override
  ConsumerState<ClientLocationEditor> createState() => _ClientLocationEditorState();
}

class _ClientLocationEditorState extends ConsumerState<ClientLocationEditor> {
  final _form = GlobalKey<FormState>();
  late final _lat = TextEditingController(text: widget.location?.lat.toStringAsFixed(6) ?? '');
  late final _lng = TextEditingController(text: widget.location?.lng.toStringAsFixed(6) ?? '');
  late final _address = TextEditingController(text: widget.location?.address ?? '');
  late String _typeId = widget.location?.typeId ?? '';
  bool _locating = false;

  bool get _isMain => widget.location?.isMain ?? false;

  @override
  void dispose() {
    for (final c in [_lat, _lng, _address]) {
      c.dispose();
    }
    super.dispose();
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
        messenger.showSnackBar(SnackBar(
          content: Text(
            result.problem == LocationProblem.denied ? l10n.locationPermissionDenied : l10n.locationUnavailable,
          ),
        ));
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
        builder: (_) => LocationPickerScreen(initial: lat != null && lng != null ? LatLng(lat, lng) : null),
      ),
    );
    if (picked != null) _setCoords(picked.latitude, picked.longitude);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      ClientLocation(
        id: widget.location?.id ?? 'l${DateTime.now().millisecondsSinceEpoch}',
        typeId: _typeId,
        lat: double.parse(_lat.text.trim()),
        lng: double.parse(_lng.text.trim()),
        address: _isMain ? '' : _address.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final types = ref.watch(tagListProvider(TagList.locationTypes)).value ?? defaultLocationTypes;
    String? coordinate(String? v, double max) {
      final n = double.tryParse(v?.trim() ?? '');
      return n == null || n.abs() > max ? l10n.required : null;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.location == null ? l10n.addLocation : l10n.editLocation)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.clientName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: types.any((t) => t.id == _typeId) ? _typeId : '',
              decoration: InputDecoration(labelText: l10n.locationType),
              items: [
                DropdownMenuItem(value: '', child: Text(l10n.noLocationType)),
                for (final t in types) DropdownMenuItem(value: t.id, child: Text(t.label(lang))),
              ],
              onChanged: (v) => setState(() => _typeId = v ?? ''),
            ),
            if (!_isMain) ...[
              const SizedBox(height: 12),
              TextFormField(controller: _address, decoration: InputDecoration(labelText: l10n.address)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(labelText: l10n.latitude),
                  validator: (v) => coordinate(v, 90),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(labelText: l10n.longitude),
                  validator: (v) => coordinate(v, 180),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
            ]),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _locating ? null : _pasteLink,
              icon: const Icon(Icons.link),
              label: Text(l10n.pasteMapsLink),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
