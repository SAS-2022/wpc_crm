import 'dart:math';

import 'client.dart';

/// Why clients are listed together as possible duplicates.
enum DuplicateReason { sameVat, sameName, samePhone, similarName, nearby }

class DuplicateGroup {
  const DuplicateGroup(this.clients, this.reasons);

  final List<Client> clients;
  final Set<DuplicateReason> reasons;

  /// Identical (same Tax ID or same name) rather than only similar.
  bool get identical => reasons.contains(DuplicateReason.sameVat) || reasons.contains(DuplicateReason.sameName);
}

/// Words that say nothing about which company it is.
const _noise = {
  'co', 'company', 'est', 'establishment', 'corp', 'corporation', 'llc', 'ltd', 'limited', 'inc', 'the', 'and',
  'for', 'of', 'شركه', 'مؤسسه', 'شركة', 'مؤسسة', 'و', 'ذ', 'م', 'م.', 'ش',
};

/// Name words for comparing: lower case, Arabic letter variants unified,
/// punctuation and company-form words removed.
List<String> nameTokens(String name) {
  final s = name
      .toLowerCase()
      .replaceAll(RegExp('[ً-ٰٟـ]'), '') // harakat, tatweel
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ');
  return s.split(' ').where((t) => t.isNotEmpty && !_noise.contains(t)).toList();
}

/// The name without spaces, so "Al-Noor" and "Alnoor" are the same.
String compactName(String name) => nameTokens(name).join();

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Last 9 digits of a phone number (drops +966 / 0 prefixes); '' if too short.
String phoneKey(String phone) {
  final d = _digits(phone);
  return d.length < 9 ? '' : d.substring(d.length - 9);
}

int _distance(String a, String b) {
  if ((a.length - b.length).abs() > 2) return 3;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

double _meters(Client a, Client b) {
  const r = 6371000.0;
  final dLat = (b.lat! - a.lat!) * pi / 180;
  final dLng = (b.lng! - a.lng!) * pi / 180;
  final h = pow(sin(dLat / 2), 2) + cos(a.lat! * pi / 180) * cos(b.lat! * pi / 180) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(h));
}

/// Similar names: one name's words all in the other (at least two words),
/// mostly the same words, or a typo or two in a longer name.
bool similarNames(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return false;
  final sa = a.toSet(), sb = b.toSet();
  final common = sa.intersection(sb).length;
  final smaller = min(sa.length, sb.length);
  if (smaller >= 2 && common == smaller) return true;
  if (common / sa.union(sb).length >= 0.75) return true;
  final ca = a.join(), cb = b.join();
  return min(ca.length, cb.length) >= 8 && _distance(ca, cb) <= 2;
}

/// Groups of clients that look like the same customer: same Tax ID, same
/// name (or alias), same phone number, similar names, or within 50 m with a
/// name word in common. Pairs marked "not duplicates" are left apart.
/// Clients only compared when they share a rare name word, phone, Tax ID or
/// name start, so 2,500 clients stay quick.
List<DuplicateGroup> findDuplicates(List<Client> clients) {
  final n = clients.length;
  final tokens = [for (final c in clients) nameTokens(c.name)];
  final compacts = [
    for (final c in clients) {for (final name in [c.name, ...c.aliases]) compactName(name)}..remove(''),
  ];
  final phones = [
    for (final c in clients) {phoneKey(c.phone), phoneKey(c.mobile)}..remove(''),
  ];
  final vats = [for (final c in clients) _digits(c.vat)];

  // Candidate pairs through shared keys.
  final index = <String, List<int>>{};
  void add(String key, int i) => (index[key] ??= []).add(i);
  for (var i = 0; i < n; i++) {
    for (final t in tokens[i].toSet()) {
      if (t.length >= 2) add('t:$t', i);
    }
    for (final c in compacts[i]) {
      add('n:$c', i);
      if (c.length >= 4) add('p:${c.substring(0, 4)}', i);
    }
    for (final p in phones[i]) {
      add('ph:$p', i);
    }
    if (vats[i].isNotEmpty) add('v:${vats[i]}', i);
  }
  final pairs = <(int, int)>{};
  for (final MapEntry(:key, value: list) in index.entries) {
    // A word used by many clients ("trading", "riyadh") doesn't pick pairs.
    if (list.length < 2 || (list.length > 30 && (key.startsWith('t:') || key.startsWith('p:')))) continue;
    // A phone shared by many clients is a placeholder, not a match.
    if (key.startsWith('ph:') && list.length > 3) continue;
    for (var x = 0; x < list.length; x++) {
      for (var y = x + 1; y < list.length; y++) {
        pairs.add((list[x], list[y]));
      }
    }
  }

  final parent = List<int>.generate(n, (i) => i);
  int find(int i) => parent[i] == i ? i : parent[i] = find(parent[i]);
  final reasonsOf = <int, Set<DuplicateReason>>{};

  for (final (i, j) in pairs) {
    final a = clients[i], b = clients[j];
    if (a.notDuplicates.contains(b.id) || b.notDuplicates.contains(a.id)) continue;
    final reasons = <DuplicateReason>{};
    final differentVat = vats[i].isNotEmpty && vats[j].isNotEmpty && vats[i] != vats[j];
    if (vats[i].isNotEmpty && vats[i] == vats[j]) reasons.add(DuplicateReason.sameVat);
    if (compacts[i].intersection(compacts[j]).isNotEmpty) reasons.add(DuplicateReason.sameName);
    // Different Tax IDs are different companies unless the names are identical.
    if (!differentVat) {
      if (phones[i].intersection(phones[j]).isNotEmpty) reasons.add(DuplicateReason.samePhone);
      if (!reasons.contains(DuplicateReason.sameName) && similarNames(tokens[i], tokens[j])) {
        reasons.add(DuplicateReason.similarName);
      }
      if (a.hasLocation &&
          b.hasLocation &&
          tokens[i].toSet().intersection(tokens[j].toSet()).isNotEmpty &&
          _meters(a, b) <= 50) {
        reasons.add(DuplicateReason.nearby);
      }
    }
    if (reasons.isEmpty) continue;
    final ri = find(i), rj = find(j);
    final root = ri < rj ? ri : rj;
    final merged = {...?reasonsOf.remove(ri), ...?reasonsOf.remove(rj), ...reasons};
    parent[ri] = root;
    parent[rj] = root;
    reasonsOf[root] = merged;
  }

  final members = <int, List<Client>>{};
  for (var i = 0; i < n; i++) {
    (members[find(i)] ??= []).add(clients[i]);
  }
  final groups = [
    for (final MapEntry(key: root, value: list) in members.entries)
      if (list.length > 1) DuplicateGroup(list..sort((a, b) => a.name.compareTo(b.name)), reasonsOf[root] ?? const {}),
  ];
  // Identical first, then by name.
  groups.sort((a, b) {
    if (a.identical != b.identical) return a.identical ? -1 : 1;
    return a.clients.first.name.compareTo(b.clients.first.name);
  });
  return groups;
}
