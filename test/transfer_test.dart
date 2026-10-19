import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/transfer.dart';
import 'package:wpc_crm/features/plan/plan_task.dart';

AppUser user(String id, UserRole role, {String? kamId, bool active = true}) =>
    AppUser(id: id, name: id, email: '', phone: '', role: role, kamId: kamId, active: active);

PlanTask task(String id, {required String owner, required String date, String? clientId = 'c1', bool done = false}) =>
    PlanTask(
      id: id,
      ownerId: owner,
      date: date,
      clientId: clientId,
      clientName: clientId,
      title: '',
      createdBy: owner,
      approval: TaskApproval.approved,
      done: done,
      visitId: null,
    );

void main() {
  final kam = user('kam', UserRole.kam);
  final otherKam = user('kam2', UserRole.kam);
  final gm = user('gm', UserRole.gm);
  final sami = user('sami', UserRole.salesExec, kamId: 'kam');
  final eddy = user('eddy', UserRole.salesExec, kamId: 'kam');
  final omar = user('omar', UserRole.salesExec, kamId: 'kam2');
  final gone = user('gone', UserRole.salesExec, kamId: 'kam', active: false);
  final users = [kam, otherKam, gm, sami, eddy, omar, gone];
  final byId = {for (final u in users) u.id: u};

  group('transferTargets', () {
    test('a KAM moves clients to themselves and active members of their own team only', () {
      expect(transferTargets(kam, users).map((u) => u.id), ['kam', 'sami', 'eddy']);
    });

    test('the GM / sales manager moves clients to any active sales exec or KAM', () {
      expect(transferTargets(gm, users).map((u) => u.id), ['kam', 'kam2', 'sami', 'eddy', 'omar']);
    });

    test('a sales exec moves nothing', () {
      expect(transferTargets(sami, users), isEmpty);
    });
  });

  group('canTransferFrom', () {
    test('a KAM moves their own clients, their team\'s and unassigned ones', () {
      expect(canTransferFrom(kam, 'kam', byId), isTrue);
      expect(canTransferFrom(kam, 'sami', byId), isTrue);
      expect(canTransferFrom(kam, 'kam2', byId), isFalse);
      expect(canTransferFrom(kam, 'omar', byId), isFalse);
      expect(canTransferFrom(kam, null, byId), isTrue); // unassigned pool (2026-10-19)
    });

    test('the GM moves any client, unassigned ones too', () {
      expect(canTransferFrom(gm, 'omar', byId), isTrue);
      expect(canTransferFrom(gm, null, byId), isTrue);
      expect(canUnassign(gm), isTrue);
      expect(canUnassign(kam), isFalse);
    });

    test('a sales exec moves nothing', () {
      expect(canTransferFrom(sami, 'sami', byId), isFalse);
    });
  });

  group('planItemsToDrop', () {
    const today = '2026-10-15';
    final previous = {'c1': 'sami', 'c2': null};

    test('drops the previous owner\'s open items from today on', () {
      final tasks = [
        task('today', owner: 'sami', date: today),
        task('later', owner: 'sami', date: '2026-10-20'),
      ];
      expect(planItemsToDrop(tasks, previous, today).map((t) => t.id), ['today', 'later']);
    });

    test('keeps past plans, done items, other owners, other clients and free tasks', () {
      final tasks = [
        task('past', owner: 'sami', date: '2026-10-14'),
        task('done', owner: 'sami', date: today, done: true),
        task('eddy', owner: 'eddy', date: today),
        task('other client', owner: 'sami', date: today, clientId: 'c9'),
        task('free', owner: 'sami', date: today, clientId: null),
      ];
      expect(planItemsToDrop(tasks, previous, today), isEmpty);
    });
  });

  test('ClientTransfer round-trips through a map', () {
    final t = ClientTransfer(fromId: 'sami', toId: null, byId: 'gm', at: DateTime(2026, 10, 15, 10, 30));
    final back = ClientTransfer.fromMap(t.toMap());
    expect((back.fromId, back.toId, back.byId, back.at), ('sami', null, 'gm', DateTime(2026, 10, 15, 10, 30)));
  });
}
