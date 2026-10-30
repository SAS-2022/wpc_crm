import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/saving.dart';

// Page access (user request 2026-10-23): App settings → Page access, where
// the sales manager / GM choose per role which pages it may open. Each page
// lists the roles that can have it at all ([AppPage.possible]): the data
// behind a page is protected by the security rules, so giving e.g. drivers
// the Clients page would only show an empty page — those combinations are
// not offered. Default = every possible role (the app as it was). Firestore
// `settings/pageAccess` {off: {page: [role values]}} stores only what was
// turned off, so new pages and roles start on.

enum AppPage {
  clients(['/clients'], {_exec, _kam, _sm, _gm}),
  map(['/map'], {_exec, _kam, _sm, _gm}),
  visits(['/visits'], {_exec, _kam, _sm, _gm}),
  teamPlans(['/team-plans'], {_kam, _sm, _gm}),
  reports(['/reports'], {_kam, _sm, _gm}),
  transfers(['/transfers'], {_kam, _sm, _gm}),
  liveTracking(['/live'], {_kam, _sm, _gm}),
  routeHistory(['/history'], {_kam, _sm, _gm, _lm, _ws}),
  drivers(['/drivers'], {_sm, _gm, _lm, _ws}),
  vehicles(['/vehicles'], {_sm, _gm, _lm}),
  attendance(['/attendance'], {_hr, _gm, _sm, _kam, _lm, _ws, _fm}),
  hrArea(['/hr'], {_hr, _gm, _sm}),
  users(['/users'], {_sm, _gm, _lm}),
  importClients(['/import'], {_sm, _gm}),

  /// Never turned off for SM / GM ([locked]): nobody can lock themselves out.
  settings(['/settings', '/work-hours', '/work-sites', '/companies', '/visit-rules', '/given-items', '/client-tags',
      '/location-types'], {_sm, _gm});

  const AppPage(this.paths, this.possible);

  /// The page's path and the pages opened from it.
  final List<String> paths;

  /// The roles that can have it (the data rules allow it).
  final Set<UserRole> possible;

  /// Always on for this role.
  bool locked(UserRole role) => this == settings && possible.contains(role);

  /// The page [location] belongs to, if it's one of these.
  static AppPage? forLocation(String location) {
    for (final p in values) {
      for (final path in p.paths) {
        if (location == path || location.startsWith('$path/')) return p;
      }
    }
    return null;
  }
}

const _exec = UserRole.salesExec;
const _kam = UserRole.kam;
const _sm = UserRole.salesManager;
const _gm = UserRole.gm;
const _hr = UserRole.hr;
const _lm = UserRole.logisticsManager;
const _fm = UserRole.factoryManager;
const _ws = UserRole.warehouseSupervisor;

class PageAccess {
  const PageAccess(this.off);

  /// Default: every page on for every role that can have it.
  static const defaults = PageAccess({});

  /// Turned-off roles per page.
  final Map<AppPage, Set<UserRole>> off;

  bool allows(UserRole role, AppPage page) =>
      page.possible.contains(role) && (page.locked(role) || !(off[page]?.contains(role) ?? false));

  /// [user] may open [page]. People marked "Is a manager" always see their
  /// team's attendance (it follows the person, not the role).
  bool allowsUser(AppUser user, AppPage page) =>
      allows(user.role, page) || (page == AppPage.attendance && user.markedManager);

  /// Whether [user] may open [location] (pages not listed here: yes).
  bool allowsLocation(AppUser user, String location) {
    final page = AppPage.forLocation(location);
    return page == null || allowsUser(user, page);
  }

  PageAccess turned(AppPage page, UserRole role, bool on) {
    final roles = {...?off[page]};
    on ? roles.remove(role) : roles.add(role);
    return PageAccess({...off, page: roles}..removeWhere((_, v) => v.isEmpty));
  }

  static PageAccess fromMap(Object? data) {
    final offMap = data is Map ? data['off'] : null;
    if (offMap is! Map) return defaults;
    final pages = AppPage.values.asNameMap();
    return PageAccess({
      for (final e in offMap.entries)
        if (pages[e.key] case final page? when e.value is List)
          page: {
            for (final v in e.value as List)
              if (UserRole.fromValue('$v') case final r when r != UserRole.unknown) r,
          },
    });
  }

  Map<String, Object> toMap() => {
        'off': {for (final e in off.entries) e.key.name: [for (final r in e.value) r.value]},
      };
}

final _doc = FirebaseFirestore.instance.collection('settings').doc('pageAccess');

/// Read by every active user (settings rules); defaults until saved.
final pageAccessProvider = StreamProvider<PageAccess>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true ? u.value!.id : null));
  if (uid == null) return Stream.value(PageAccess.defaults);
  return _doc.snapshots().map((s) => PageAccess.fromMap(s.data()));
});

Future<void> savePageAccess(PageAccess access) => saving(() => _doc.set(access.toMap()));
