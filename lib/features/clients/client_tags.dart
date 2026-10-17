import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';

/// A business tag on clients (Factory, Showroom, …), used to filter the
/// client list and map. The list lives in Firestore `settings/clientTags`
/// {tags: [{id, en, ar}]}; GM / sales manager edit it, clients keep the ids
/// in `clients.tagIds`.
class ClientTag {
  const ClientTag({required this.id, required this.en, this.ar = ''});

  factory ClientTag.fromMap(Map<dynamic, dynamic> m) =>
      ClientTag(id: m['id'] as String? ?? '', en: m['en'] as String? ?? '', ar: m['ar'] as String? ?? '');

  final String id;
  final String en;

  /// Arabic name; the English one is shown when empty.
  final String ar;

  String label(String languageCode) => languageCode == 'ar' && ar.isNotEmpty ? ar : en;

  Map<String, dynamic> toMap() => {'id': id, 'en': en, 'ar': ar};
}

/// Used until a GM / sales manager first saves the list.
const defaultClientTags = [
  ClientTag(id: 'factory', en: 'Factory', ar: 'مصنع'),
  ClientTag(id: 'workshop', en: 'Workshop', ar: 'ورشة'),
  ClientTag(id: 'contractor', en: 'Contractor', ar: 'مقاول'),
  ClientTag(id: 'interior_designer', en: 'Interior Designer', ar: 'مصمم داخلي'),
  ClientTag(id: 'showroom', en: 'Showroom', ar: 'معرض'),
];

/// Comparison key: case, spaces, punctuation and Arabic letter forms ignored.
String tagKey(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[ً-ٰٟـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// True when [en] or [ar] has the same key as a name (English or Arabic) of
/// another tag than [exceptId].
bool isDuplicateTag(List<ClientTag> tags, String en, String ar, {String? exceptId}) {
  final keys = {tagKey(en), tagKey(ar)}..remove('');
  return tags.any((t) => t.id != exceptId && (keys.contains(tagKey(t.en)) || keys.contains(tagKey(t.ar))));
}

class DuplicateTagException implements Exception {
  const DuplicateTagException();
}

List<ClientTag> _tagsOf(Map<String, dynamic>? data) {
  final list = data?['tags'];
  if (list is! List) return defaultClientTags;
  return [
    for (final m in list)
      if (m is Map) ClientTag.fromMap(m),
  ];
}

final _doc = FirebaseFirestore.instance.doc('settings/clientTags');

final clientTagsProvider = StreamProvider<List<ClientTag>>((ref) => _doc.snapshots().map((s) => _tagsOf(s.data())));

/// Tag id → tag, for showing a client's tags.
final clientTagsByIdProvider = Provider<Map<String, ClientTag>>((ref) => {
      for (final t in ref.watch(clientTagsProvider).value ?? defaultClientTags) t.id: t,
    });

/// Adds a tag ([id] null) or renames one. Checked inside a transaction so two
/// people can't add the same name at once; throws [DuplicateTagException].
Future<void> saveClientTag({String? id, required String en, required String ar}) =>
    FirebaseFirestore.instance.runTransaction((tx) async {
      final tags = _tagsOf((await tx.get(_doc)).data());
      if (isDuplicateTag(tags, en, ar, exceptId: id)) throw const DuplicateTagException();
      final tag = ClientTag(id: id ?? _doc.collection('x').doc().id, en: en, ar: ar);
      final updated = id == null ? [...tags, tag] : [for (final t in tags) t.id == id ? tag : t];
      tx.set(_doc, {'tags': [for (final t in updated) t.toMap()]});
    });

/// Removes the tag from the list and from every client that has it.
Future<void> deleteClientTag(String id) async {
  final db = FirebaseFirestore.instance;
  await db.runTransaction((tx) async {
    final tags = _tagsOf((await tx.get(_doc)).data());
    tx.set(_doc, {'tags': [for (final t in tags) if (t.id != id) t.toMap()]});
  });
  final tagged = await db.collection('clients').where('tagIds', arrayContains: id).get();
  for (var i = 0; i < tagged.docs.length; i += 400) {
    final batch = db.batch();
    for (final d in tagged.docs.skip(i).take(400)) {
      batch.update(d.reference, {'tagIds': FieldValue.arrayRemove([id])});
    }
    await batch.commit();
  }
}

/// The client's tags as small chips; nothing when it has none.
class ClientTagChips extends ConsumerWidget {
  const ClientTagChips({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(clientTagsByIdProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final names = [
      for (final id in client.tagIds)
        if (tags[id] case final t?) t.label(lang),
    ];
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final n in names)
            Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: const Icon(Icons.sell_outlined, size: 14),
              label: Text(n),
            ),
        ],
      ),
    );
  }
}

/// Asks which tags to add to or remove from [count] clients. Returns
/// (add, remove) or null when cancelled.
Future<({Set<String> add, Set<String> remove})?> showBulkTagsDialog(BuildContext context, int count) {
  final add = <String>{};
  final remove = <String>{};
  return showDialog(
    context: context,
    builder: (dialog) => Consumer(
      builder: (context, ref, _) {
        final l10n = AppLocalizations.of(context);
        final lang = Localizations.localeOf(context).languageCode;
        final tags = ref.watch(clientTagsProvider).value ?? defaultClientTags;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(l10n.tagClientsTitle(count)),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(l10n.tagClientsHelp, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  // Tap cycles: unchanged → add → remove → unchanged.
                  for (final t in tags)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        add.contains(t.id)
                            ? Icons.add_circle
                            : remove.contains(t.id)
                                ? Icons.remove_circle
                                : Icons.radio_button_unchecked,
                        color: add.contains(t.id)
                            ? Colors.green
                            : remove.contains(t.id)
                                ? Theme.of(context).colorScheme.error
                                : null,
                      ),
                      title: Text(t.label(lang)),
                      subtitle: add.contains(t.id)
                          ? Text(l10n.tagWillAdd)
                          : remove.contains(t.id)
                              ? Text(l10n.tagWillRemove)
                              : null,
                      onTap: () => setState(() {
                        if (add.remove(t.id)) {
                          remove.add(t.id);
                        } else if (!remove.remove(t.id)) {
                          add.add(t.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: add.isEmpty && remove.isEmpty ? null : () => Navigator.pop(dialog, (add: add, remove: remove)),
                child: Text(l10n.save),
              ),
            ],
          ),
        );
      },
    ),
  );
}
