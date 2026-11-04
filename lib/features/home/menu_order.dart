// Side menu order (web, 2026-11-04, user request): each person drags the
// entries into their own order, saved as `users/{uid}.menuOrder` (paths).

/// [paths] (the menu in its default order, only the entries the person may
/// open) in the person's [saved] order. Saved paths no longer in the menu
/// are dropped; entries missing from [saved] (new pages, or a page turned on
/// later) go right after the entry they follow by default, so they show up
/// where they would have been.
List<String> orderMenu(List<String> paths, List<String>? saved) {
  if (saved == null || saved.isEmpty) return List.of(paths);
  final available = paths.toSet();
  final result = <String>[
    for (final p in saved.toSet())
      if (available.contains(p)) p,
  ];
  for (final (i, p) in paths.indexed) {
    if (result.contains(p)) continue;
    // After the nearest default predecessor already placed, else first.
    var at = 0;
    for (var j = i - 1; j >= 0; j--) {
      final k = result.indexOf(paths[j]);
      if (k >= 0) {
        at = k + 1;
        break;
      }
    }
    result.insert(at, p);
  }
  return result;
}

/// The order to save after a reorder: [shown] (the menu as the person sees
/// it now) plus saved paths they can't see at the moment (e.g. a page turned
/// off for their role), so turning it on again keeps its place. Null when
/// it's the default order (nothing to save).
List<String>? menuOrderToSave(List<String> shown, List<String> defaults, List<String>? saved) {
  final hidden = [
    for (final p in saved ?? const <String>[])
      if (!shown.contains(p)) p,
  ];
  if (hidden.isEmpty && _same(shown, defaults)) return null;
  return [...shown, ...hidden];
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
