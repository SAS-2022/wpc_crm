import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/clients/client.dart';
import 'package:wpc_crm/features/home/stats.dart';
import 'package:wpc_crm/features/clients/visit_rules.dart';
import 'package:wpc_crm/features/reports/report.dart';
import 'package:wpc_crm/features/reports/report_pdf.dart';
import 'package:wpc_crm/features/reports/report_ranking.dart';
import 'package:wpc_crm/features/reports/report_sections.dart';
import 'package:wpc_crm/features/reports/routing_pace.dart';
import 'package:wpc_crm/features/visits/visit.dart';
import 'package:wpc_crm/l10n/app_localizations_ar.dart';
import 'package:wpc_crm/l10n/app_localizations_en.dart';

AppUser user(String id, {int target = 0}) =>
    AppUser(id: id, name: id, email: '', phone: '', role: UserRole.salesExec, kamId: null, active: true, monthlyTarget: target);

Client client(String id, {String? owner, List<String> tags = const [], DateTime? createdAt, String source = 'import'}) => Client(
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
      lat: 24.7,
      lng: 46.6,
      assignedTo: owner,
      category: 'B',
      lastVisitAt: null,
      source: source,
      createdAt: createdAt,
      tagIds: tags,
    );

var _n = 0;
Visit visit(String clientId, String by, DateTime at, {bool call = false}) => Visit(
      id: 'v${_n++}',
      clientId: clientId,
      clientName: clientId,
      salesExecId: by,
      checkedInAt: at,
      notes: '',
      distanceMeters: null,
      accuracy: null,
      mocked: false,
      checkInLat: 24.7,
      checkInLng: 46.6 + (_n % 10) / 100,
      type: call ? VisitType.call : VisitType.visit,
    );

