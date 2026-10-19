import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/client_links.dart';

Client c(String id, {String? parent}) => Client(
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
      assignedTo: null,
      category: 'B',
      lastVisitAt: null,
      parentId: parent,
    );

void main() {
  // X has showrooms s1, s2; s2 has a kiosk k. Y has s3. Z stands alone.
  final clients = [
    c('X'),
    c('s2', parent: 'X'),
    c('s1', parent: 'X'),
    c('k', parent: 's2'),
    c('Y'),
    c('s3', parent: 'Y'),
    c('Z'),
    c('orphan', parent: 'deleted'),
  ];

  test('trees: main companies with their branches at every level, sorted', () {
    final trees = linkTrees(clients);
    expect([for (final t in trees) t.client.id], ['X', 'Y']);
    final x = trees.first;
    expect([for (final n in x.children) n.client.id], ['s1', 's2']);
    expect(x.children[1].children.single.client.id, 'k');
    expect(x.size, 3);
    expect([for (final cl in x.all) cl.id], ['X', 's1', 's2', 'k']);
  });

  test('a missing main company counts as none; unlinked clients are left out', () {
    final ids = {for (final t in linkTrees(clients)) for (final cl in t.all) cl.id};
    expect(ids.contains('Z'), isFalse);
    expect(ids.contains('orphan'), isFalse);
  });

  test('no loops: not under itself or under one of its own branches', () {
    expect(canLink('X', 'k', clients), isFalse); // k is below X
    expect(canLink('X', 'X', clients), isFalse);
    expect(canLink('Y', 'X', clients), isTrue);
    expect(canLink('k', 'Y', clients), isTrue);
    expect(descendantIds('X', clients), {'s1', 's2', 'k'});
  });

  test('a loop already in the data doesn\'t hang the tree', () {
    final loop = [c('a', parent: 'b'), c('b', parent: 'a'), c('r'), c('x', parent: 'r')];
    expect([for (final t in linkTrees(loop)) t.client.id], ['r']);
  });
}
