import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/hr/contract_pay.dart';

void main() {
  test('English contract with labelled lines', () {
    final p = parseContractText('''
Employment Contract
Start date: 01/02/2026
Basic Salary: 6,000 SAR (Six thousand riyals)
Housing Allowance: 1,500 SAR
Transportation Allowance: 600 SAR
Phone Allowance: 200 SAR
Total Salary: 8,300 SAR
''');
    expect(p.basic?.amount, 6000);
    expect(p.housing?.amount, 1500);
    expect(p.transport?.amount, 600);
    expect([for (final o in p.others) (o.name, o.amount.amount)], [('Phone Allowance', 200.0)]);
    expect(p.total, 8300);
    expect(p.totalMismatch, isFalse);
  });

  test('Arabic contract with Arabic-Indic digits', () {
    final p = parseContractText('''
الراتب الأساسي: ٥٬٠٠٠ ريال
بدل السكن: ١٬٢٥٠ ريال
بدل النقل: ٥٠٠ ريال
بدل اتصال: ١٥٠ ريال
''');
    expect(p.basic?.amount, 5000);
    expect(p.housing?.amount, 1250);
    expect(p.transport?.amount, 500);
    expect([for (final o in p.others) (o.name, o.amount.amount)], [('بدل اتصال', 150.0)]);
  });

  test('table: label on one line, value on the next', () {
    final p = parseContractText('Basic Wage\n4500\nHousing Allowance\n1125\nTransportation Allowance\n450\n');
    expect(p.basic?.amount, 4500);
    expect(p.housing?.amount, 1125);
    expect(p.transport?.amount, 450);
  });

  test('several labels on one row', () {
    final p = parseContractText('Basic Wage 4000 Housing Allowance 1000 Transportation Allowance 400 Total 5400');
    expect(p.basic?.amount, 4000);
    expect(p.housing?.amount, 1000);
    expect(p.transport?.amount, 400);
  });

  test('housing as a percentage of basic, yearly amounts', () {
    final p = parseContractText('''
Basic salary: 8000 SAR per month
Housing allowance: 25% of the basic salary
Transportation allowance: 12,000 SAR per year
''');
    expect(p.housing?.amount, 2000);
    expect(p.housing?.note, ContractNote.percentOfBasic);
    expect(p.transport?.amount, 1000);
    expect(p.transport?.note, ContractNote.yearly);
  });

  test('bilingual contract: English names kept, no duplicates', () {
    final p = parseContractText('''
Basic Salary 5000 الراتب الأساسي
Food Allowance 300 بدل طعام
''');
    expect(p.basic?.amount, 5000);
    expect([for (final o in p.others) (o.name, o.amount.amount)], [('Food Allowance', 300.0)]);
  });

  test('RTL line with the value before the label', () {
    final p = parseContractText('5000 :الراتب الأساسي');
    expect(p.basic?.amount, 5000);
  });

  test('nothing found; mismatching total flagged', () {
    expect(parseContractText('This agreement is made between the parties.').isEmpty, isTrue);
    final p = parseContractText('Basic salary: 5000\nTotal salary: 7000');
    expect(p.totalMismatch, isTrue);
  });
}
