import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/hr/hr_actions.dart';
import 'package:wpc_crm/features/hr/payroll.dart';

void main() {
  HrAction w(String date, WarningLevel level, {String uid = 'a', bool cancelled = false}) =>
      HrAction(uid: uid, kind: HrActionKind.warning, level: level, date: date, title: 't', cancelled: cancelled);

  test('next warning level: one above the highest active one of the last 180 days', () {
    final day = DateTime(2026, 11, 7);
    expect(nextWarningLevel(const [], 'a', day), WarningLevel.verbal);
    expect(nextWarningLevel([w('2026-10-01', WarningLevel.verbal)], 'a', day), WarningLevel.first);
    expect(nextWarningLevel([w('2026-10-01', WarningLevel.first), w('2026-11-01', WarningLevel.verbal)], 'a', day),
        WarningLevel.second);
    // Older than 180 days, cancelled or someone else's: not counted.
    expect(nextWarningLevel([w('2026-04-01', WarningLevel.second)], 'a', day), WarningLevel.verbal);
    expect(nextWarningLevel([w('2026-10-01', WarningLevel.second, cancelled: true)], 'a', day), WarningLevel.verbal);
    expect(nextWarningLevel([w('2026-10-01', WarningLevel.second, uid: 'b')], 'a', day), WarningLevel.verbal);
    // Stays at the final warning.
    expect(nextWarningLevel([w('2026-10-01', WarningLevel.last)], 'a', day), WarningLevel.last);
  });

  test('map round trip; pay fields only on deductions / rewards', () {
    const d = HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-07', title: 'Late', amount: 100, days: 1);
    final back = HrAction.fromMap(d.toMap());
    expect((back.kind, back.amount, back.days, back.payMonth), (HrActionKind.deduction, 100.0, 1.0, '2026-11'));
    const n = HrAction(uid: 'a', kind: HrActionKind.note, date: '2026-11-07', title: 'x', amount: 5);
    expect(n.toMap()['amount'], isNull);
    expect(n.toMap()['month'], isNull);
  });

  test('payslip: deductions / rewards of the payroll month, a day = monthly ÷ 30', () {
    const salary = SalaryStructure(
        basic: 4000, housing: 1000, transport: 500, others: [OtherAllowance(name: 'Phone', amount: 300), OtherAllowance(name: 'Food', amount: 200)]);
    expect(SalaryStructure.fromMap(salary.toMap()).toMap(), salary.toMap());
    expect(salary.otherTotal, 500);
    final actions = [
      const HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-10-28', month: '2026-11', title: 'x', amount: 150),
      const HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-03', title: 'x', days: 1),
      const HrAction(uid: 'a', kind: HrActionKind.reward, date: '2026-11-05', title: 'x', amount: 300),
      const HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-05', title: 'x', amount: 999, cancelled: true),
      const HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-12-01', title: 'x', amount: 50),
      const HrAction(uid: 'b', kind: HrActionKind.deduction, date: '2026-11-01', title: 'x', amount: 70),
    ];
    final p = payslipFor(salary, actions, 'a', '2026-11');
    expect(p, (gross: 6000.0, deductions: 350.0, rewards: 300.0, net: 5950.0));

  });

  test('acceptance: sent by default except notes; waiting until accepted, cancelled or not sent', () {
    const warning = HrAction(uid: 'a', kind: HrActionKind.warning, date: '2026-11-07', title: 'Late');
    expect(warning.sent, isTrue);
    expect(warning.awaitingAcceptance, isTrue);
    expect(const HrAction(uid: 'a', kind: HrActionKind.note, date: '2026-11-07', title: 'x').sent, isFalse);
    expect(const HrAction(uid: 'a', kind: HrActionKind.note, date: '2026-11-07', title: 'x', sent: true).awaitingAcceptance, isTrue);
    expect(HrAction(uid: 'a', kind: HrActionKind.warning, date: '2026-11-07', title: 'x', acceptedAt: DateTime(2026)).awaitingAcceptance, isFalse);
    expect(const HrAction(uid: 'a', kind: HrActionKind.warning, date: '2026-11-07', title: 'x', cancelled: true).awaitingAcceptance, isFalse);
    // Warnings / deductions / rewards are always saved as sent.
    expect(const HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-07', title: 'x', sent: false).toMap()['sent'], isTrue);
  });

  test('changing what it says asks again; acceptance / cancel fields do not', () {
    const a = HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-07', title: 'Late', amount: 100);
    expect(a.sameContentAs(HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-07', title: 'Late', amount: 100, acceptedAt: DateTime(2026))), isTrue);
    expect(a.sameContentAs(const HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-07', title: 'Late', amount: 150)), isFalse);
    expect(a.sameContentAs(const HrAction(uid: 'a', kind: HrActionKind.deduction, date: '2026-11-07', title: 'Late', amount: 100, month: '2026-12')), isFalse);
  });
}