void main() {
  final range = StatsRange.month(DateTime(2026, 10));
  final sami = user('sami', target: 4), eddy = user('eddy', target: 10);
  final clients = {
    for (final c in [
      client('f1', tags: ['factory']),
      client('f2', tags: ['factory', 'showroom']),
      client('s1', tags: ['showroom']),
      client('x'),
      client('new', owner: 'sami', createdAt: DateTime(2026, 10, 3)),
    ])
      c.id: c,
  };

  List<RankedPerson> build(List<Visit> visits, {Set<String> before = const {}, List<AppUser>? people}) {
    final team = people ?? [sami, eddy];
    return rankPeople(
      reports: buildReports(
        people: team,
        clients: clients.values.toList(),
        visits: visits,
        tasks: const [],
        range: range,
        rules: VisitRules.defaults,
        now: DateTime(2026, 11, 1),
      ),
      range: range,
      visits: visits,
      visitedBefore: before,
      clients: clients,
      newClientsFrom: clients.values.toList(),
      routing: routingReport(people: team, visits: visits, clients: clients, range: range),
    );
  }

  RankedPerson of(List<RankedPerson> rows, String id) => rows.firstWhere((r) => r.report.user.id == id);

  test('first visits vs re-visits', () {
    final rows = build([
      visit('f1', 'sami', DateTime(2026, 10, 2, 9)), // visited before the month
      visit('f2', 'eddy', DateTime(2026, 10, 2, 10)), // eddy first …
      visit('f2', 'sami', DateTime(2026, 10, 9, 10)), // … so a re-visit for sami
      visit('s1', 'sami', DateTime(2026, 10, 5, 10)),
      visit('s1', 'sami', DateTime(2026, 10, 20, 10)),
      visit('x', 'sami', DateTime(2026, 10, 6, 10), call: true), // calls don't count
    ], before: {'f1'});
    final s = of(rows, 'sami');
    expect(s.firstClients, ['s1']);
    expect(s.revisitedClients, ['f1', 'f2']);
    expect(s.visitsByClient['s1'], 2);
    expect(of(rows, 'eddy').firstClients, ['f2']);
    expect(s.workDays, 4);
  });

  test('client types: distinct clients and visits per tag, untagged apart', () {
    final rows = build([
      visit('f1', 'sami', DateTime(2026, 10, 2, 9)),
      visit('f1', 'sami', DateTime(2026, 10, 3, 9)),
      visit('f2', 'sami', DateTime(2026, 10, 3, 11)),
      visit('x', 'sami', DateTime(2026, 10, 4, 11)),
    ], people: [sami]);
    final t = rows.single.byTag;
    expect(t['factory'], (clients: 2, visits: 3));
    expect(t['showroom'], (clients: 1, visits: 1));
    expect(t[''], (clients: 1, visits: 1));
  });

  test('target: calls count; achieved at 100%', () {
    final rows = build([
      for (var d = 1; d <= 3; d++) visit('f1', 'sami', DateTime(2026, 10, d, 9)),
      visit('x', 'sami', DateTime(2026, 10, 4, 9), call: true),
      visit('f1', 'eddy', DateTime(2026, 10, 4, 9)),
    ]);
    expect(of(rows, 'sami').targetAchieved, isTrue);
    expect(of(rows, 'sami').targetShare, closeTo(1, 1e-9));
    expect(of(rows, 'eddy').targetAchieved, isFalse);
    expect(of(rows, 'eddy').targetShare, closeTo(0.1, 1e-9));
  });

  test('ranking: higher score first, new clients counted, equal scores share a rank', () {
    final rows = build([
      for (var d = 1; d <= 4; d++) visit('f1', 'sami', DateTime(2026, 10, d, 9)),
      visit('f2', 'eddy', DateTime(2026, 10, 4, 9)),
    ]);
    expect(rows.map((r) => r.report.user.id), ['sami', 'eddy']);
    expect(rows.first.rank, 1);
    expect(rows.first.newClients, 1);
    expect(rows.first.scoreParts[ScorePart.target], closeTo(scoreWeights[ScorePart.target]!, 1e-9));
    expect(rows.first.score, lessThanOrEqualTo(100));

    final tied = build(const [], people: [eddy, user('ali')]);
    expect(tied.map((r) => r.rank), [1, 1]);
  });

  test('average day from GPS timelines', () {
    DayTimeline day(String d, int client, int driving, double km, DateTime first, DateTime last) => DayTimeline(
          uid: 'sami',
          day: d,
          minutes: {for (final k in TimeKind.values) k: 0, TimeKind.client: client, TimeKind.driving: driving},
          drivingKm: km,
          clientStays: [ClientStay(clientId: 'f1', from: first, to: last)],
          stops: const [],
          firstClientAt: first,
          lastClientAt: last,
        );
    final a = averageDayOf([
      day('2026-10-01', 120, 60, 40, DateTime(2026, 10, 1, 8, 30), DateTime(2026, 10, 1, 15)),
      day('2026-10-02', 180, 90, 60, DateTime(2026, 10, 2, 9, 30), DateTime(2026, 10, 2, 16)),
    ])!;
    expect(a.days, 2);
    expect(a.split[TimeKind.client], 150);
    expect(a.split[TimeKind.driving], 75);
    expect(a.drivingKm, 50);
    expect(clockOf(a.firstClientMin!), '09:00');
    expect(clockOf(a.lastClientMin!), '15:30');
    expect(averageDayOf(const []), isNull);
  });

  test('PDF per person builds, in English and in Arabic with the bundled fonts', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting();
    final rows = build([
      visit('f1', 'sami', DateTime(2026, 10, 2, 9)),
      visit('s1', 'sami', DateTime(2026, 10, 3, 9)),
    ]);
    final bytes = await buildPersonPdf(
      of(rows, 'sami'),
      ReportPdfContext(
        l10n: AppLocalizationsEn(),
        languageCode: 'en',
        periodLabel: 'October 2026',
        teamSize: rows.length,
        clients: clients,
        tagLabel: (id) => id.isEmpty ? 'No type' : id,
        createdAt: DateTime(2026, 11, 1),
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final ar = await buildPersonPdf(
      of(rows, 'sami'),
      ReportPdfContext(
        l10n: AppLocalizationsAr(),
        languageCode: 'ar',
        periodLabel: 'أكتوبر 2026',
        teamSize: rows.length,
        clients: clients,
        tagLabel: (id) => id.isEmpty ? 'بدون نوع' : 'مصنع',
        createdAt: DateTime(2026, 11, 1),
        fonts: await loadReportFonts(),
        logo: await loadReportLogo(),
      ),
    );
    expect(String.fromCharCodes(ar.take(5)), '%PDF-');
    expect(reportPdfFileName(of(rows, 'sami'), 'Oct/2026'), 'sami - Oct2026.pdf');
  });

  test('fieldDistance leaves off days out', () {
    DayTimeline day(String d, double km) =>
        DayTimeline(uid: 'a', day: d, minutes: const {}, drivingKm: km, clientStays: const [], stops: const []);
    final days = [day('2026-10-29', 80), day('2026-10-30', 40), day('2026-10-31', 55.5)];
    // 30 Oct is a Friday.
    final d = fieldDistance(days, (d) => d == '2026-10-30');
    expect(d?.km, 135.5);
    expect(d?.days, 2);
    expect(fieldDistance(days, (_) => true), isNull);
    expect(fieldDistance(const [], (_) => false), isNull);
  });
}
