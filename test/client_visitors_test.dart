import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/saudi_cities.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/client_tags.dart';
import 'package:wpc_crm/features/clients/client_visitors.dart';
import 'package:wpc_crm/features/clients/client_locations_section.dart' show locationLabel;
import 'package:wpc_crm/l10n/app_localizations_en.dart';
import 'package:wpc_crm/features/visits/visit.dart';
import 'package:wpc_crm/features/visits/visit_place.dart';

const _dammam = ClientLocation(id: 'l2', typeId: 'showroom', lat: 26.452189, lng: 50.073268);
const _madinah = ClientLocation(id: 'l3', typeId: 'showroom', lat: 24.482846, lng: 39.651171, address: 'King Abdullah Rd');

Client _client({List<VisitAssignment> visitors = const [], Set<String>? only}) => Client(
      id: 'c1', vat: '', nameKey: 'k', name: 'Kitchen Co', aliases: const [], phone: '', mobile: '', address: '',
      city: '', tags: '', odooSalesperson: '', googlePin: '', lat: 24.603121, lng: 46.768475, assignedTo: 'eddy',
      category: 'B', lastVisitAt: null, extraLocations: const [_dammam, _madinah],
      visitAssignments: visitors, onlyLocationIds: only,
    );

extension on Client {
  Client copyWithLocations(ClientLocation extra) => Client(
        id: id, vat: '', nameKey: nameKey, name: name, aliases: const [], phone: '', mobile: '', address: '',
        city: '', tags: '', odooSalesperson: '', googlePin: '', lat: lat, lng: lng, assignedTo: assignedTo,
        category: 'B', lastVisitAt: null, extraLocations: [...extraLocations, extra],
      );
}

Client _c(String id, {String? parent, List<VisitAssignment> visitors = const []}) => Client(
      id: id, vat: '', nameKey: id, name: id, aliases: const [], phone: '', mobile: '', address: '',
      city: '', tags: '', odooSalesperson: '', googlePin: '', lat: 21.5, lng: 39.2, assignedTo: 'mo',
      category: 'B', lastVisitAt: null, parentId: parent, visitAssignments: visitors,
    );

Visit _visit({String locationId = '', String typeId = '', double? lat, double? lng, VisitType type = VisitType.visit}) =>
    Visit(
      id: 'v1', clientId: 'c1', clientName: 'Kitchen Co', salesExecId: 'ali', checkedInAt: null, notes: '',
      distanceMeters: null, accuracy: null, mocked: false, locationId: locationId, locationTypeId: typeId,
      checkInLat: lat, checkInLng: lng, type: type,
    );

