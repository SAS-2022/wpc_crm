import '../clients/client_documents.dart' show normalizeDocText;

// Employment contract → salary parts (user request 2026-11-13): HR or the
// payroll account uploads an employee's contract; its text is read on the
// device (PDF text layer / ML Kit on phones, `document_text.dart`) and parsed
// here into the payroll fields (basic, home allowance, transportation, other
// allowances), shown for review before they're saved.

/// One amount found in the contract, monthly SAR. [note] says how it was
/// worked out when it wasn't written as a monthly figure.
class ContractAmount {
  const ContractAmount(this.amount, {this.note = ContractNote.none});

  final double amount;
  final ContractNote note;
}

enum ContractNote {
  none,

  /// Written as a yearly amount, divided by 12.
  yearly,

  /// Written as a percentage of the basic salary.
  percentOfBasic,
}

/// What a contract says about pay. Null / empty = not found.
class ContractPay {
  const ContractPay({this.basic, this.housing, this.transport, this.others = const [], this.total});

  final ContractAmount? basic;
  final ContractAmount? housing;
  final ContractAmount? transport;
  final List<({String name, ContractAmount amount})> others;

  /// The contract's own total (only used to check the parts).
  final double? total;

  bool get isEmpty => basic == null && housing == null && transport == null && others.isEmpty;

  double get partsTotal =>
      (basic?.amount ?? 0) + (housing?.amount ?? 0) + (transport?.amount ?? 0) + others.fold(0.0, (a, o) => a + o.amount.amount);

  /// The contract states a total that the parts found don't add up to.
  bool get totalMismatch => total != null && !isEmpty && (total! - partsTotal).abs() > 1;
}

const _basicLabels = [
  'basic monthly salary', 'monthly basic salary', 'basic salary', 'basic wage', 'basic pay', 'base salary',
  'الراتب الأساسي', 'الراتب الاساسي', 'الأجر الأساسي', 'الاجر الاساسي', 'الأجر الاساسي', 'الاجر الأساسي',
  'راتب أساسي', 'راتب اساسي', 'أجر أساسي', 'اجر اساسي',
];
const _housingLabels = [
  'housing allowance', 'accommodation allowance', 'home allowance', 'housing',
  'بدل السكن', 'بدل سكن', 'بدل الإسكان', 'بدل الاسكان',
];
const _transportLabels = [
  'transportation allowance', 'transport allowance', 'transportation', 'transport',
  'بدل النقل', 'بدل نقل', 'بدل المواصلات', 'بدل مواصلات', 'بدل الانتقال', 'بدل انتقال',
];
const _totalLabels = [
  'total monthly salary', 'total salary', 'gross salary', 'total wage', 'total monthly wage', 'total package',
  'إجمالي الراتب', 'اجمالي الراتب', 'إجمالي الأجر', 'اجمالي الاجر', 'الراتب الإجمالي', 'الراتب الاجمالي',
  'الأجر الإجمالي', 'الاجر الاجمالي', 'المجموع', 'الإجمالي', 'الاجمالي',
];

/// "Phone allowance", "Other allowances", "بدل اتصال", "بدلات أخرى".
final _otherEnglish = RegExp(r"\b((?:[a-z][a-z'&/\-]*\s){0,2}?[a-z][a-z'&/\-]*)\s+allowances?\b");
final _otherArabic = RegExp(r'(بدل(?:ات)?\s+(?:ال)?[ء-ي]+(?:\s+(?:ال)?[ء-ي]+)?)');

/// Words before "allowance" that start a sentence, not a name.
const _notNames = {
  'the', 'an', 'a', 'and', 'or', 'of', 'any', 'monthly', 'with', 'plus', 'per', 'his', 'her', 'their', 'such', 'this',
  'following', 'total', 'all', 'no', 'to', 'by', 'for', 'is', 'are', 'be', 'will', 'shall', 'receive', 'paid',
};
const _yearly = ['annual', 'per year', 'yearly', 'a year', 'per annum', 'سنوي', 'سنويا', 'سنوياً', 'في السنة'];

// Amounts: "5,000", "5000.00", "5 000"; dates and percentages are dropped
// before looking.
final _amount = RegExp(r'(?<![\d.])(\d{1,3}(?:[, ]\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)(?![\d%])');
final _date = RegExp(r'\d{1,4}[/\-.]\d{1,2}[/\-.]\d{1,4}');
final _percent = RegExp(r'(\d+(?:\.\d+)?)\s*%|%\s*(\d+(?:\.\d+)?)');

