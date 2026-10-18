import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/plan/plan_task.dart';
import 'package:wpc_crm/features/plan/route_order.dart';

// Points along a street, about 1.1 km apart (0.01° longitude near Riyadh).
Stop _at(int km) => (24.7, 46.6 + km * 0.01);

PlanTask _task(String id, String clientId, {TaskApproval approval = TaskApproval.approved}) => PlanTask(
      id: id,
      ownerId: 'u',
      date: '2026-10-18',
      clientId: clientId,
      clientName: clientId,
      title: '',
      createdBy: 'u',
      approval: approval,
      done: false,
      visitId: null,
    );

Client _client(String id, Stop? at) => Client(
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
      lat: at?.$1,
      lng: at?.$2,
      assignedTo: 'u',
      category: 'B',
      lastVisitAt: null,
    );

void main() {
  test('stops on a line are visited end to end', () {
    final stops = [_at(3), _at(0), _at(4), _at(1), _at(2)];
    final order = shortestOrder(stops);
    final km = [for (final i in order) stops[i].$2];
    final ascending = [...km]..sort();
    expect(km, anyOf([equals(ascending), equals(ascending.reversed.toList())]));
    expect(pathMeters([for (final i in order) stops[i]]), closeTo(stopMeters(_at(0), _at(4)), 1));
  });

  test('small inputs keep their order', () {
    expect(shortestOrder([]), isEmpty);
    expect(shortestOrder([_at(5), _at(0)]), [0, 1]);
  });

  test('plan numbers skip rejected items and clients without a location', () {
    final clients = {
      'a': _client('a', _at(0)),
      'b': _client('b', _at(5)),
      'c': _client('c', _at(1)),
      'x': _client('x', null),
    };
    final tasks = [
      _task('1', 'a'),
      _task('2', 'b'),
      _task('3', 'c'),
      _task('4', 'x'),
      _task('5', 'b', approval: TaskApproval.rejected),
    ];
    final numbers = planStopNumbers(tasks, clients);
    expect(numbers.keys.toSet(), {'1', '2', '3'});
    // c lies between a and b.
    expect(numbers['3'], 2);
    final ordered = inRouteOrder(tasks, numbers).map((t) => t.id).toList();
    expect(ordered.sublist(3), ['4', '5']);
  });

  test('efficiency: time needed vs time taken, and the order used', () {
    final start = DateTime(2026, 10, 18, 9);
    // Visited 0 → 4 → 1 km: the shortest order would be 0 → 1 → 4.
    final e = dayEfficiency([
      (at: start, place: _at(0)),
      (at: start.add(const Duration(hours: 1)), place: _at(4)),
      (at: start.add(const Duration(hours: 3)), place: _at(1)),
    ])!;
    expect(e.took, const Duration(hours: 3));
    expect(e.bestOrder, isFalse);
    expect(e.shortestMeters, lessThan(e.takenMeters));
    // 2 visits × 30 min + about 8.5 min of driving (4 km × 1.4 at 40 km/h).
    expect(e.needed.inMinutes, inInclusiveRange(66, 70));
    expect(e.rate, closeTo(e.needed.inSeconds / e.took.inSeconds, 1e-9));

    expect(dayEfficiency([(at: start, place: _at(0))]), isNull);
  });

  test('a fast day is capped at 100 %', () {
    final start = DateTime(2026, 10, 18, 9);
    final e = dayEfficiency([
      (at: start, place: _at(0)),
      (at: start.add(const Duration(minutes: 20)), place: _at(1)),
    ])!;
    expect(e.rate, 1);
    expect(e.bestOrder, isTrue);
  });
}
