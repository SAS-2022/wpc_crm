import '../import/plus_code.dart' show saudiCities;

// Client documents (user request 2026-10-19): Commercial Registration, VAT
// certificate and National Address, attached on the client edit screen. Their
// text is read on the device for free (PDF text layer / ML Kit on phones)
// and parsed here into suggestions for the client's fields.

/// Stored as `docType` on the client's attachment.
enum ClientDocType {
  cr('cr'),
  vat('vat'),
  nationalAddress('nationalAddress');

  const ClientDocType(this.key);

  final String key;

  static ClientDocType? fromKey(String key) => values.where((t) => t.key == key).firstOrNull;
}

/// What could be read from a document. Null = not found.
class DocFields {
  const DocFields({
    this.vat,
    this.crNumber,
    this.buildingNumber,
    this.street,
    this.district,
    this.city,
    this.postalCode,
    this.additionalNumber,
    this.shortAddress,
  });

  final String? vat;
  final String? crNumber;
  final String? buildingNumber;
  final String? street;
  final String? district;
  final String? city;
  final String? postalCode;
  final String? additionalNumber;
  final String? shortAddress;

  bool get hasAddress => [buildingNumber, street, district, postalCode, additionalNumber, shortAddress].any((v) => v != null);

  bool get isEmpty => vat == null && crNumber == null && city == null && !hasAddress;

  /// Saudi National Address order: "1234 King Fahd Rd, Al Olaya, Riyadh
  /// 12211-5678 (RRRD1234)". Null without street or building number.
  String? get addressLine {
    if (street == null && buildingNumber == null) return null;
    final first = [?buildingNumber, ?street].join(' ');
    final postal = [?postalCode, ?additionalNumber].join('-');
    final last = [?city, if (postal.isNotEmpty) postal].join(' ');
    final line = [first, ?district, if (last.isNotEmpty) last].join(', ');
    return shortAddress == null ? line : '$line ($shortAddress)';
  }
}

