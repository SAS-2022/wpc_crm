import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client_documents.dart';

void main() {
  test('VAT certificate: 15-digit number (also spaced or in Arabic digits)', () {
    expect(parseDocText('VAT Registration Number: 300123456700003').vat, '300123456700003');
    expect(parseDocText('رقم التسجيل الضريبي\n300 1234 5670 0003').vat, '300123456700003');
    expect(parseDocText('الرقم الضريبي ٣٠٠١٢٣٤٥٦٧٠٠٠٠٣').vat, '300123456700003');
    expect(parseDocText('Invoice 123456789012345').vat, isNull); // doesn't start and end with 3
  });

  test('CR: labelled number first, else a classic 10-digit number, never a phone', () {
    expect(parseDocText('رقم السجل التجاري: 1010123456\nالرقم الوطني الموحد: 7001234567').crNumber, '1010123456');
    expect(parseDocText('Unified National Number\n7001234567').crNumber, '7001234567');
    expect(parseDocText('Tel 0551234567\nRef 7012345678 / 2050123456').crNumber, '2050123456');
    expect(parseDocText('0551234567').crNumber, isNull);
  });

  test('National Address: bilingual certificate, label then value or value then label', () {
    const text = '''
National Address Certificate
Building Number: 8228
Street Name: King Fahd Road
District: Al Olaya
City: Riyadh
Postal Code: 12214
Additional Number: 3456
Short Address: RRRD8228
''';
    final f = parseDocText(text);
    expect(f.buildingNumber, '8228');
    expect(f.street, 'King Fahd Road');
    expect(f.district, 'Al Olaya');
    expect(f.city, 'Riyadh');
    expect(f.postalCode, '12214');
    expect(f.additionalNumber, '3456');
    expect(f.shortAddress, 'RRRD8228');
    expect(f.addressLine, '8228 King Fahd Road, Al Olaya, Riyadh 12214-3456 (RRRD8228)');
    expect(f.vat, isNull);
  });

  test('Arabic labels with the value before the label (reversed line) or on the next line', () {
    final f = parseDocText('٨٢٢٨ :رقم المبنى\nالرمز البريدي\n١٢٢١٤\nالرقم الإضافي: ٣٤٥٦\nالحي: العليا');
    expect(f.buildingNumber, '8228');
    expect(f.postalCode, '12214');
    expect(f.additionalNumber, '3456');
    expect(f.district, 'العليا');
  });

  test('bilingual PDF as pdfium gives it: reversed English runs, Persian letter forms', () {
    // Text the web app read from a test certificate (lines joined with \n).
    const text = 'شھادة العنوان الوطني Certificate Address National\n'
        'رقم المبنى: ٨٢٢٨ 8228 :Number Building\n'
        'اسم الشارع: طریق الملك فھد Road Fahd King :Name Street\n'
        'District: Al Olaya العلیا :الحي\n'
        'المدینة: الریاض Riyadh :City\n'
        'الرمز البریدي: ١٢٢١٤ 12214 :Code Postal\n'
        'Additional Number: 3456\n'
        'Short Address: RRRD8228\n'
        'VAT Registration Number 300123456700003\n'
        'رقم السجل التجاري 1010123456';
    final f = parseDocText(text);
    expect(f.vat, '300123456700003');
    expect(f.crNumber, '1010123456');
    expect(f.addressLine, '8228 King Fahd Road, Al Olaya, Riyadh 12214-3456 (RRRD8228)');
  });

  test('city found by name when unlabelled; nothing found = empty', () {
    expect(parseDocText('شركة مثال - جدة').city, 'Jeddah');
    expect(parseDocText('hello world').isEmpty, isTrue);
  });
}
