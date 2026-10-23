import 'dart:ui';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/absence.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wpc_crm/core/app_user.dart';
import 'package:wpc_crm/features/attendance/attendance_calendar.dart';
import 'package:wpc_crm/features/attendance/attendance_report.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';
import 'package:wpc_crm/l10n/app_localizations.dart';

AppUser _user({DateTime? registered, WorkHours? schedule}) => AppUser(
      id: 'u',
      name: 'Omar',
      email: '',
      phone: '',
      role: UserRole.worker,
      kamId: null,
      active: true,
      workSiteIds: const ['hq'],
      registeredAt: registered,
      workSchedule: schedule,
    );

DayResult _day(int d, {int late = 0, int counted = 540, int after = 0}) => DayResult(
      checkInAt: DateTime(2026, 10, d, 8, late),
      checkOutAt: DateTime(2026, 10, d, 17),
      checkOutType: 'left',
      siteId: 'hq',
      countedMin: counted,
      overtimeMin: 0,
      lateMin: late,
      afterHoursMin: after,
    );

void main() {
  setUpAll(() => initializeDateFormatting());
  // October 2026: 1 Oct is a Thursday; work days Sat–Thu.
  final month = DateTime(2026, 10);
  final today = DateTime(2026, 10, 8); // Thursday

  AttendanceReportRow row({
    Map<String, DayResult> results = const {},
    Set<String> leave = const {},
    Map<String, Absence> absences = const {},
    AppUser? user,
  }) => reportRow(
        user: user ?? _user(),
        schedule: (user ?? _user()).scheduleOr(WorkHours.defaults),
        month: month,
        results: results,
        holidays: const {'2026-10-05'},
        leaveDays: leave,
        absences: absences,
        today: today,
      );

  test('counts days, lateness, hours and time stayed after hours', () {
    final r = row(
      results: {'2026-10-01': _day(1, late: 12), '2026-10-03': _day(3, after: 40), '2026-10-04': _day(4, late: 20)},
      leave: {'2026-10-06'},
    );
    // Work days in October minus the holiday: 31 days − 5 Fridays − 1 holiday.
    expect(r.workDays, 25);
    expect(r.attended, 3);
    expect(r.leave, 1);
    // 1 Oct–7 Oct: work days 1, 3, 4, 6 (leave), 7 → only the 7th missed; 8th = today.
    expect(r.missed, 1);
    expect([r.lateDays, r.lateMin, r.workedMin, r.afterHoursMin], [2, 32, 1620, 40]);
  });

  test('missed days count from registration', () {
    final r = row(user: _user(registered: DateTime(2026, 10, 6)));
    expect(r.missed, 2); // the 6th and 7th
  });

  test('own schedule: Sunday–Thursday only', () {
    final r = row(
      user: _user(
        schedule: const WorkHours(days: {7, 1, 2, 3, 4}, startMinute: 9 * 60, endMinute: 18 * 60),
      ),
    );
    expect(r.days.firstWhere((d) => d.date.day == 3).mark, DayMark.off); // Saturday
  });

  test('Excel has a summary and a daily sheet', () {
    final r = row(results: {'2026-10-01': _day(1, late: 12)});
    final bytes = buildAttendanceXlsx(
      [r],
      AttendanceReportContext(
        l10n: lookupAppLocalizations(const Locale('en')),
        languageCode: 'en',
        month: month,
        siteNames: const {'hq': 'Head office'},
        roleLabel: (_) => 'Worker',
        companyNames: const {},
        scheduleLabel: (_) => 'Sat–Thu',
      ),
    );
    final excel = Excel.decodeBytes(bytes);
    final summary = excel['Summary'];
    expect(summary.row(1).first?.value.toString(), 'Omar');
    final daily = excel['Daily'];
    expect(daily.row(1)[3]?.value.toString(), 'Head office');
    expect(daily.row(1)[7]?.value.toString(), '12');
  });

  test('reported absences are counted apart from missed days', () {
    const sick = Absence(uid: 'u', date: '2026-10-07', reason: AbsenceReason.sick, note: 'fever');
    final base = row();
    final r = row(absences: {'2026-10-07': sick});
    expect(r.absent, 1);
    expect(r.missed, base.missed - 1);
    expect(r.days.firstWhere((d) => d.date == DateTime(2026, 10, 7)).absence, sick);
  });

  test('a rejected absence is a missed day; only waiting ones are "reported absent"', () {
    const no = Absence(uid: 'u', date: '2026-10-07', reason: AbsenceReason.tired, note: '', status: AbsenceStatus.rejected);
    final r = row(absences: {'2026-10-07': no});
    expect([r.absent, r.missed], [0, row().missed]);
  });
}
