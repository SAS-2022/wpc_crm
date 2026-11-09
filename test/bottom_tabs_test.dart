import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/home/bottom_tabs.dart';

void main() {
  const defaults = ['/', '/clients', '/visits'];
  const available = ['/', '/clients', '/map', '/visits', '/attendance', '/attendance/map', '/live'];

  test('resolve: saved tabs still available, max 4, More never in the list', () {
    expect(resolveBottomTabs(saved: null, available: available, defaults: defaults), defaults);
    expect(resolveBottomTabs(saved: ['/map', '/live'], available: available, defaults: defaults), ['/map', '/live']);
    expect(
      resolveBottomTabs(
        saved: ['/', '/map', '/visits', '/live', '/attendance'],
        available: available,
        defaults: defaults,
      ),
      ['/', '/map', '/visits', '/live'],
    );
    expect(resolveBottomTabs(saved: ['/more', '/map', '/map', '/reports'], available: available, defaults: defaults), [
      '/map',
    ]);
    // Nothing left (Page access turned it off) → defaults.
    expect(resolveBottomTabs(saved: ['/reports'], available: available, defaults: defaults), defaults);
  });

  test('save null for the default', () {
    expect(bottomTabsToSave(defaults, defaults), isNull);
    expect(bottomTabsToSave(['/map'], defaults), ['/map']);
  });

  test('selected tab by longest prefix, else More', () {
    const tabs = ['/', '/attendance', '/attendance/map', '/clients'];
    expect(tabIndexFor('/', tabs), 0);
    expect(tabIndexFor('/plan/u1', tabs), 0);
    expect(tabIndexFor('/attendance', tabs), 1);
    expect(tabIndexFor('/attendance/report', tabs), 1);
    expect(tabIndexFor('/attendance/map', tabs), 2);
    expect(tabIndexFor('/clients/abc/edit', tabs), 3);
    expect(tabIndexFor('/more', tabs), 4);
    expect(tabIndexFor('/profile', tabs), 4);
    expect(tabIndexFor('/map', tabs), 4);
  });

  test('swipe only with the default branch tabs', () {
    expect(canSwipeTabs(defaults), isTrue);
    expect(canSwipeTabs(['/', '/map', '/visits']), isFalse);
    expect(canSwipeTabs(['/', '/clients']), isFalse);
  });
}
