import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/saving.dart';

/// Marketing items handed to clients at visits (user request 2026-10-18).
/// The enum name is the key in `visits.given`, `clients.given` and
/// `settings/givenItems`.
enum GivenItem { switchCatalog, bookletCatalog, displayStand, a4Samples }

/// The last time an item was given to a client and how many in all
/// (`clients.given.{item}` = {at, qty, total}).
class GivenRecord {
  const GivenRecord({required this.at, required this.qty, required this.total});

  final DateTime? at;
  final int qty;
  final int total;

  static Map<GivenItem, GivenRecord> parse(Object? raw) => {
        if (raw is Map)
          for (final item in GivenItem.values)
            if (raw[item.name] case final Map<Object?, Object?> m)
              item: GivenRecord(
                at: (m['at'] as Timestamp?)?.toDate(),
                qty: (m['qty'] as num?)?.toInt() ?? 0,
                total: (m['total'] as num?)?.toInt() ?? 0,
              ),
      };
}

/// Quantities given at one visit (`visits.given`), positive only.
Map<GivenItem, int> parseGiven(Object? raw) => {
      if (raw is Map)
        for (final item in GivenItem.values)
          if (raw[item.name] case final num n when n > 0) item: n.toInt(),
    };

/// After how many days a client should get a new one (`settings/givenItems`,
/// edited by the GM / sales manager).
class GivenItemRules {
  const GivenItemRules(this.days);

  final Map<GivenItem, int> days;

  /// Starting values; the managers adjust them.
  static const defaults = GivenItemRules({
    GivenItem.switchCatalog: 180,
    GivenItem.bookletCatalog: 180,
    GivenItem.displayStand: 365,
    GivenItem.a4Samples: 90,
  });

  int of(GivenItem item) => days[item] ?? defaults.days[item]!;

  factory GivenItemRules.fromMap(Map<String, dynamic>? d) => GivenItemRules({
        for (final item in GivenItem.values)
          item: switch (d?[item.name]) {
            final num n when n >= 1 => n.toInt(),
            _ => defaults.days[item]!,
          },
      });

  Map<String, dynamic> toMap() => {for (final item in GivenItem.values) item.name: of(item)};
}

enum GivenStatus { never, ok, dueSoon, due }

/// Days before the due date that count as "due soon". 14 unless changed in
/// App settings (`AppSettings.apply`).
var givenDueSoonDays = 14;

/// When the client should get a new [item]; null if never given.
DateTime? givenNextDue(GivenRecord? record, GivenItem item, GivenItemRules rules) =>
    record?.at?.add(Duration(days: rules.of(item)));

GivenStatus givenStatus(GivenRecord? record, GivenItem item, GivenItemRules rules, DateTime now) {
  final due = givenNextDue(record, item, rules);
  if (due == null) return GivenStatus.never;
  if (!now.isBefore(due)) return GivenStatus.due;
  return due.difference(now).inDays < givenDueSoonDays ? GivenStatus.dueSoon : GivenStatus.ok;
}

/// One hand-over of an item to a client (`clients.givenLog` entry): from a
/// visit ([visitId]) or recorded on the client page, possibly backdated.
class GivenEntry {
  const GivenEntry({
    required this.id,
    required this.item,
    required this.qty,
    required this.at,
    required this.byId,
    this.visitId,
  });

  final String id;
  final GivenItem item;
  final int qty;
  final DateTime at;
  final String byId;
  final String? visitId;

  bool get manual => visitId == null;

  Map<String, Object> toMap() => {
        'id': id,
        'item': item.name,
        'qty': qty,
        'at': Timestamp.fromDate(at),
        'byId': byId,
        'visitId': ?visitId,
      };

  static GivenEntry? fromMap(Object? m) {
    if (m is! Map) return null;
    final item = GivenItem.values.where((i) => i.name == m['item']).firstOrNull;
    final at = (m['at'] as Timestamp?)?.toDate();
    final qty = (m['qty'] as num?)?.toInt() ?? 0;
    if (item == null || at == null || qty <= 0) return null;
    return GivenEntry(
      id: m['id'] as String? ?? '',
      item: item,
      qty: qty,
      at: at,
      byId: m['byId'] as String? ?? '',
      visitId: m['visitId'] as String?,
    );
  }
}

/// `clients.givenLog`, newest first.
List<GivenEntry> parseGivenLog(Object? raw) => [
      if (raw is List)
        for (final m in raw) ?GivenEntry.fromMap(m),
    ]..sort((a, b) => b.at.compareTo(a.at));

/// Per item: the latest hand-over (date, quantity) and the total, from the
/// log plus [legacy] (`clients.given`, written by visits before the log).
Map<GivenItem, GivenRecord> summarizeGiven(List<GivenEntry> log, Map<GivenItem, GivenRecord> legacy) {
  final out = <GivenItem, GivenRecord>{};
  for (final item in GivenItem.values) {
    final old = legacy[item];
    DateTime? at = old?.at;
    var qty = old?.qty ?? 0;
    var total = old?.total ?? 0;
    for (final e in log.where((e) => e.item == item)) {
      total += e.qty;
      if (at == null || e.at.isAfter(at)) {
        at = e.at;
        qty = e.qty;
      }
    }
    if (total > 0) out[item] = GivenRecord(at: at, qty: qty, total: total);
  }
  return out;
}

/// Log entries for the items given at visit [visitId].
List<Map<String, Object>> visitGivenEntries(String visitId, String byId, DateTime at, Map<GivenItem, int> given) => [
      for (final MapEntry(key: item, value: qty) in given.entries)
        if (qty > 0) GivenEntry(id: '${visitId}_${item.name}', item: item, qty: qty, at: at, byId: byId, visitId: visitId).toMap(),
    ];

DocumentReference<Map<String, dynamic>> _client(String id) => FirebaseFirestore.instance.collection('clients').doc(id);

/// Client page: records a hand-over, possibly backdated.
Future<void> addGivenEntry(String clientId, GivenEntry entry) => saving(() =>
    _client(clientId).update({'givenLog': FieldValue.arrayUnion([entry.toMap()])}));

/// Removes log entries matching [test] (a manual entry, or a deleted visit's).
Future<void> removeGivenEntries(String clientId, bool Function(Map<Object?, Object?> raw) test) => saving(() =>
    FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_client(clientId));
      final log = snap.data()?['givenLog'];
      if (log is! List) return;
      final kept = [for (final m in log) if (m is! Map || !test(m)) m];
      if (kept.length != log.length) tx.update(_client(clientId), {'givenLog': kept});
    }));

final givenItemRulesProvider = StreamProvider<GivenItemRules>((ref) => FirebaseFirestore.instance
    .doc('settings/givenItems')
    .snapshots()
    .map((s) => GivenItemRules.fromMap(s.data())));

Future<void> saveGivenItemRules(GivenItemRules rules) => saving(() =>
    FirebaseFirestore.instance.doc('settings/givenItems').set(rules.toMap()));
