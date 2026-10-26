import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/visit_rules.dart';
import 'package:wpc_crm/features/home/stats.dart';
import 'package:wpc_crm/features/plan/plan_task.dart';
import 'package:wpc_crm/features/reports/report.dart';
import 'package:wpc_crm/features/visits/visit.dart';

AppUser _user(String id, {int target = 0}) => AppUser(
      id: id,
      name: id,
      email: '',
      phone: '',
      role: UserRole.salesExec,
      kamId: null,
      active: true,
      monthlyTarget: target,
    );

Client _client(String id, String? owner, {DateTime? lastVisit}) => Client(
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
      lastVisitAt: lastVisit,
    );

Visit _visit(String client, String by, DateTime at, {double? distance, bool mocked = false, String? kam}) => Visit(
      id: '$client-$at',
      clientId: client,
      clientName: client,
      salesExecId: by,
      checkedInAt: at,
      notes: '',
      distanceMeters: distance,
      accuracy: 10,
      mocked: mocked,
      kamId: kam,
    );

PlanTask _task(String owner, String date, {bool done = false, TaskApproval approval = TaskApproval.approved}) =>
    PlanTask(
      id: '$owner$date$done',
      ownerId: owner,
      date: date,
      clientId: null,
      clientName: null,
      title: 't',
      createdBy: owner,
      approval: approval,
      done: done,
      visitId: null,
    );

void main() {
  final range = StatsRange.month(DateTime(2026, 10));
  final now = DateTime(2026, 10, 20);

  test('person report counts visits, coverage, flags and plan in the period only', () {
    final reports = buildReports(
      people: [_user('a', target: 31), _user('b')],
      clients: [
        _client('c1', 'a', lastVisit: DateTime(2026, 10, 15)),
        _client('c2', 'a'),
        _client('c3', 'b'),
      ],
      visits: [
        _visit('c1', 'a', DateTime(2026, 10, 15)),
        _visit('c1', 'a', DateTime(2026, 10, 16), distance: 500),
        _visit('c9', 'a', DateTime(2026, 10, 17), mocked: true, kam: 'k'),
        _visit('c3', 'a', DateTime(2026, 10, 18)), // someone else's client
        _visit('c2', 'a', DateTime(2026, 9, 30)), // before the period
      ],
      tasks: [
        _task('a', '2026-10-15', done: true),
        _task('a', '2026-10-16'),
        _task('a', '2026-10-17', approval: TaskApproval.pending),
        _task('a', '2026-09-30', done: true),
      ],
      range: range,
      rules: VisitRules.defaults,
      now: now,
    );
    final a = reports[0];
    expect(a.visits, 4);
    expect(a.target, closeTo(31, 0.001));
    expect(a.clientsVisited, 3);
    expect(a.assigned, 2);
    expect(a.assignedVisited, 1);
    expect(a.coverage, 0.5);
    expect(a.onSchedule, 1);
    expect(a.flagged, 2);
    expect(a.withKam, 1);
    expect(a.tasksApproved, 2);
    expect(a.tasksDone, 1);

    final b = reports[1];
    expect(b.visits, 0);
    // c3 was visited by a, which still covers b's client.
    expect(b.assignedVisited, 1);
    expect(b.planCompletion, isNull);
  });

  test('unvisited clients: never visited first, then oldest visit', () {
    final list = unvisitedClients(
      clients: [
        _client('recent', 'a', lastVisit: DateTime(2026, 9, 25)),
        _client('old', 'a', lastVisit: DateTime(2026, 6, 1)),
        _client('never', 'a'),
        _client('done', 'a'),
        _client('other', 'b'),
      ],
      ownerIds: {'a'},
      visits: [_visit('done', 'a', DateTime(2026, 10, 2))],
      range: range,
    );
    expect(list.map((c) => c.id), ['never', 'old', 'recent']);
  });

  test('route distance ignores rough fixes and jitter while standing still', () {
    final t0 = DateTime(2026, 10, 14, 8);
    RoutePoint p(double lat, double lng, int minute, {double accuracy = 10}) =>
        RoutePoint(lat: lat, lng: lng, t: t0.add(Duration(minutes: minute)), accuracy: accuracy);
    final summary = summarizeRoute([
      p(24.7000, 46.6000, 0),
      p(24.70005, 46.6000, 2), // ~5 m jitter
      p(24.70010, 46.6000, 4), // ~11 m from the start
      p(24.8000, 46.6000, 6, accuracy: 500), // rough fix, dropped
      p(24.7100, 46.6000, 8), // ~1.1 km north
    ]);
    expect(summary.path.length, 4);
    expect(summary.distanceMeters, closeTo(1112, 5));
    expect(summary.first, t0);
    expect(summary.last, t0.add(const Duration(minutes: 8)));
  });

  test('route splits where no location came for more than 15 minutes', () {
    final t0 = DateTime(2026, 10, 14, 8);
    RoutePoint p(int minute) => RoutePoint(lat: 24.7, lng: 46.6, t: t0.add(Duration(minutes: minute)));
    final runs = splitAtGaps([p(0), p(2), p(4), p(30), p(32), p(47), p(80)]);
    expect(runs.map((r) => r.length), [3, 3, 1]);
    expect(splitAtGaps(const []), isEmpty);
  });

  test('decodes a Google encoded polyline', () {
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points.length, 3);
    expect(points[0].$1, closeTo(38.5, 1e-6));
    expect(points[0].$2, closeTo(-120.2, 1e-6));
    expect(points[2].$1, closeTo(43.252, 1e-6));
    expect(points[2].$2, closeTo(-126.453, 1e-6));
  });

  test('route lines use road legs; legs without a road follow the fixes', () {
    final t0 = DateTime(2026, 10, 14, 8);
    DateTime at(int minute) => t0.add(Duration(minutes: minute));
    RoutePoint p(double lat, int minute) => RoutePoint(lat: lat, lng: 46.6, t: at(minute), accuracy: 10);
    final run = [p(24.70, 0), p(24.71, 2), p(24.7101, 4), p(24.72, 6), p(24.73, 8)];
    final legs = [
      SnappedLeg(from: at(0), to: at(2), meters: 1500, points: const [(24.70, 46.6), (24.705, 46.61), (24.71, 46.6)]),
      SnappedLeg(from: at(2), to: at(6), meters: 1300), // no believable road: along the fixes
    ];
    final result = routeLines([run], legs);
    expect(result.lines.single, [
      (24.70, 46.6), (24.705, 46.61), (24.71, 46.6), // road leg
      (24.71, 46.6), (24.7101, 46.6), (24.72, 46.6), // no road: the fixes, minute 4 included
      (24.73, 46.6), // not snapped yet
    ]);
    expect(result.meters, closeTo(1500 + 1300 + 1112, 5));

    final unsnapped = routeLines([run], const []);
    expect(unsnapped.lines.single.length, 5);
    expect(unsnapped.meters, closeTo(summarizeRoute(run).distanceMeters, 0.01));
  });
}
