import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/clients/visit_rules.dart';
import 'package:wpc_crm/features/home/stats.dart';
import 'package:wpc_crm/features/home/stats_widgets.dart';
import 'package:wpc_crm/features/reports/report.dart';
import 'package:wpc_crm/features/visits/app_calls.dart';
import 'package:wpc_crm/features/visits/visit.dart';

Visit _visit(String client, DateTime at, {VisitType type = VisitType.visit, double? distance, bool mocked = false}) =>
    Visit(
      id: '$client-$at-$type',
      clientId: client,
      clientName: client,
      salesExecId: 'a',
      checkedInAt: at,
      notes: '',
      distanceMeters: distance,
      accuracy: null,
      mocked: mocked,
      type: type,
    );

Client _client(String id) => Client(
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
      assignedTo: 'a',
      category: 'B',
      lastVisitAt: null,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a call is never flagged, a far or fake-GPS visit is', () {
    final day = DateTime(2026, 10, 10);
    expect(_visit('c', day, type: VisitType.call, distance: 900, mocked: true).isFlagged, isFalse);
    expect(_visit('c', day, distance: 900).isFlagged, isTrue);
    expect(_visit('c', day, mocked: true).isFlagged, isTrue);
    expect(_visit('c', day).isFlagged, isFalse);
  });

  test('reports count visits and calls apart; both cover the client', () {
    final reports = buildReports(
      people: [
        const AppUser(
          id: 'a',
          name: 'a',
          email: '',
          phone: '',
          role: UserRole.salesExec,
          kamId: null,
          active: true,
          monthlyTarget: 240,
        ),
      ],
      clients: [_client('c1'), _client('c2'), _client('c3')],
      visits: [
        _visit('c1', DateTime(2026, 10, 5)),
        _visit('c2', DateTime(2026, 10, 6), type: VisitType.call),
        _visit('c2', DateTime(2026, 10, 7), type: VisitType.call),
      ],
      tasks: const [],
      range: StatsRange.month(DateTime(2026, 10)),
      rules: VisitRules.defaults,
      now: DateTime(2026, 10, 20),
    );
    final a = reports.single;
    expect(a.visits, 1);
    expect(a.calls, 2);
    expect(a.contacts, 3);
    expect(a.clientsVisited, 2);
    expect(a.assignedVisited, 2);
    expect(a.flagged, 0);
  });

  test('visits + calls text and call duration', () {
    expect(visitsAndCallsText(190, 30), '190 + 30');
    expect(visitsAndCallsText(190, 0), '190');
    expect(formatCallDuration(45), '45 s');
    expect(formatCallDuration(250), '4 min');
  });

  group('call dialled from the app', () {
    late ProviderContainer container;
    late AppCallNotifier calls;
    setUp(() {
      container = ProviderContainer();
      calls = container.read(appCallProvider.notifier);
    });
    tearDown(() => container.dispose());

    void lifecycle(AppLifecycleState s) =>
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(s);

    test('counts only once the user left the app and came back', () async {
      calls.state = AppCall(clientId: 'c1', startedAt: DateTime.now());
      // Still in the app (e.g. the iOS "Call?" alert was cancelled): nothing.
      lifecycle(AppLifecycleState.inactive);
      lifecycle(AppLifecycleState.resumed);
      expect(calls.finishedFor('c1'), isNull);

      lifecycle(AppLifecycleState.inactive);
      lifecycle(AppLifecycleState.hidden);
      lifecycle(AppLifecycleState.paused);
      lifecycle(AppLifecycleState.hidden);
      lifecycle(AppLifecycleState.inactive);
      lifecycle(AppLifecycleState.resumed);
      final call = calls.finishedFor('c1');
      expect(call, isNotNull);
      expect(call!.endedAt, isNotNull);
      // Another client, or too late: not offered.
      expect(calls.finishedFor('c2'), isNull);
      expect(calls.finishedFor('c1', now: call.endedAt!.add(const Duration(hours: 3))), isNull);

      calls.clear();
      expect(calls.finishedFor('c1'), isNull);
    });
  });
}
