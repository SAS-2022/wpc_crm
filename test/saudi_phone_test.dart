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
    expect(saudiMobileFieldText('+966501234567'), '0501234567');
    expect(saudiMobileFieldText('+971501234567'), '+971501234567');
    expect(saudiMobileFieldText(''), '');
  });

  test('typing: digits only, at most 10, pasted country code becomes 0', () {
    expect(saudiMobileInput('05012345678901'), '0501234567');
    expect(saudiMobileInput('+966 50 123 4567'), '0501234567');
    expect(saudiMobileInput('00966501234567'), '0501234567');
    expect(saudiMobileInput('501234567'), '0501234567');
    expect(saudiMobileInput('٠٥٠ ١٢٣'), '050123');
    expect(saudiMobileInput('05a-1'), '051');
  });
}
