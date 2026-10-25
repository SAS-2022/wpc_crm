import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/add_phone_prompt.dart';
import 'package:wpc_crm/features/clients/client.dart';

Client _client({String phone = '', String mobile = '', List<ClientContact> contacts = const []}) => Client(
      id: 'c1', vat: '', nameKey: 'x', name: 'X', aliases: const [], phone: phone, mobile: mobile, address: '',
      city: '', tags: '', odooSalesperson: '', googlePin: '', lat: null, lng: null, assignedTo: 'u1',
      category: 'B', lastVisitAt: null, contacts: contacts,
    );

void main() {
  test('a client can be reached by its phone, mobile or a contact\'s number', () {
    expect(_client().hasPhoneNumber, isFalse);
    expect(_client(phone: '  ').hasPhoneNumber, isFalse);
    expect(_client(phone: '0112345678').hasPhoneNumber, isTrue);
    expect(_client(mobile: '0501234567').hasPhoneNumber, isTrue);
    expect(_client(contacts: const [ClientContact(name: 'A', phone: '', mobile: '')]).hasPhoneNumber, isFalse);
    expect(_client(contacts: const [ClientContact(name: 'A', phone: '', mobile: '0501234567')]).hasPhoneNumber, isTrue);
  });

  test('numbers from the contact list are cleaned', () {
    expect(cleanPhoneNumber('050 123 4567'), '0501234567');
    expect(cleanPhoneNumber('+966 (50) 123-4567'), '+966501234567');
    expect(cleanPhoneNumber('00966501234567'), '+966501234567');
    expect(isPhoneNumber('050 123 4567'), isTrue);
    expect(isPhoneNumber('12345'), isFalse);
    expect(isPhoneNumber('abc'), isFalse);
  });
}
