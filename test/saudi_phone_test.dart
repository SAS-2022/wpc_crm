import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/saudi_phone.dart';

void main() {
  test('reads the usual ways of writing a Saudi mobile', () {
    for (final raw in ['501234567', '0501234567', '050 123 4567', '966501234567', '+966 50 123 4567', '00966501234567', '٠٥٠١٢٣٤٥٦٧']) {
      expect(saudiMobile(raw), '+966501234567', reason: raw);
    }
  });

  test('refuses other numbers', () {
    for (final raw in ['', '0112345678', '50123456', '5012345678', '+971501234567', '+9660501234567x1', '12345']) {
      expect(saudiMobile(raw), isNull, reason: raw);
    }
  });

  test('field text: 9 digits for a Saudi mobile, old value otherwise', () {
    expect(saudiMobileFieldText('+966501234567'), '501234567');
    expect(saudiMobileFieldText('+971501234567'), '+971501234567');
    expect(saudiMobileFieldText(''), '');
  });
}
