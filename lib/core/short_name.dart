/// Short labels for company and work-site chips on the Employee Map (user
/// 2026-11-08): "Wood Panels Co" → "WPC", "Wood Panels Service Center" →
/// "WPSC". The first letter of each word (numbers kept whole, "and", "&",
/// "of", "the" left out); names of one word or up to 6
/// letters stay as they are, and so do Arabic names (separate Arabic
/// letters don't read as an abbreviation).
String abbreviate(String name) {
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(name)) return name.trim();
  final words = name.trim().split(RegExp(r'[\s\-_/,.()]+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 2 || name.trim().length <= 6) return name.trim();
  const skip = {'and', '&', 'of', 'the'};
  final b = StringBuffer();
  for (final w in words) {
    if (skip.contains(w.toLowerCase())) continue;
    if (RegExp(r'^\d+$').hasMatch(w)) {
      b.write(w);
    } else {
      b.write(String.fromCharCodes(w.runes.take(1)).toUpperCase());
    }
  }
  return b.isEmpty ? name.trim() : b.toString();
}

/// [abbreviate] for every name; names whose short forms clash keep their
/// full name, so two chips never read the same.
Map<String, String> shortLabels(Map<String, String> names) {
  final short = {for (final e in names.entries) e.key: abbreviate(e.value)};
  final uses = <String, int>{};
  for (final s in short.values) {
    uses[s.toUpperCase()] = (uses[s.toUpperCase()] ?? 0) + 1;
  }
  return {
    for (final e in short.entries) e.key: (uses[e.value.toUpperCase()] ?? 0) > 1 ? names[e.key]!.trim() : e.value,
  };
}