/// Reads the pay parts of an employment contract (English, Arabic or both).
ContractPay parseContractText(String raw) {
  final text = normalizeDocText(raw).replaceAll('٬', ',').replaceAll('٫', '.');
  final lines = [
    for (final l in text.split(RegExp(r'[\r\n]+'))) if (l.trim().isNotEmpty) l.trim().replaceAll(RegExp(r'\s+'), ' '),
  ];

  // Every label found, per line, so each value is cut off at the next label.
  final found = <_Hit>[];
  for (var i = 0; i < lines.length; i++) {
    final lower = lines[i].toLowerCase();
    final taken = <(int, int)>[];
    bool free(int s, int e) => taken.every((t) => e <= t.$1 || s >= t.$2);
    void add(_Kind kind, int start, int end, [String name = '']) {
      if (!free(start, end)) return;
      taken.add((start, end));
      found.add(_Hit(kind, i, start, end, name));
    }

    for (final (kind, labels) in [
      (_Kind.total, _totalLabels),
      (_Kind.basic, _basicLabels),
      (_Kind.housing, _housingLabels),
      (_Kind.transport, _transportLabels),
    ]) {
      for (final l in [...labels]..sort((a, b) => b.length.compareTo(a.length))) {
        for (final at in _labelIndexes(lower, l)) {
          add(kind, at, at + l.length);
        }
      }
    }
    for (final m in _otherEnglish.allMatches(lower)) {
      // Drop leading words that aren't part of the name ("a monthly phone allowance").
      final words = lines[i].substring(m.start, m.end).split(' ');
      final skip = words.takeWhile((w) => _notNames.contains(w.toLowerCase())).length;
      if (skip >= words.length - 1) continue;
      add(_Kind.other, m.start, m.end, _tidyName(words.skip(skip).join(' ')));
    }
    for (final m in _otherArabic.allMatches(lines[i])) {
      add(_Kind.other, m.start, m.end, m[1]!.trim());
    }
  }
  found.sort((a, b) => a.line != b.line ? a.line.compareTo(b.line) : a.start.compareTo(b.start));

  final hitsByLine = <int, List<_Hit>>{};
  for (final h in found) {
    hitsByLine.putIfAbsent(h.line, () => []).add(h);
  }

  ContractAmount? basic, housing, transport;
  double? total;
  final others = <({String name, ContractAmount amount})>[];
  double? housingPercent, transportPercent;
  final otherPercents = <String, double>{};

  for (final h in found) {
    final line = lines[h.line];
    final hits = hitsByLine[h.line]!;
    final index = hits.indexOf(h);
    final nextStart = index + 1 < hits.length ? hits[index + 1].start : line.length;
    final prevEnd = index > 0 ? hits[index - 1].end : 0;
    final after = line.substring(h.end, nextStart);
    final before = line.substring(prevEnd, h.start);
    final yearly = _yearly.any((w) => after.toLowerCase().contains(w) || before.toLowerCase().contains(w));

    // A percentage of the basic salary ("25% of the basic salary").
    final pct = _percent.firstMatch(after);
    if (pct != null && h.kind != _Kind.basic && h.kind != _Kind.total && _amountIn(after) == null) {
      final p = double.parse(pct[1] ?? pct[2]!);
      if (p > 0 && p <= 100) {
        switch (h.kind) {
          case _Kind.housing:
            housingPercent ??= p;
          case _Kind.transport:
            transportPercent ??= p;
          case _Kind.other:
            otherPercents.putIfAbsent(h.name, () => p);
          default:
        }
        continue;
      }
    }

    // After the label, else before it (RTL lines come out reversed), else
    // the next line (a table: label above value) when that line has no label.
    var value = _amountIn(after) ?? (index == 0 ? _amountIn(before) : null);
    if (value == null && h.line + 1 < lines.length && !hitsByLine.containsKey(h.line + 1) && index == hits.length - 1) {
      value = _amountIn(lines[h.line + 1]);
    }
    if (value == null) continue;
    final amount = yearly ? ContractAmount(_round(value / 12), note: ContractNote.yearly) : ContractAmount(value);
    switch (h.kind) {
      case _Kind.basic:
        basic ??= amount;
      case _Kind.housing:
        housing ??= amount;
      case _Kind.transport:
        transport ??= amount;
      case _Kind.total:
        total ??= amount.amount;
      case _Kind.other:
        if (others.every((o) => o.name.toLowerCase() != h.name.toLowerCase())) others.add((name: h.name, amount: amount));
    }
  }

  if (basic != null) {
    ContractAmount pctOf(double p) => ContractAmount(_round(basic!.amount * p / 100), note: ContractNote.percentOfBasic);
    if (housing == null && housingPercent != null) housing = pctOf(housingPercent);
    if (transport == null && transportPercent != null) transport = pctOf(transportPercent);
    for (final e in otherPercents.entries) {
      if (others.every((o) => o.name.toLowerCase() != e.key.toLowerCase())) others.add((name: e.key, amount: pctOf(e.value)));
    }
  }

  // Bilingual contracts name each allowance twice: keep the English name when
  // an Arabic one has the same amount.
  final kept = <({String name, ContractAmount amount})>[];
  for (final o in others) {
    final arabic = !RegExp(r'[A-Za-z]').hasMatch(o.name);
    final twin = others.any((p) => p != o && p.amount.amount == o.amount.amount && RegExp(r'[A-Za-z]').hasMatch(p.name));
    if (arabic && twin) continue;
    kept.add(o);
  }
  return ContractPay(basic: basic, housing: housing, transport: transport, others: kept, total: total);
}

enum _Kind { basic, housing, transport, other, total }

class _Hit {
  _Hit(this.kind, this.line, this.start, this.end, this.name);

  final _Kind kind;
  final int line;
  final int start;
  final int end;
  final String name;
}

/// Where [label] stands as whole words in [lower].
Iterable<int> _labelIndexes(String lower, String label) sync* {
  var from = 0;
  while (true) {
    final at = lower.indexOf(label, from);
    if (at < 0) return;
    from = at + 1;
    final beforeOk = at == 0 || !RegExp(r'[a-zء-ي]').hasMatch(lower[at - 1]);
    final end = at + label.length;
    // English labels may be followed by "s" / ":" etc., not more letters.
    final afterOk = end >= lower.length || !RegExp(r'[a-zء-ي]').hasMatch(lower[end]);
    if (beforeOk && afterOk) yield at;
  }
}

/// The first amount in [s] (≥ 1 SAR), ignoring dates and percentages.
double? _amountIn(String s) {
  final clean = s.replaceAll(_date, ' ').replaceAll(_percent, ' ');
  for (final m in _amount.allMatches(clean)) {
    final v = double.tryParse(m[1]!.replaceAll(RegExp(r'[, ]'), ''));
    if (v != null && v >= 1) return v;
  }
  return null;
}

String _tidyName(String s) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

double _round(double v) => (v * 100).roundToDouble() / 100;
