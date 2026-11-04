// Text folding for search boxes (2026-11-03, user: searches found nothing
// when typing Arabic). Typed Arabic rarely matches the stored text letter
// for letter: hamza forms (أ إ آ ا), ة / ه, ى / ي, harakat, tatweel, and
// Arabic-Indic digits (٠١٢) from Arabic keyboards. Both sides are folded the
// same way. Not used for stored keys (`nameKey`), only for matching.

/// [s] folded for searching: lower case, Arabic letter forms unified,
/// harakat / tatweel dropped, Arabic-Indic digits as 0–9, spaces collapsed.
String foldSearch(String s) => foldSearchMapped(s).$1.trim();

/// [foldSearch] without the trim, plus for each folded character the index
/// of the character it came from in [s] (to highlight matches in [s]).
(String, List<int>) foldSearchMapped(String s) {
  final out = StringBuffer();
  final at = <int>[];
  var space = false;
  for (var i = 0; i < s.length; i++) {
    final c = _fold(s.codeUnitAt(i));
    if (c == null) continue;
    final isSpace = c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0;
    if (isSpace) {
      if (space) continue;
      space = true;
      out.writeCharCode(0x20);
    } else {
      space = false;
      out.writeCharCode(c);
    }
    at.add(i);
  }
  return (out.toString(), at);
}

/// The digits in [s] (Arabic-Indic digits included, as 0–9).
String searchDigits(String s) => foldSearch(s).replaceAll(RegExp(r'\D'), '');

/// One UTF-16 unit folded; null = dropped.
int? _fold(int c) {
  if (c >= 0x41 && c <= 0x5A) return c + 0x20; // A–Z
  if (c < 0x80) return c;
  if (c >= 0x660 && c <= 0x669) return 0x30 + c - 0x660; // ٠–٩
  if (c >= 0x6F0 && c <= 0x6F9) return 0x30 + c - 0x6F0; // ۰–۹ (Persian)
  if ((c >= 0x64B && c <= 0x65F) || c == 0x670 || c == 0x640) return null; // harakat, tatweel
  switch (c) {
    case 0x623 || 0x625 || 0x622 || 0x671: // أ إ آ ٱ
      return 0x627; // ا
    case 0x629: // ة
      return 0x647; // ه
    case 0x649 || 0x6CC || 0x626: // ى ی ئ
      return 0x64A; // ي
    case 0x624: // ؤ
      return 0x648; // و
    case 0x6A9: // ک
      return 0x643; // ك
  }
  final lower = String.fromCharCode(c).toLowerCase();
  return lower.length == 1 ? lower.codeUnitAt(0) : c;
}

/// Whether [text] contains [query], both compared folded ([foldSearch]).
/// [query] may be folded already.
bool searchHas(String text, String query) => query.isEmpty || foldSearch(text).contains(foldSearch(query));
