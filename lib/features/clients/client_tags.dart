import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';
import '../../core/saving.dart';

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

/// Labels for a client's locations (Office, Factory, …), used until a GM /
/// sales manager first saves the list (`settings/locationTypes`).
const defaultLocationTypes = [
  ClientTag(id: 'office', en: 'Office', ar: 'مكتب'),
  ClientTag(id: 'factory', en: 'Factory', ar: 'مصنع'),
  ClientTag(id: 'showroom', en: 'Showroom', ar: 'معرض'),
  ClientTag(id: 'warehouse', en: 'Warehouse', ar: 'مستودع'),
  ClientTag(id: 'workshop', en: 'Workshop', ar: 'ورشة'),
  ClientTag(id: 'branch', en: 'Branch', ar: 'فرع'),
];

/// Job titles people pick when registering (user request 2026-10-19: a list,
/// not typed), used until a GM / sales manager first saves the list
/// (`settings/positions`, readable before sign-in). `users.position` holds the id.
const defaultPositions = [
  ClientTag(id: 'sales_executive', en: 'Sales Executive', ar: 'مندوب مبيعات'),
  ClientTag(id: 'key_account_manager', en: 'Key Account Manager', ar: 'مدير حسابات رئيسية'),
  ClientTag(id: 'accountant', en: 'Accountant', ar: 'محاسب'),
  ClientTag(id: 'procurement_officer', en: 'Procurement Officer', ar: 'موظف مشتريات'),
  ClientTag(id: 'hr_officer', en: 'HR Officer', ar: 'موظف موارد بشرية'),
  ClientTag(id: 'engineer', en: 'Engineer', ar: 'مهندس'),
  ClientTag(id: 'driver', en: 'Driver', ar: 'سائق'),
  ClientTag(id: 'worker', en: 'Worker', ar: 'عامل'),
  ClientTag(id: 'storekeeper', en: 'Storekeeper', ar: 'أمين مستودع'),
  ClientTag(id: 'admin_assistant', en: 'Administrative Assistant', ar: 'مساعد إداري'),
];

/// The editable label lists: business tags on clients, the labels of a
/// client's locations and job positions. Same shape ({tags: [{id, en, ar}]}),
/// same editor.
enum TagList {
  clientTags('settings/clientTags', defaultClientTags),
  locationTypes('settings/locationTypes', defaultLocationTypes),
  positions('settings/positions', defaultPositions);

  const TagList(this.path, this.defaults);

  final String path;
  final List<ClientTag> defaults;

  DocumentReference<Map<String, dynamic>> get doc => FirebaseFirestore.instance.doc(path);
}

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

List<ClientTag> _tagsOf(TagList kind, Map<String, dynamic>? data) {
  final list = data?['tags'];
  if (list is! List) return kind.defaults;
  return [
    for (final m in list)
      if (m is Map) ClientTag.fromMap(m),
  ];
}

final tagListProvider = StreamProvider.family<List<ClientTag>, TagList>(
    (ref, kind) => kind.doc.snapshots().map((s) => _tagsOf(kind, s.data())));

final clientTagsProvider = tagListProvider(TagList.clientTags);

/// Location type id → label.
final locationTypesByIdProvider = Provider<Map<String, ClientTag>>((ref) => {
      for (final t in ref.watch(tagListProvider(TagList.locationTypes)).value ?? defaultLocationTypes) t.id: t,
    });

/// Position id → label; [positionLabel] shows it.
final positionsByIdProvider = Provider<Map<String, ClientTag>>((ref) => {
      for (final t in ref.watch(tagListProvider(TagList.positions)).value ?? defaultPositions) t.id: t,
    });

/// A person's position in [lang]; text typed before positions became a list
/// is shown as it is.
String positionLabel(Map<String, ClientTag> positions, String position, String lang) =>
    positions[position]?.label(lang) ?? position;

/// Tag id → tag, for showing a client's tags.
final clientTagsByIdProvider = Provider<Map<String, ClientTag>>((ref) => {
      for (final t in ref.watch(clientTagsProvider).value ?? defaultClientTags) t.id: t,
    });

/// Adds a tag ([id] null) or renames one. Checked inside a transaction so two
/// people can't add the same name at once; throws [DuplicateTagException].
Future<void> saveTag(TagList kind, {String? id, required String en, required String ar}) => saving(() =>
    FirebaseFirestore.instance.runTransaction((tx) async {
      final tags = _tagsOf(kind, (await tx.get(kind.doc)).data());
      if (isDuplicateTag(tags, en, ar, exceptId: id)) throw const DuplicateTagException();
      final tag = ClientTag(id: id ?? kind.doc.collection('x').doc().id, en: en, ar: ar);
      final updated = id == null ? [...tags, tag] : [for (final t in tags) t.id == id ? tag : t];
      tx.set(kind.doc, {'tags': [for (final t in updated) t.toMap()]});
    }));

/// Removes the label from the list. A client tag is also removed from every
/// client that has it; a deleted location type leaves its locations unlabelled.
Future<void> deleteTag(TagList kind, String id) => saving(() async {
  final db = FirebaseFirestore.instance;
  await db.runTransaction((tx) async {
    final tags = _tagsOf(kind, (await tx.get(kind.doc)).data());
    tx.set(kind.doc, {'tags': [for (final t in tags) if (t.id != id) t.toMap()]});
  });
  if (kind != TagList.clientTags) return;
  final tagged = await db.collection('clients').where('tagIds', arrayContains: id).get();
  for (var i = 0; i < tagged.docs.length; i += 400) {
    final batch = db.batch();
    for (final d in tagged.docs.skip(i).take(400)) {
      batch.update(d.reference, {'tagIds': FieldValue.arrayRemove([id])});
    }
    await batch.commit();
  }
});

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
