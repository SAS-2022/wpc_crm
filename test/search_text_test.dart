import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/search_text.dart';

void main() {
  test('Arabic letter forms, harakat and tatweel fold together', () {
    expect(foldSearch('أحمد'), foldSearch('احمد'));
    expect(foldSearch('إبراهيم'), foldSearch('ابراهيم'));
    expect(foldSearch('مؤسسة'), foldSearch('موسسه'));
    expect(foldSearch('مستشفى'), foldSearch('مستشفي'));
    expect(foldSearch('مُحَمَّد'), 'محمد');
    expect(foldSearch('مـحـمـد'), 'محمد');
  });

  test('Arabic-Indic digits, case and spaces', () {
    expect(foldSearch('٠٥٥ ١٢٣'), '055 123');
    expect(searchDigits('۰۵۵-۱۲۳'), '055123');
    expect(foldSearch('  Al   Noor '), 'al noor');
  });

  test('mapped indexes point back into the original text', () {
    final (folded, at) = foldSearchMapped('مُحَمَّد  Ali');
    expect(folded, 'محمد ali');
    expect(at.length, folded.length);
    expect(at[1], 2); // ح after the damma
    expect(at[5], 10); // 'A'
  });

  test('searchHas', () {
    expect(searchHas('شركة الأمل للتجارة', 'الامل'), isTrue);
    expect(searchHas('Riyadh', 'riy'), isTrue);
    expect(searchHas('Riyadh', 'jed'), isFalse);
    expect(searchHas('anything', ''), isTrue);
  });
}
