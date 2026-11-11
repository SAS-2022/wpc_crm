import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client_required.dart';

void main() {
  final full = <String, dynamic>{
    'name': 'Master Craft',
    'tagIds': ['factory'],
    'contactPerson': 'Abu Ahmed',
    'phone': '',
    'mobile': '0505904368',
    'lat': 24.8,
    'lng': 46.6,
  };

  test('a complete client misses nothing', () {
    expect(missingClientFields(full), isEmpty);
    expect(missingClientFields({...full, 'phone': '011 435 9633', 'mobile': ''}), isEmpty);
  });

  test('lists every missing field', () {
    expect(missingClientFields({'name': '  ', 'tagIds': <String>[], 'contactPerson': '', 'phone': ' ', 'mobile': '', 'lat': null, 'lng': null}),
        RequiredClientField.values);
    expect(missingClientFields({}), RequiredClientField.values);
    expect(missingClientFields({...full, 'lng': null}), [RequiredClientField.location]);
  });

  test('an extra location stands in for cleared main coordinates', () {
    expect(missingClientFields({...full, 'lat': null, 'lng': null}, hasOtherLocation: true), isEmpty);
  });
}
