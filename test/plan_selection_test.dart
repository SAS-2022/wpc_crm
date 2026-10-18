import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/plan/plan_selection.dart';

AppUser user(String id, UserRole role, {String? kamId, bool active = true}) =>
    AppUser(id: id, name: id, email: '', phone: '', role: role, kamId: kamId, active: active);

Client client(String id, String? owner) => Client(
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
    );

void main() {
  final kam = user('kam', UserRole.kam);
  final gm = user('gm', UserRole.gm);
  final users = {
    for (final u in [
      kam,
      gm,
      user('sami', UserRole.salesExec, kamId: 'kam'),
      user('omar', UserRole.salesExec, kamId: 'kam2'),
      user('gone', UserRole.salesExec, kamId: 'kam', active: false),
    ])
      u.id: u,
  };
  final clients = [
    client('c1', 'sami'),
    client('c2', 'sami'),
    client('c3', 'omar'),
    client('c4', null),
    client('c5', 'gone'),
    client('c6', 'kam'),
  ];

  test('the GM plans every client for its salesperson; no or inactive owner = unassigned', () {
    final s = splitForPlans(clients, gm, users);
    expect(s.byOwner.map((k, v) => MapEntry(k, v.map((c) => c.id).toList())), {
      'sami': ['c1', 'c2'],
      'omar': ['c3'],
      'kam': ['c6'],
    });
    expect(s.unassigned.map((c) => c.id), ['c4', 'c5']);
    expect(s.notAllowed, isEmpty);
  });

  test('a KAM plans only for their team and themselves', () {
    final s = splitForPlans(clients, kam, users);
    expect(s.byOwner.keys, unorderedEquals(['sami', 'kam']));
    expect(s.notAllowed.map((c) => c.id), ['c3']);
  });

  test('clients just moved count under their new owner', () {
    final s = splitForPlans(clients, gm, users, moved: {'c4': 'sami', 'c5': 'omar'});
    expect(s.unassigned, isEmpty);
    expect(s.byOwner['sami']!.map((c) => c.id), ['c1', 'c2', 'c4']);
    expect(s.byOwner['omar']!.map((c) => c.id), ['c3', 'c5']);
  });
}