/// Arabic-Indic / Persian digits → 0-9, Arabic comma → comma, Persian
/// letter forms → Arabic, tatweel and direction marks removed.
String normalizeDocText(String text) {
  final out = StringBuffer();
  for (final r in text.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else if (r == 0x060C) {
      out.write(',');
    } else if (r == 0x0640 || r == 0x200E || r == 0x200F || (r >= 0x202A && r <= 0x202E) || (r >= 0x2066 && r <= 0x2069)) {
      continue;
    } else if (r == 0x00A0) {
      out.write(' ');
    } else if (r == 0x06BE || r == 0x06C1) {
      out.write('ه'); // Persian heh forms some PDFs use
    } else if (r == 0x06CC) {
      out.write('ي');
    } else if (r == 0x06A9) {
      out.write('ك');
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

const _crLabels = [
  'commercial registration', 'commercial register', 'c.r', 'cr no', 'cr number', 'unified number',
  'unified national number', 'رقم السجل', 'السجل التجاري', 'الرقم الوطني الموحد', 'الرقم الموحد',
];
const _buildingLabels = ['building number', 'building no', 'رقم المبنى', 'رقم المبني'];
const _streetLabels = ['street name', 'street', 'اسم الشارع', 'الشارع'];
const _districtLabels = ['district', 'neighborhood', 'neighbourhood', 'الحي'];
const _cityLabels = ['city', 'المدينة'];
const _postalLabels = ['postal code', 'zip code', 'postcode', 'الرمز البريدي'];
const _additionalLabels = ['additional number', 'additional no', 'secondary number', 'الرقم الإضافي', 'الرقم الاضافي'];

const _allLabels = [
  ..._crLabels, ..._buildingLabels, ..._streetLabels, ..._districtLabels, ..._cityLabels, ..._postalLabels,
  ..._additionalLabels, 'short address', 'العنوان المختصر', 'vat', 'tax', 'الرقم الضريبي', 'رقم التسجيل الضريبي',
];

/// Reads a document's text. Every field is looked for in every document (a
/// VAT certificate also carries the address).
DocFields parseDocText(String raw) {
  final text = normalizeDocText(raw);
  final lines = [
    for (final l in text.split(RegExp(r'[\r\n]+'))) if (l.trim().isNotEmpty) l.trim(),
  ];
  // Numbers printed in groups ("300 1234 5678 9003") joined up.
  final joined = text.replaceAllMapped(RegExp(r'(\d)[ \-](?=\d)'), (m) => m[1]!);

  final vat = RegExp(r'(?<!\d)3\d{13}3(?!\d)').firstMatch(joined)?[0];

  String? crNumber = _labelled(lines, _crLabels, number: RegExp(r'(?<!\d)([1-7]\d{9})(?!\d)'));
  if (crNumber == null) {
    // Unlabelled: any 10-digit number that isn't a phone (05…) or part of the
    // VAT number; classic CR numbers (1–5…) before unified ones (7…).
    final all = [
      for (final m in RegExp(r'(?<!\d)([1-7]\d{9})(?!\d)').allMatches(text)) m[1]!,
    ].where((n) => vat == null || !vat.contains(n)).toList();
    crNumber = all.where((n) => !n.startsWith('7')).firstOrNull ?? all.firstOrNull;
  }

  final short = RegExp(r'(?<![A-Za-z])([A-Z]{4}\d{4})(?!\d)').firstMatch(text)?[1];
  return DocFields(
    vat: vat,
    crNumber: crNumber,
    buildingNumber: _labelled(lines, _buildingLabels, number: _digits(4)),
    street: _labelled(lines, _streetLabels),
    district: _labelled(lines, _districtLabels),
    city: switch (_labelled(lines, _cityLabels)) {
      final c? => _knownCity(c) ?? c,
      null => _knownCity(text),
    },
    postalCode: _labelled(lines, _postalLabels, number: _digits(5)),
    additionalNumber: _labelled(lines, _additionalLabels, number: _digits(4)),
    shortAddress: short,
  );
}

RegExp _digits(int n) => RegExp('(?<!\\d)(\\d{$n})(?!\\d)');

/// Words that are parts of labels, never values.
const _labelWords = {'name', 'number', 'no', 'code', 'address', 'short', 'اسم', 'رقم'};

final _latinWord = RegExp(r'[A-Za-z]');
final _arabicWord = RegExp(r'[\u0621-\u064A]');

/// The value next to one of [labels] (a [number] match, else a name): after
/// the label up to the next colon, before it (back to the previous colon), or
/// on the next / previous line. A name is kept in the label's script, since
/// bilingual lines hold both. RTL lines come out of PDFs with English runs
/// in reverse word order ("Road Fahd King :Name Street"), so multi-word
/// English labels are also looked for reversed; their value stands before
/// them, reversed too.
String? _labelled(List<String> lines, List<String> labels, {RegExp? number}) {
  final forms = <(String, bool)>[
    for (final l in labels) (l, false),
    for (final l in labels)
      if (l.contains(' ') && _latinWord.hasMatch(l)) (l.split(' ').reversed.join(' '), true),
  ]..sort((a, b) {
      // English labels first (addresses are kept in English), longest first.
      final latin = (_latinWord.hasMatch(a.$1) ? 0 : 1).compareTo(_latinWord.hasMatch(b.$1) ? 0 : 1);
      return latin != 0 ? latin : b.$1.length.compareTo(a.$1.length);
    });
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lower = line.toLowerCase();
    for (final (label, reversed) in forms) {
      final at = _labelIndex(lower, label);
      if (at < 0) continue;
      final after = _segment(line.substring(at + label.length), forward: true);
      final before = _segment(line.substring(0, at), forward: false);
      final candidates = [
        if (reversed) ...[before, after] else ...[after, before],
        if (i + 1 < lines.length) _clean(lines[i + 1]),
        if (i > 0) _clean(lines[i - 1]),
      ];
      for (final c in candidates) {
        if (c.isEmpty || _isLabel(c)) continue;
        if (number != null) {
          final m = number.firstMatch(c);
          if (m != null) return m[1];
          continue;
        }
        final latin = _latinWord.hasMatch(label);
        var words = [
          for (final w in c.split(' '))
            if ((latin ? _latinWord : _arabicWord).hasMatch(w) && !RegExp(r'\d').hasMatch(w)) w,
        ];
        if (reversed) words = words.reversed.toList();
        final value = words.join(' ').trim();
        if (value.length >= 2 && value.length <= 60 && !_labelWords.contains(value.toLowerCase()) && !_isLabel(value)) {
          return value;
        }
      }
    }
  }
  return null;
}

/// The part of [s] that belongs to the label next to it: up to the next
/// colon going [forward], back to the previous colon otherwise.
String _segment(String s, {required bool forward}) {
  final c = _clean(s);
  final parts = c.split(RegExp(r'[:：]'));
  return _clean(forward ? parts.first : parts.last);
}

/// Where [label] stands as a whole word in [lower], or -1.
int _labelIndex(String lower, String label) {
  var from = 0;
  while (true) {
    final at = lower.indexOf(label, from);
    if (at < 0) return -1;
    final before = at == 0 ? '' : lower[at - 1];
    final end = at + label.length;
    final after = end >= lower.length ? '' : lower[end];
    bool letter(String c) => c.isNotEmpty && RegExp(r'[a-zء-ي]').hasMatch(c);
    if (!letter(before) && !letter(after)) return at;
    from = at + 1;
  }
}

String _clean(String s) => s.replaceAll(RegExp(r'^[\s:：\-–|/.]+|[\s:：\-–|/]+$'), '').replaceAll(RegExp(r'\s+'), ' ');

bool _isLabel(String s) {
  final lower = s.toLowerCase();
  return _allLabels.any((l) => lower == l || (lower.startsWith(l) && lower.length < l.length + 3));
}

/// A Saudi city named anywhere in the text, as its English name.
String? _knownCity(String text) {
  final lower = text
      .toLowerCase()
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي');
  for (final (names, _, _) in saudiCities) {
    if (names.any((n) => _labelIndex(lower, n) >= 0)) {
      return names.first.split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  }
  return null;
}
