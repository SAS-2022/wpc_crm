import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/kam_meetings/kam_meeting.dart';

KamTask task(String id, {DateTime? due, bool done = false, DateTime? doneAt, DateTime? createdAt}) => KamTask(
      id: id,
      meetingId: 'm',
      kamId: 'k',
      text: id,
      due: due,
      status: done ? KamTaskStatus.done : KamTaskStatus.open,
      doneAt: doneAt,
      createdAt: createdAt,
    );

AppUser user(UserRole role, {List<UserRole> extra = const [], bool active = true}) =>
    AppUser(id: 'u', name: 'U', email: '', phone: '', role: role, kamId: null, extraRoles: extra, active: active);

void main() {
  final now = DateTime(2026, 11, 22, 10);

  test('overdue only after the due day ends', () {
    expect(task('a', due: DateTime(2026, 11, 22)).overdue(now), isFalse);
    expect(task('a', due: DateTime(2026, 11, 21)).overdue(now), isTrue);
    expect(task('a', due: DateTime(2026, 11, 21), done: true).overdue(now), isFalse);
    expect(task('a').overdue(now), isFalse);
  });

  test('open first (overdue, by due day, no due last), done newest first', () {
    final list = sortKamTasks([
      task('done-old', done: true, doneAt: DateTime(2026, 11, 1)),
      task('no-due', createdAt: DateTime(2026, 11, 1)),
      task('due-25', due: DateTime(2026, 11, 25)),
      task('overdue', due: DateTime(2026, 11, 20)),
      task('due-23', due: DateTime(2026, 11, 23)),
      task('done-new', done: true, doneAt: DateTime(2026, 11, 20)),
    ], now);
    expect(list.map((t) => t.id), ['overdue', 'due-23', 'due-25', 'no-due', 'done-new', 'done-old']);
  });

  test('meetings: upcoming soonest first, then past newest first', () {
    KamMeeting m(String id, DateTime at) => KamMeeting(id: id, kamId: 'k', at: at);
    final list = sortKamMeetings([
      m('past-old', DateTime(2026, 11, 1)),
      m('next-far', DateTime(2026, 11, 29)),
      m('past-new', DateTime(2026, 11, 15)),
      m('next', DateTime(2026, 11, 23)),
    ], now);
    expect(list.map((x) => x.id), ['next', 'next-far', 'past-new', 'past-old']);
  });

  test('who manages / sees', () {
    expect(managesKamMeetings(user(UserRole.salesManager)), isTrue);
    expect(managesKamMeetings(user(UserRole.gm)), isTrue);
    expect(managesKamMeetings(user(UserRole.kam)), isFalse);
    expect(seesKamMeetings(user(UserRole.kam)), isTrue);
    expect(seesKamMeetings(user(UserRole.salesExec, extra: [UserRole.kam])), isTrue);
    expect(seesKamMeetings(user(UserRole.salesExec)), isFalse);
    expect(seesKamMeetings(user(UserRole.kam, active: false)), isFalse);
  });

  test('done comment must have text', () {
    expect(validDoneComment('  '), isFalse);
    expect(validDoneComment('Called them'), isTrue);
  });
}
