/// Bottom tabs on phones chosen by each person (2026-11-08, user request):
/// up to [maxChosenTabs] pages of their choice, then More, which is always
/// the last tab and can't be removed — five tabs at most.
library;

/// Tabs besides More.
const maxChosenTabs = 4;

/// The tab branches' first screens (0 Home, 1 Clients, 2 Visits, 3 More):
/// those tabs switch branch and keep their own back stack.
const branchRoots = {'/': 0, '/clients': 1, '/visits': 2, '/more': 3};

/// The tabs to show (More not included): the [saved] ones still [available]
/// (Page access, role), at most [maxChosenTabs]; nothing saved or nothing of
/// it left = [defaults].
List<String> resolveBottomTabs({
  required List<String>? saved,
  required List<String> available,
  required List<String> defaults,
}) {
  if (saved == null) return defaults;
  final ok = available.toSet();
  final seen = <String>{};
  final tabs = [
    for (final p in saved)
      if (p != '/more' && ok.contains(p) && seen.add(p)) p,
  ].take(maxChosenTabs).toList();
  return tabs.isEmpty ? defaults : tabs;
}

/// The value to store: null when [tabs] are the [defaults].
List<String>? bottomTabsToSave(List<String> tabs, List<String> defaults) =>
    _same(tabs, defaults) ? null : List.of(tabs);

/// The selected tab for [location]: the tab whose path is its longest
/// prefix (Home also holds the plan and notification pages); nothing
/// matching = More (index `tabs.length`).
int tabIndexFor(String location, List<String> tabs) {
  var index = tabs.length;
  var best = -1;
  for (final (i, path) in tabs.indexed) {
    final matches = path == '/'
        ? location == '/' || location.startsWith('/plan') || location.startsWith('/notifications')
        : location == path || location.startsWith('$path/');
    if (matches && path.length > best) {
      index = i;
      best = path.length;
    }
  }
  return index;
}

/// Swiping between tabs only works when the tabs are exactly the four
/// branches in their order (Home, Clients, Visits, More).
bool canSwipeTabs(List<String> tabs) => _same(tabs, const ['/', '/clients', '/visits']);

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
