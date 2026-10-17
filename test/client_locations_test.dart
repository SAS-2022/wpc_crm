import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/merge.dart';

Client _client(
  String id, {
  double? lat,
  double? lng,
  String mainType = '',
  List<ClientLocation> extra = const [],
}) =>
    Client(
      id: id,
      vat: '',
      nameKey: id,
      name: id,
      aliases: const [],
      phone: '',
      mobile: '',
      address: '',
      city: '',
      tags: '',
      odooSalesperson: '',
      googlePin: '',
      lat: lat,
      lng: lng,
      assignedTo: null,
      category: 'B',
      lastVisitAt: null,
      mainLocationType: mainType,
      extraLocations: extra,
    );

const _factory = ClientLocation(id: 'f', typeId: 'factory', lat: 24.80, lng: 46.80, address: 'Industrial city');
const _showroom = ClientLocation(id: 's', typeId: 'showroom', lat: 24.70, lng: 46.68);

void main() {
  test('locations: main first, then the extra ones; none without a main location', () {
    final c = _client('c', lat: 24.71, lng: 46.67, mainType: 'office', extra: const [_factory, _showroom]);
    expect([for (final l in c.locations) l.typeId], ['office', 'factory', 'showroom']);
    expect(c.locations.first.isMain, isTrue);
    expect(_client('n', extra: const [_factory]).locations, isEmpty);
  });

  test('nearest location to the phone', () {
    final c = _client('c', lat: 24.71, lng: 46.67, mainType: 'office', extra: const [_factory, _showroom]);
    expect(nearestLocation(c, 24.801, 46.801)?.id, 'f');
    expect(nearestLocation(c, 24.7001, 46.6801)?.id, 's');
    expect(nearestLocation(_client('n'), 24.7, 46.7), isNull);
  });

  test('saving a list: the first is main, the rest extra; old main keeps a new id', () {
    final c = _client('c', lat: 24.71, lng: 46.67, mainType: 'office', extra: const [_factory]);
    // "Make main" on the factory.
    final update = locationsUpdate([_factory, ...c.locations.where((l) => l.id != 'f')]);
    expect(update['lat'], 24.80);
    expect(update['mainLocationType'], 'factory');
    final extra = update['extraLocations'] as List;
    expect(extra.single['typeId'], 'office');
    expect(extra.single['id'], isNot(ClientLocation.mainId));
    // Everything deleted.
    expect(locationsUpdate(const []), {'lat': null, 'lng': null, 'mainLocationType': '', 'extraLocations': []});
  });

  test("merge keeps every location once, the kept client's main first", () {
    final keep = _client('k', lat: 24.71, lng: 46.67, mainType: 'office', extra: const [_factory]);
    final other = _client(
      'o',
      lat: 24.80001, // same place as keep's factory (≈1 m)
      lng: 46.80001,
      mainType: 'factory',
      extra: const [ClientLocation(id: 'f', typeId: 'warehouse', lat: 24.9, lng: 46.9)],
    );
    final update = mergeUpdate(keep, [other], byId: 'gm', at: DateTime(2026, 10, 17));
    expect(update['lat'], 24.71);
    expect(update['mainLocationType'], 'office');
    final extra = [for (final m in update['extraLocations'] as List) m as Map];
    expect([for (final m in extra) m['typeId']], ['factory', 'warehouse']);
    expect({for (final m in extra) m['id']}.length, 2); // ids stay unique
  });
}
