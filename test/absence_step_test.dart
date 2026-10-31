import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/absence.dart';

void main() {
  Absence a({
    AbsenceStatus status = AbsenceStatus.pending,
    List<String> managers = const [],
    AbsenceManagerStep? step,
    String? decidedBy,
  }) =>
      Absence(
        uid: 'op',
        date: '2026-10-31',
        reason: AbsenceReason.sick,
        note: '',
        status: status,
        managerIds: managers,
        managerStep: step,
        decidedBy: decidedBy,
      );
  const approved = AbsenceManagerStep(approved: true, byId: 'fm');
  const rejected = AbsenceManagerStep(approved: false, byId: 'fm');

  test('no manager: HR right away (also older reports)', () {
    expect(a().waitingForManager, isFalse);
    expect(a().hrMayDecide, isTrue);
  });

  test('with a manager: the manager first, then HR', () {
    expect(a(managers: ['fm']).waitingForManager, isTrue);
    expect(a(managers: ['fm']).hrMayDecide, isFalse);
    expect(a(managers: ['fm'], step: approved).waitingForManager, isFalse);
    expect(a(managers: ['fm'], step: approved).hrMayDecide, isTrue);
  });

  test('rejected by the manager: HR may still change it until they decide', () {
    final r = a(status: AbsenceStatus.rejected, managers: ['fm'], step: rejected);
    expect(r.rejectedByManager, isTrue);
    expect(r.hrMayDecide, isTrue);
    final decided = a(status: AbsenceStatus.rejected, managers: ['fm'], step: rejected, decidedBy: 'hr');
    expect(decided.rejectedByManager, isFalse);
    expect(decided.hrMayDecide, isFalse);
  });
}
