import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';
import 'client_location_editor.dart';
import 'client_tags.dart';
import 'clients_repository.dart';

/// "Factory", or "Location 2" when unlabelled.
String locationLabel(ClientLocation l, int index, Map<String, ClientTag> types, String lang, AppLocalizations l10n) =>
    types[l.typeId]?.label(lang) ?? l10n.locationNumber(index + 1);

Future<void> openDirections(ClientLocation l) => launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${l.lat},${l.lng}'),
      mode: LaunchMode.externalApplication,
    );

/// Directions to the client: straight away with one location, else pick one.
Future<void> directionsToClient(BuildContext context, Client client) async {
  final list = client.locations;
  if (list.isEmpty) return;
  if (list.length == 1) {
    await openDirections(list.single);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => Consumer(builder: (context, ref, _) {
      final l10n = AppLocalizations.of(context);
      final lang = Localizations.localeOf(context).languageCode;
      final types = ref.watch(locationTypesByIdProvider);
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, l) in list.indexed)
            ListTile(
              leading: const Icon(Icons.directions),
              title: Text(locationLabel(l, i, types, lang, l10n)),
              subtitle: l.address.isEmpty ? null : Text(l.address),
              onTap: () {
                Navigator.pop(sheet);
                openDirections(l);
              },
            ),
        ]),
      );
    }),
  );
}

/// The client's locations, main first; [canEdit]: add, change, make main,
/// delete. Saved right away, as a whole list (`locationsUpdate`).
class ClientLocationsList extends ConsumerWidget {
  const ClientLocationsList({super.key, required this.client, required this.canEdit, this.extrasOnly = false});

  final Client client;
  final bool canEdit;

  /// Edit screen: only the extra locations (the main one is edited in the
  /// form's own fields there), and no "make main".
  final bool extrasOnly;

  Future<void> _save(BuildContext context, WidgetRef ref, List<ClientLocation> list) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(clientsRepositoryProvider).update(client.id, locationsUpdate(list));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [ClientLocation? location]) async {
    final edited = await Navigator.push<ClientLocation>(
      context,
      MaterialPageRoute(builder: (_) => ClientLocationEditor(clientName: client.name, location: location)),
    );
    if (edited == null || !context.mounted) return;
    final list = [...client.locations];
    final i = list.indexWhere((l) => l.id == edited.id);
    if (i >= 0) {
      list[i] = edited;
    } else {
      list.add(edited);
    }
    await _save(context, ref, list);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ClientLocation location, String label) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.deleteLocationTitle(label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _save(context, ref, client.locations.where((l) => l.id != location.id).toList());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final types = ref.watch(locationTypesByIdProvider);
    final list = client.locations;
    if (extrasOnly && list.isEmpty) {
      return ListTile(dense: true, leading: const Icon(Icons.info_outline), title: Text(l10n.setMainLocationFirst));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (list.isEmpty) ListTile(dense: true, leading: const Icon(Icons.location_off), title: Text(l10n.noLocation)),
        for (final (i, l) in list.indexed)
          if (!extrasOnly || !l.isMain)
            ListTile(
              dense: true,
              leading: Icon(Icons.place, color: l.isMain ? theme.colorScheme.primary : null),
              title: Text(
                [locationLabel(l, i, types, lang, l10n), if (l.isMain && list.length > 1) l10n.mainLocation].join(' · '),
                style: theme.textTheme.bodyLarge,
              ),
              subtitle: Text([if (l.address.isNotEmpty) l.address, '${l.lat.toStringAsFixed(5)}, ${l.lng.toStringAsFixed(5)}']
                  .join('\n')),
              onTap: () => launchUrl(
                Uri.parse('https://www.google.com/maps/search/?api=1&query=${l.lat},${l.lng}'),
                mode: LaunchMode.externalApplication,
              ),
              trailing: canEdit
                  ? PopupMenuButton<String>(
                      onSelected: (action) => switch (action) {
                        'edit' => _edit(context, ref, l),
                        'main' => _save(context, ref, [l, ...list.where((x) => x.id != l.id)]),
                        _ => _delete(context, ref, l, locationLabel(l, i, types, lang, l10n)),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(l10n.editLocation)),
                        if (!l.isMain && !extrasOnly)
                          PopupMenuItem(value: 'main', child: Text(l10n.makeMainLocation)),
                        PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.directions),
                      tooltip: l10n.directions,
                      onPressed: () => openDirections(l),
                    ),
            ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(l10n.addLocation),
              ),
            ),
          ),
      ],
    );
  }
}
