import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/client_status.dart';
import 'package:wpc_crm/features/clients/transfer.dart';
import 'package:wpc_crm/features/clients/transfer_watch.dart';
import 'package:wpc_crm/features/visits/visit.dart';

AppUser user(String id, UserRole role, {String? kamId, bool active = true}) =>
    AppUser(id: id, name: id, email: '', phone: '', role: role, kamId: kamId, active: active);

Client client(String id, {String? owner, StatusRequest? request, List<ClientTransfer> transfers = const []}) => Client(
      id: id,
      vat: '',
      nameKey: id,
      name: id,
      aliases: const [],
      phone: '',
      mobile: '',
      address: '',
      city: '',
      tags: '',
      odooSalesperson: '',
      googlePin: '',
      lat: null,
      lng: null,
      assignedTo: owner,
      category: 'B',
      lastVisitAt: null,
      statusRequest: request,
      transfers: transfers,
    );

Visit visit(String id, String clientId, String by, DateTime at, {VisitType type = VisitType.visit}) => Visit(
      id: id,
      clientId: clientId,
      clientName: clientId,
      salesExecId: by,
      checkedInAt: at,
      notes: '',
      distanceMeters: null,
      accuracy: null,
      mocked: false,
      type: type,
    );

void main() {
  final kam = user('kam', UserRole.kam);
  final kam2 = user('kam2', UserRole.kam);
  final sm = user('sm', UserRole.salesManager);
  final gm = user('gm', UserRole.gm);
  final sami = user('sami', UserRole.salesExec, kamId: 'kam');
  final omar = user('omar', UserRole.salesExec, kamId: 'kam2');
  final all = [kam, kam2, sm, gm, sami, omar, user('oldGm', UserRole.gm, active: false)];
  final byId = {for (final u in all) u.id: u};

  group('client status', () {
    test('a sales exec asks; their KAM, the sales manager and the GM are asked', () {
      expect(canRequestStatus(sami, client('c', owner: 'sami')), isTrue);
      expect(canRequestStatus(sami, client('c', owner: 'omar')), isFalse);
      expect(statusApprovers(sami, all), unorderedEquals(['kam', 'sm', 'gm']));
      // A KAM's own client: only the managers.
      expect(statusApprovers(kam, all), unorderedEquals(['sm', 'gm']));
    });

    test('KAM / managers change it directly, but a KAM not on their own clients', () {
      expect(canSetStatusDirectly(kam, client('c', owner: 'sami'), byId), isTrue);
      expect(canSetStatusDirectly(kam, client('c'), byId), isTrue); // unassigned
      expect(canSetStatusDirectly(kam, client('c', owner: 'omar'), byId), isFalse); // other team
      expect(canSetStatusDirectly(kam, client('c', owner: 'kam'), byId), isFalse); // asks the managers
      expect(canSetStatusDirectly(sm, client('c', owner: 'kam'), byId), isTrue);
      expect(canSetStatusDirectly(sami, client('c', owner: 'sami'), byId), isFalse);
    });

    test('approvers decide others\' requests, never their own', () {
      const asked = StatusRequest(status: ClientStatus.closed, byId: 'sami', at: null);
      expect(canDecideStatus(kam, client('c', owner: 'sami', request: asked), byId), isTrue);
      expect(canDecideStatus(gm, client('c', owner: 'sami', request: asked), byId), isTrue);
      expect(canDecideStatus(kam2, client('c', owner: 'sami', request: asked), byId), isFalse);
      expect(canDecideStatus(sami, client('c', owner: 'sami', request: asked), byId), isFalse);
      const kamAsked = StatusRequest(status: ClientStatus.notWorking, byId: 'kam', at: null);
      expect(canDecideStatus(kam, client('c', owner: 'kam', request: kamAsked), byId), isFalse);
      expect(canDecideStatus(sm, client('c', owner: 'kam', request: kamAsked), byId), isTrue);
      expect(canDecideStatus(gm, client('c', owner: 'sami'), byId), isFalse); // nothing pending
    });

    test('unknown or missing status is active', () {
      expect(ClientStatus.fromKey(null), ClientStatus.active);
      expect(ClientStatus.fromKey('closed'), ClientStatus.closed);
      expect(ClientStatus.fromKey('x'), ClientStatus.active);
    });
  });

  group('transferred clients', () {
    final now = DateTime(2026, 10, 19, 12);
    final moved = DateTime(2026, 10, 10);
    ClientTransfer t(String? from, String? to, DateTime at) => ClientTransfer(fromId: from, toId: to, byId: 'kam', at: at);

    test('first visit or call by the new salesperson after the move', () {
      final rows = transferWatchRows(
        clients: [
          client('a', owner: 'sami', transfers: [t('omar', 'sami', moved)]),
          client('b', owner: 'sami', transfers: [t('omar', 'sami', moved)]),
          client('c', owner: 'sami', transfers: [t(null, 'sami', DateTime(2026, 10, 15))]),
        ],
        visits: [
          visit('1', 'a', 'omar', DateTime(2026, 10, 12)), // old owner: doesn't count
          visit('2', 'a', 'sami', DateTime(2026, 10, 9)), // before the move
          visit('3', 'b', 'sami', DateTime(2026, 10, 13), type: VisitType.call),
          visit('4', 'b', 'sami', DateTime(2026, 10, 16)),
        ],
        since: DateTime(2026, 9, 19),
        now: now,
      );
      // Not contacted first, longest waiting first.
      expect([for (final r in rows) r.client.id], ['a', 'c', 'b']);
      expect(rows[0].contacted, isFalse);
      expect(rows[0].days, 9);
      expect(rows[2].firstContact?.id, '3');
      expect(rows[2].days, 3);
    });

    test('moves to Unassigned and before the period are left out; later moves marked', () {
      final rows = transferWatchRows(
        clients: [
          client('a', transfers: [t('sami', null, moved)]),
          client('b', owner: 'omar', transfers: [t('omar', 'sami', DateTime(2026, 8, 1))]),
          client('c', owner: 'omar', transfers: [t('omar', 'sami', moved), t('sami', 'omar', DateTime(2026, 10, 12))]),
        ],
        visits: const [],
        since: DateTime(2026, 9, 19),
        now: now,
      );
      expect([for (final r in rows) (r.client.id, r.transfer.toId, r.movedAgain)], [
        ('c', 'sami', true),
        ('c', 'omar', false),
      ]);
    });

    test('limited to the people (new or previous owner)', () {
      final rows = transferWatchRows(
        clients: [
          client('a', transfers: [t('omar', 'sami', moved)]),
          client('b', transfers: [t('x', 'y', moved)]),
        ],
        visits: const [],
        since: DateTime(2026, 9, 19),
        now: now,
        people: {'omar'},
      );
      expect([for (final r in rows) r.client.id], ['a']);
    });
  });
}
