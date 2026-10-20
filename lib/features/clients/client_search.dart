import 'client.dart';

// Client search (user request 2026-10-20): name, other names, city, contact
// person and contacts, phone numbers, VAT, CR (company ID) and the
// salesperson. Returns where it matched, so the list can highlight the
// matching letters in yellow.

/// Where a search matched.
enum SearchField { name, alias, city, contactPerson, contact, phone, vat, cr, salesperson }

/// One matching text and the [start, end) ranges of the match in it.
class SearchHit {
  const SearchHit(this.field, this.text, this.ranges);

  final SearchField field;
  final String text;
  final List<(int, int)> ranges;
}

/// The first hit per field, in [SearchField] order (name first).
class SearchMatch {
  const SearchMatch(this.hits);

  final List<SearchHit> hits;

  /// The hit on the client's name, if any.
  SearchHit? get name => hits.where((h) => h.field == SearchField.name).firstOrNull;

  /// The first hit on something other than the name, shown under the row
  /// when the name itself didn't match.
  SearchHit? get other => name != null ? null : hits.firstOrNull;
}

/// A typed search, prepared once for many clients.
class ClientQuery {
  ClientQuery(String raw)
      : text = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
        digits = _national(raw.replaceAll(RegExp(r'\D'), ''));

  final String text;

  /// The digits typed, without a country code / leading 0 (for phones);
  /// empty when fewer than 3 digits were typed or letters were typed too.
  final String digits;

  bool get isEmpty => text.isEmpty;
  bool get _phoneLike => digits.length >= 3 && !RegExp(r'[^\d\s+()\-]').hasMatch(text);

  /// Every [start, end) where the query appears in [s], ignoring case.
  List<(int, int)> rangesIn(String s) {
    if (text.isEmpty || s.isEmpty) return const [];
    final lower = s.toLowerCase();
    final out = <(int, int)>[];
    for (var i = lower.indexOf(text); i >= 0; i = lower.indexOf(text, i + text.length)) {
      out.add((i, i + text.length));
    }
    return out;
  }

  /// Phone numbers: digits only, so "055 123" finds "+966 55 123 4567".
  List<(int, int)> phoneRangesIn(String s) {
    if (!_phoneLike) return const [];
    // Positions of the digits in [s], after the country code / leading 0.
    final positions = [for (var i = 0; i < s.length; i++) if (_isDigit(s.codeUnitAt(i))) i];
    final all = String.fromCharCodes([for (final i in positions) s.codeUnitAt(i)]);
    final skip = all.length - _national(all).length;
    final national = all.substring(skip);
    final at = national.indexOf(digits);
    if (at < 0) return const [];
    return [(positions[skip + at], positions[skip + at + digits.length - 1] + 1)];
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  /// Saudi numbers: drops 00966 / 966 / a leading 0.
  static String _national(String d) {
    for (final p in ['00966', '966', '0']) {
      if (d.startsWith(p) && d.length > p.length + 2) return d.substring(p.length);
    }
    return d;
  }
}

/// Null when [c] doesn't match [q]. [salesperson]: the assigned person's name.
SearchMatch? searchClient(Client c, ClientQuery q, {String salesperson = ''}) {
  if (q.isEmpty) return const SearchMatch([]);
  final hits = <SearchHit>[];
  void text(SearchField f, String s) {
    if (hits.any((h) => h.field == f)) return;
    final r = q.rangesIn(s);
    if (r.isNotEmpty) hits.add(SearchHit(f, s, r));
  }

  void phone(SearchField f, String s) {
    if (hits.any((h) => h.field == f)) return;
    final r = q.phoneRangesIn(s);
    if (r.isNotEmpty) hits.add(SearchHit(f, s, r));
  }

  text(SearchField.name, c.name);
  for (final a in c.aliases) {
    text(SearchField.alias, a);
  }
  text(SearchField.city, c.city);
  text(SearchField.contactPerson, c.contactPerson);
  for (final p in c.contacts) {
    text(SearchField.contact, p.name);
  }
  for (final s in [c.phone, c.mobile, for (final p in c.contacts) ...[p.phone, p.mobile]]) {
    phone(SearchField.phone, s);
    text(SearchField.phone, s);
  }
  text(SearchField.vat, c.vat);
  text(SearchField.cr, c.companyId);
  text(SearchField.salesperson, salesperson);
  return hits.isEmpty ? null : SearchMatch(hits);
}
