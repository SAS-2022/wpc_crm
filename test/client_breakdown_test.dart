import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/client_breakdown.dart';

Client _client(String id, {String type = '', List<String> tags = const []}) => Client(
      id: id, vat: '', nameKey: id, name: id, aliases: const [], phone: '', mobile: '', address: '',
      city: '', tags: '', odooSalesperson: '', googlePin: '', lat: null, lng: null, assignedTo: 'u1',
      category: 'B', lastVisitAt: null, clientType: type, tagIds: tags,
    );

void main() {
  test('clients are counted by type and by tag', () {
    final b = clientBreakdown([
      _client('a', type: clientTypeCompany, tags: ['factory', 'showroom']),
      _client('b', type: clientTypeCompany, tags: ['factory']),
      _client('c', type: clientTypeIndividual),
      _client('d', tags: ['deleted']),
    ], {'factory', 'showroom', 'workshop'});
    expect(b.total, 4);
    expect(b.companies, 2);
    expect(b.individuals, 1);
    expect(b.typeUnset, 1);
    // Most first; a client with two tags counts under both; deleted tags left out.
    expect(b.tags, [('factory', 2), ('showroom', 1)]);
    expect(b.untagged, 2);
  });

  test('no clients = all zero', () {
    final b = clientBreakdown(const [], {'factory'});
    expect(b.total, 0);
    expect(b.tags, isEmpty);
    expect(b.untagged, 0);
  });
}
