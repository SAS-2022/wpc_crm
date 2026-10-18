import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Marketing items handed to clients at visits (user request 2026-10-18).
/// The enum name is the key in `visits.given`, `clients.given` and
/// `settings/givenItems`.
enum GivenItem { switchCatalog, bookletCatalog, displayStand }

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

/// Days before the due date that count as "due soon".
const givenDueSoonDays = 14;

/// When the client should get a new [item]; null if never given.
DateTime? givenNextDue(GivenRecord? record, GivenItem item, GivenItemRules rules) =>
    record?.at?.add(Duration(days: rules.of(item)));

GivenStatus givenStatus(GivenRecord? record, GivenItem item, GivenItemRules rules, DateTime now) {
  final due = givenNextDue(record, item, rules);
  if (due == null) return GivenStatus.never;
  if (!now.isBefore(due)) return GivenStatus.due;
  return due.difference(now).inDays < givenDueSoonDays ? GivenStatus.dueSoon : GivenStatus.ok;
}

/// The client update for items given at a visit: last date, last quantity
/// and a running total per item (dotted paths, so other items stay).
Map<String, Object> givenClientUpdate(Map<GivenItem, int> given) => {
      for (final MapEntry(key: item, value: qty) in given.entries)
        if (qty > 0) ...{
          'given.${item.name}.at': FieldValue.serverTimestamp(),
          'given.${item.name}.qty': qty,
          'given.${item.name}.total': FieldValue.increment(qty),
        },
    };

/// `clients.given` rebuilt from a client's visits (after a visit is
/// deleted): per item the latest visit that gave it, and the sum.
Map<String, Object> givenFromVisits(Iterable<({DateTime? at, Map<GivenItem, int> given})> visits) {
  final out = <String, Object>{};
  for (final item in GivenItem.values) {
    DateTime? last;
    var lastQty = 0, total = 0;
    for (final v in visits) {
      final qty = v.given[item] ?? 0;
      if (qty <= 0) continue;
      total += qty;
      if (v.at != null && (last == null || v.at!.isAfter(last))) {
        last = v.at;
        lastQty = qty;
      }
    }
    if (total > 0) out[item.name] = {'at': last == null ? null : Timestamp.fromDate(last), 'qty': lastQty, 'total': total};
  }
  return out;
}

final givenItemRulesProvider = StreamProvider<GivenItemRules>((ref) => FirebaseFirestore.instance
    .doc('settings/givenItems')
    .snapshots()
    .map((s) => GivenItemRules.fromMap(s.data())));

Future<void> saveGivenItemRules(GivenItemRules rules) =>
    FirebaseFirestore.instance.doc('settings/givenItems').set(rules.toMap());
