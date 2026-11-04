import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/home/menu_order.dart';

void main() {
  const menu = ['/', '/clients', '/map', '/visits', '/more'];

  test('no saved order = default', () {
    expect(orderMenu(menu, null), menu);
    expect(orderMenu(menu, const []), menu);
  });

  test('saved order is used', () {
    expect(orderMenu(menu, const ['/more', '/visits', '/', '/map', '/clients']),
        ['/more', '/visits', '/', '/map', '/clients']);
  });

  test('paths gone from the menu are dropped, duplicates ignored', () {
    expect(orderMenu(menu, const ['/visits', '/reports', '/visits', '/', '/clients', '/map', '/more']),
        ['/visits', '/', '/clients', '/map', '/more']);
  });

  test('new entries go after their default predecessor', () {
    // '/map' and '/more' not saved: '/map' after '/clients', '/more' after '/visits'.
    expect(orderMenu(menu, const ['/visits', '/clients', '/']), ['/visits', '/more', '/clients', '/map', '/']);
    // A new first entry goes first.
    expect(orderMenu(menu, const ['/more', '/clients']).first, '/');
  });

  test('order to save keeps hidden saved paths and is null for the default', () {
    expect(menuOrderToSave(menu, menu, null), isNull);
    expect(menuOrderToSave(['/clients', '/', '/map', '/visits', '/more'], menu, null),
        ['/clients', '/', '/map', '/visits', '/more']);
    expect(menuOrderToSave(menu, menu, const ['/reports', '/']), [...menu, '/reports']);
  });
}
