import '../home/stats.dart';
import '../visits/visit.dart';
import 'client.dart';
import 'given_items.dart';

// Catalogs & stands page (`/catalogs`, user request 2026-11-01): clients by
// the items they got, with their last visit and visit totals, and every
// hand-over in a period by salesperson.

/// One client who got at least one item (of [item], when filtering).
class CatalogClientRow {
  const CatalogClientRow({
    required this.client,
    required this.items,
    required this.status,
    required this.lastGivenAt,
    required this.visits,
    required this.calls,
    required this.lastVisitAt,
  });

  final Client client;

  /// The items shown on the row (one when filtering by item).
  final Map<GivenItem, GivenRecord> items;

  /// The most urgent status of [items] (due > due soon > ok).
  final GivenStatus status;
  final DateTime? lastGivenAt;

  /// Every visit / call to the client by anyone.
  final int visits;
  final int calls;

  /// The latest visit (calls not counted).
  final DateTime? lastVisitAt;
}

int _urgency(GivenStatus s) => switch (s) {
      GivenStatus.due => 3,
      GivenStatus.dueSoon => 2,
      GivenStatus.ok => 1,
      GivenStatus.never => 0,
    };

/// Clients who got [item] (null = any item), with visit totals from
/// [visits] (the visits of those clients). Newest hand-over first.
List<CatalogClientRow> catalogClientRows({
  required List<Client> clients,
  required List<Visit> visits,
  required GivenItemRules rules,
  required DateTime now,
  GivenItem? item,
}) {
  final byClient = <String, List<Visit>>{};
  for (final v in visits) {
    (byClient[v.clientId] ??= []).add(v);
  }
  final rows = <CatalogClientRow>[];
  for (final c in clients) {
    final items = {
      for (final MapEntry(:key, :value) in c.given.entries)
        if (item == null || key == item) key: value,
    };
    if (items.isEmpty) continue;
    var status = GivenStatus.never;
    DateTime? lastGiven;
    for (final MapEntry(:key, :value) in items.entries) {
      final s = givenStatus(value, key, rules, now);
      if (_urgency(s) > _urgency(status)) status = s;
      if (value.at != null && (lastGiven == null || value.at!.isAfter(lastGiven))) lastGiven = value.at;
    }
    final own = byClient[c.id] ?? const <Visit>[];
    DateTime? lastVisit;
    var calls = 0;
    for (final v in own) {
      if (v.isCall) {
        calls++;
      } else if (v.checkedInAt != null && (lastVisit == null || v.checkedInAt!.isAfter(lastVisit))) {
        lastVisit = v.checkedInAt;
      }
    }
    rows.add(CatalogClientRow(
      client: c,
      items: items,
      status: status,
      lastGivenAt: lastGiven,
      visits: own.length - calls,
      calls: calls,
      lastVisitAt: lastVisit,
    ));
  }
  rows.sort((a, b) => (b.lastGivenAt ?? DateTime(0)).compareTo(a.lastGivenAt ?? DateTime(0)));
  return rows;
}

/// One item handed to a client: a `givenLog` entry or (app builds before the
/// log) a visit's `given`.
class Handover {
  const Handover({
    required this.client,
    required this.item,
    required this.qty,
    required this.at,
    required this.byId,
    this.visitId,
  });

  final Client client;
  final GivenItem item;
  final int qty;
  final DateTime at;
  final String byId;
  final String? visitId;

  bool get atVisit => visitId != null;
}

/// Every hand-over to [clients] in [range], newest first. [visits] = the
/// range's visits: their `given` counts only when no log has that visit.
List<Handover> handoversIn({
  required List<Client> clients,
  required List<Visit> visits,
  required StatsRange range,
}) {
  final byId = {for (final c in clients) c.id: c};
  final logged = {
    for (final c in clients)
      for (final e in c.givenLog) ?e.visitId,
  };
  final out = <Handover>[
    for (final c in clients)
      for (final e in c.givenLog)
        if (range.contains(e.at))
          Handover(client: c, item: e.item, qty: e.qty, at: e.at, byId: e.byId, visitId: e.visitId),
  ];
  for (final v in visits) {
    final c = byId[v.clientId];
    final at = v.checkedInAt;
    if (c == null || at == null || v.given.isEmpty || logged.contains(v.id) || !range.contains(at)) continue;
    for (final MapEntry(key: item, value: qty) in v.given.entries) {
      out.add(Handover(client: c, item: item, qty: qty, at: at, byId: v.salesExecId, visitId: v.id));
    }
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

/// What one person handed over.
class HandoverTotals {
  HandoverTotals(this.byId);

  final String byId;
  final byItem = <GivenItem, int>{};
  final clientIds = <String>{};

  int get total => byItem.values.fold(0, (s, n) => s + n);
}

/// Per person, most items first.
List<HandoverTotals> handoverTotals(Iterable<Handover> handovers) {
  final out = <String, HandoverTotals>{};
  for (final h in handovers) {
    final t = out[h.byId] ??= HandoverTotals(h.byId);
    t.byItem[h.item] = (t.byItem[h.item] ?? 0) + h.qty;
    t.clientIds.add(h.client.id);
  }
  return out.values.toList()..sort((a, b) => b.total.compareTo(a.total));
}
