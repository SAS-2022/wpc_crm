import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'client_tags.dart';
import 'clients_repository.dart';
import '../users/users_repository.dart';

/// GM / sales manager: add, rename and delete client tags, or (with
/// [TagList.locationTypes]) the labels of client locations. Names must be
/// unique (case, spaces and Arabic letter forms ignored).
class ClientTagsScreen extends ConsumerWidget {
  const ClientTagsScreen({super.key, this.kind = TagList.clientTags});

  final TagList kind;

  Future<void> _edit(BuildContext context, List<ClientTag> tags, [ClientTag? tag]) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final en = TextEditingController(text: tag?.en ?? '');
    final ar = TextEditingController(text: tag?.ar ?? '');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tag == null ? l10n.addTag : l10n.editTag),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: en,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.tagNameEn),
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.required
                    : isDuplicateTag(tags, v, ar.text, exceptId: tag?.id)
                        ? l10n.tagDuplicate
                        : null,
              ),
              TextFormField(
                controller: ar,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(labelText: l10n.tagNameAr),
                validator: (v) =>
                    isDuplicateTag(tags, '', v ?? '', exceptId: tag?.id) ? l10n.tagDuplicate : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, true);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await saveTag(kind, id: tag?.id, en: en.text.trim(), ar: ar.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
    } on DuplicateTagException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.tagDuplicate)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  Future<void> _delete(BuildContext context, ClientTag tag, String label, int used) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.deleteTagTitle(label)),
        content: Text(kind == TagList.positions ? l10n.deletePositionBody(used) : l10n.deleteTagBody(used)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteTag(kind, tag.id);
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('${e.message}'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tags = ref.watch(tagListProvider(kind)).value;
    final clients = ref.watch(allClientsProvider).value ?? const [];
    final users = ref.watch(usersProvider).value ?? const [];
    final lang = Localizations.localeOf(context).languageCode;
    final locations = kind == TagList.locationTypes;
    final positions = kind == TagList.positions;
    int used(String id) => positions
        ? users.where((u) => u.position == id).length
        : clients.where((c) => locations ? c.locations.any((l) => l.typeId == id) : c.tagIds.contains(id)).length;

    return Scaffold(
      appBar: AppBar(title: Text(positions ? l10n.positions : locations ? l10n.locationTypes : l10n.clientTags)),
      floatingActionButton: tags == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(context, tags),
              icon: const Icon(Icons.add),
              label: Text(positions ? l10n.addPosition : l10n.addTag),
            ),
      body: tags == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(positions ? l10n.positionsHelp : locations ? l10n.locationTypesHelp : l10n.clientTagsHelp),
                ),
                for (final t in tags)
                  ListTile(
                    leading: Icon(positions ? Icons.work_outline : locations ? Icons.place_outlined : Icons.sell_outlined),
                    title: Text(t.label(lang)),
                    subtitle: Text([lang == 'ar' ? t.en : t.ar, positions ? l10n.peopleCount(used(t.id)) : l10n.clientsCountShort(used(t.id))]
                        .where((s) => s.isNotEmpty)
                        .join(' · ')),
                    onTap: () => _edit(context, tags, t),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.delete,
                      onPressed: () => _delete(context, t, t.label(lang), used(t.id)),
                    ),
                  ),
              ],
            ),
    );
  }
}