void main() {
  test('a visitor gets only their locations; the owner and others get all', () {
    final c = _client(visitors: const [VisitAssignment(uid: 'ali', locationIds: ['l2'])]);
    expect(isVisitorOf(c, 'ali'), isTrue);
    expect(isVisitorOf(c, 'eddy'), isFalse);
    expect(isVisitorOf(c, 'sami'), isFalse);
    expect(locationsFor(c, 'ali').map((l) => l.id), ['l2']);
    expect(locationsFor(c, 'eddy').map((l) => l.id), ['main', 'l2', 'l3']);
    // No locations chosen = all of them; removed ids are skipped.
    expect(locationsFor(_client(visitors: const [VisitAssignment(uid: 'ali')]), 'ali').length, 3);
    expect(locationsFor(_client(visitors: const [VisitAssignment(uid: 'ali', locationIds: ['gone'])]), 'ali'), isEmpty);
  });

  test('the visitor\'s copy of the client shows only their locations', () {
    final c = _client(only: {'l2'});
    expect(c.locations.map((l) => l.id), ['l2']);
    expect(c.allLocations.length, 3);
  });

  test('saved fields list each person once, with their ids for the rules', () {
    final m = visitAssignmentsUpdate(const [
      VisitAssignment(uid: 'ali', locationIds: ['l2']),
      VisitAssignment(uid: 'omar', locationIds: ['l3']),
      VisitAssignment(uid: 'ali', locationIds: ['l3']),
    ]);
    expect(m['visitorIds'], ['ali', 'omar']);
    expect((m['visitAssignments'] as List).length, 2);
    expect(parseVisitAssignments(m['visitAssignments']).first.locationIds, ['l3']);
  });

  test('nearest city', () {
    expect(nearestSaudiCity(26.452189, 50.073268)?.en, 'Dammam');
    expect(nearestSaudiCity(24.131455, 47.270725)?.en, 'Al Kharj');
    expect(nearestSaudiCity(24.897927, 46.603439)?.en, 'Riyadh');
    expect(nearestSaudiCity(21.60, 39.15)?.ar, 'جدة');
    expect(nearestSaudiCity(22.0, 50.0), isNull); // Empty Quarter
  });

  test('a visit says where it was: label, address and city', () {
    const types = {'showroom': ClientTag(id: 'showroom', en: 'Showroom', ar: 'معرض')};
    final c = _client();
    expect(visitPlace(_visit(locationId: 'l2', typeId: 'showroom'), c, types, 'en'), 'Showroom · Dammam');
    expect(visitPlace(_visit(locationId: 'l3', typeId: 'showroom'), c, types, 'ar'), 'معرض · King Abdullah Rd · المدينة المنورة');
    // Older visit without a location id: the check-in position.
    expect(visitPlace(_visit(lat: 26.45, lng: 50.07), null, types, 'en'), 'Dammam');
    expect(visitPlace(_visit(type: VisitType.call), c, types, 'en'), isNull);
  });

  test('the linked group: main company, its main company and every branch', () {
    final all = [
      _c('top'),
      _c('main', parent: 'top'),
      _c('showroom1', parent: 'main'),
      _c('showroom2', parent: 'main'),
      _c('other', parent: 'top'),
      _c('alone'),
      _c('loopA', parent: 'loopB'),
      _c('loopB', parent: 'loopA'),
    ];
    String ids(Client c) => (linkedGroupOf(c, all).map((x) => x.id).toList()..sort()).join(',');
    expect(ids(all[2]), 'main,other,showroom2,top');
    expect(ids(all[0]), 'main,other,showroom1,showroom2');
    expect(linkedGroupOf(all[5], all), isEmpty);
    expect(ids(all[6]), 'loopB'); // a loop doesn't hang
  });

  test('giving or taking a visitor keeps the others', () {
    final c = _c('x', visitors: const [VisitAssignment(uid: 'ali', locationIds: ['l2']), VisitAssignment(uid: 'omar')]);
    final added = withVisitor(c, 'ali', const [], byId: 'sm');
    expect(added.map((a) => a.uid), ['omar', 'ali']);
    expect(added.last.locationIds, isEmpty);
    expect(withVisitor(c, 'ali', null, byId: 'sm').map((a) => a.uid), ['omar']);
  });

  test('a location name shows after its label and is saved only when set', () {
    final l10n = AppLocalizationsEn();
    const types = {'showroom': ClientTag(id: 'showroom', en: 'Showroom', ar: 'معرض')};
    const named = ClientLocation(id: 'l9', typeId: 'showroom', lat: 24.7, lng: 46.7, name: 'Olaya');
    expect(locationLabel(named, 1, types, 'en', l10n), 'Showroom · Olaya');
    expect(locationLabel(named.copyWith(typeId: ''), 1, types, 'en', l10n), 'Olaya');
    expect(locationLabel(_dammam, 1, types, 'en', l10n), 'Showroom');
    expect(named.toMap()['name'], 'Olaya');
    expect(_dammam.toMap().containsKey('name'), isFalse);
    expect(ClientLocation.fromMap(named.toMap()).name, 'Olaya');
    expect(locationsUpdate([named, _dammam])['mainLocationName'], 'Olaya');
    expect(visitPlace(_visit(locationId: 'l9', typeId: 'showroom'),
        _client().copyWithLocations(named), types, 'en'), 'Showroom · Olaya · Riyadh');
  });

  test('the salesperson filter finds the clients a person visits, with only their locations', () {
    final c = _client(visitors: const [VisitAssignment(uid: 'ali', locationIds: ['l2']), VisitAssignment(uid: 'omar')]);
    expect(matchesOwnerOrVisitor(c, {'ali'}, '_u'), isTrue);
    expect(matchesOwnerOrVisitor(c, {'eddy'}, '_u'), isTrue);
    expect(matchesOwnerOrVisitor(c, {'sami'}, '_u'), isFalse);
    expect(matchesOwnerOrVisitor(c, const {}, '_u'), isTrue);
    expect(locationsForFilter(c, {'ali'}, '_u').map((l) => l.id), ['l2']);
    expect(locationsForFilter(c, {'omar'}, '_u').length, 3); // all locations
    expect(locationsForFilter(c, {'eddy'}, '_u').length, 3);
    expect(locationsForFilter(c, {'ali', 'eddy'}, '_u').length, 3);
    expect(pinPersonFor(c, _dammam, {'ali'}, '_u'), 'ali');
    expect(pinPersonFor(c, _dammam, {'eddy', 'ali'}, '_u'), 'eddy');
    expect(pinPersonFor(c, _madinah, const {}, '_u'), 'eddy');
  });
}
