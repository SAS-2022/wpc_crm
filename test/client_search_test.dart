import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/client_search.dart';

Client _client() => const Client(
      id: 'c1', vat: '300123456700003', nameKey: 'al noor showroom', name: 'Al Noor Showroom',
      aliases: ['Noor Trading'], phone: '+966 55 123 4567', mobile: '', address: '', city: 'Riyadh', tags: '',
      odooSalesperson: '', googlePin: '', lat: null, lng: null, assignedTo: 'u1', category: 'B', lastVisitAt: null,
      contactPerson: 'Khalid Saeed', companyId: '1010123456',
      contacts: [ClientContact(name: 'Fahad Omar', phone: '', mobile: '0509876543')],
    );

SearchMatch? find(String q) => searchClient(_client(), ClientQuery(q), salesperson: 'Sami Mansour');

void main() {
  test('name, case-insensitive, with ranges to highlight', () {
    final m = find('NOOR')!;
    expect(m.name!.ranges, [(3, 7)]);
    expect(m.other, isNull);
  });

  test('contact person, contacts, salesperson, VAT and CR', () {
    expect(find('khalid')!.other!.field, SearchField.contactPerson);
    expect(find('fahad')!.other!.field, SearchField.contact);
    expect(find('sami')!.other!.field, SearchField.salesperson);
    expect(find('3001234')!.other!.field, SearchField.vat);
    expect(find('1010123')!.other!.field, SearchField.cr);
  });

  test('phones match on digits, with or without 0 / +966', () {
    final m = find('0551234')!.other!;
    expect(m.field, SearchField.phone);
    // "55 123 4" highlighted in "+966 55 123 4567".
    expect(m.text.substring(m.ranges.single.$1, m.ranges.single.$2), '55 123 4');
    expect(find('050 987')!.other!.text, '0509876543');
  });

  test('no match', () {
    expect(find('zzz'), isNull);
    expect(find(''), isNotNull);
  });
}
