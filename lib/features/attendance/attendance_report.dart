import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/work_hours.dart';
import 'absence.dart';
import 'absence_sheet.dart' show absenceReasonLabel, absenceStatusText;
import 'attendance_calendar.dart';
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_rules.dart';

// Monthly attendance report (user request 2026-10-20): per person who needs
// attendance, the month's work days, days attended / missed / on leave,
// lateness, hours, overtime and time stayed after hours without overtime.
// Shown in the HR area and exported to Excel.

class AttendanceReportDay {
  const AttendanceReportDay(this.date, this.mark, this.result, [this.absence, this.approvedOvertimeMin]);

  final DateTime date;
  final DayMark mark;

  /// Null when there was no attendance that day.
  final DayResult? result;

  /// "Not coming to work" reported for the day.
  final Absence? absence;

  /// Overtime a manager approved that day (null = not approved; 2026-10-25).
  final int? approvedOvertimeMin;
}

class AttendanceReportRow {
  const AttendanceReportRow({required this.user, required this.schedule, required this.days});

  final AppUser user;
  final WorkHours schedule;
  final List<AttendanceReportDay> days;

  Iterable<DayResult> get _results => days.map((d) => d.result).whereType<DayResult>().where((r) => r.checkedIn);

  /// Their work days in the month (holidays left out), past and future.
  int get workDays => days.where((d) => d.mark != DayMark.off && schedule.days.contains(d.date.weekday)).length;
  int get attended => days.where((d) => d.mark == DayMark.attended).length;
  int get missed => days.where((d) => d.mark == DayMark.missed).length;
  int get leave => days.where((d) => d.mark == DayMark.leave).length;

  /// Work days reported beforehand as "not coming" (not counted as missed).
  int get absent => days.where((d) => d.mark == DayMark.absent && schedule.days.contains(d.date.weekday)).length;
  int get lateDays => _results.where((r) => (r.lateMin ?? 0) > 0).length;
  int get lateMin => _results.fold(0, (s, r) => s + (r.lateMin ?? 0));
  int get workedMin => _results.fold(0, (s, r) => s + (r.countedMin ?? 0));
  int get overtimeMin => _results.fold(0, (s, r) => s + (r.overtimeMin ?? 0));

  /// Overtime approved by managers (2026-10-25), possibly changed from what was recorded.
  int get approvedOvertimeMin => days.fold(0, (s, d) => s + (d.approvedOvertimeMin ?? 0));
  int get afterHoursMin => _results.fold(0, (s, r) => s + (r.afterHoursMin ?? 0));
}

final _key = DateFormat('yyyy-MM-dd');

/// One person's month. [results]: their days by 'yyyy-MM-dd'. Work days
/// count as missed from when they registered, else their first check-in in
/// the month, else the first of the month.
AttendanceReportRow reportRow({
  required AppUser user,
  required WorkHours schedule,
  required DateTime month,
  required Map<String, DayResult> results,
  required Set<String> holidays,
  required Set<String> leaveDays,
  Map<String, Absence> absences = const {},
  Map<String, int> approvedOvertime = const {},
  required DateTime today,
}) {
  final attended = {for (final MapEntry(:key, :value) in results.entries) if (value.checkedIn) key};
  final first = attended.isEmpty ? null : DateTime.parse((attended.toList()..sort()).first);
  final marks = markMonth(
    month: month,
    attended: attended,
    workDays: schedule.days,
    holidays: holidays,
    leaveDays: leaveDays,
    absentDays: {for (final e in absences.entries) if (e.value.pending) e.key},
    since: user.registeredAt ?? first ?? DateTime(month.year, month.month),
    today: today,
  );
  return AttendanceReportRow(
    user: user,
    schedule: schedule,
    days: [
      for (final MapEntry(key: d, value: m) in marks.entries)
        AttendanceReportDay(d, m, results[_key.format(d)], absences[_key.format(d)], approvedOvertime[_key.format(d)]),
    ],
  );
}

/// Labels and lookups the Excel file needs.
class AttendanceReportContext {
  const AttendanceReportContext({
    required this.l10n,
    required this.languageCode,
    required this.month,
    required this.siteNames,
    required this.roleLabel,
    required this.companyNames,
    required this.scheduleLabel,
  });

  final AppLocalizations l10n;
  final String languageCode;
  final DateTime month;
  final Map<String, String> siteNames;
  final String Function(AppUser) roleLabel;
  final Map<String, String> companyNames;
  final String Function(WorkHours) scheduleLabel;
}

String dayMarkLabel(AppLocalizations l10n, DayMark m) => switch (m) {
      DayMark.attended => l10n.dayAttended,
      DayMark.missed => l10n.dayMissed,
      DayMark.leave => l10n.dayOnLeave,
      DayMark.absent => l10n.reportedAbsent,
      DayMark.off => l10n.dayOff,
      DayMark.today || DayMark.future || DayMark.none => '',
    };

/// A day without a check-in: its mark, with the reason and note of a
/// reported absence ("Reported absent: Sick – fever").
/// A rejected absence is a missed day ("Missed · Not accepted …").
String reportDayStatus(AppLocalizations l10n, AttendanceReportDay d) => switch (d.absence) {
      final a? when d.mark == DayMark.absent || d.mark == DayMark.missed => [
          d.mark == DayMark.absent
              ? l10n.dayReportedAbsent(absenceReasonLabel(l10n, a.reason))
              : '${l10n.dayMissed} · ${absenceStatusText(l10n, a)} (${absenceReasonLabel(l10n, a.reason)})',
          if (a.note.isNotEmpty) a.note,
        ].join(' – '),
      _ => dayMarkLabel(l10n, d.mark),
    };

/// Decimal hours for Excel (8 h 30 → 8.5), so HR can add them up.
double hoursOf(int minutes) => (minutes / 60 * 100).round() / 100;

/// Two sheets: "Summary" (one row per person) and "Daily" (one row per
/// person and day). Right-to-left in Arabic.
List<int> buildAttendanceXlsx(List<AttendanceReportRow> rows, AttendanceReportContext x) {
  final l10n = x.l10n;
  final excel = Excel.createExcel();
  const summaryName = 'Summary', dailyName = 'Daily';
  excel.rename(excel.getDefaultSheet() ?? 'Sheet1', summaryName);
  excel.setDefaultSheet(summaryName);
  final bold = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#FFE8EEF4'));
  final clock = DateFormat('HH:mm');

  void header(Sheet sheet, List<String> titles, {Map<int, double> widths = const {}}) {
    sheet.isRTL = x.languageCode == 'ar';
    for (final (i, t) in titles.indexed) {
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), TextCellValue(t), cellStyle: bold);
      sheet.setColumnWidth(i, widths[i] ?? 16);
    }
  }

  final summary = excel[summaryName];
  header(summary, [
    l10n.reportEmployee,
    l10n.role,
    l10n.company,
    l10n.reportSchedule,
    l10n.reportWorkDays,
    l10n.dayAttended,
    l10n.reportMissed,
    l10n.dayOnLeave,
    l10n.reportedAbsent,
    l10n.reportLateDays,
    l10n.reportLateHours,
    l10n.reportWorkedHours,
    l10n.reportOvertimeHours,
    l10n.reportOvertimeApprovedHours,
    l10n.reportStayedAfterHours,
  ], widths: {0: 28, 4: 34});
  for (final r in rows) {
    summary.appendRow([
      TextCellValue(r.user.name),
      TextCellValue(x.roleLabel(r.user)),
      TextCellValue(x.companyNames[r.user.companyId] ?? ''),
      TextCellValue(x.scheduleLabel(r.schedule)),
      IntCellValue(r.workDays),
      IntCellValue(r.attended),
      IntCellValue(r.missed),
      IntCellValue(r.leave),
      IntCellValue(r.absent),
      IntCellValue(r.lateDays),
      DoubleCellValue(hoursOf(r.lateMin)),
      DoubleCellValue(hoursOf(r.workedMin)),
      DoubleCellValue(hoursOf(r.overtimeMin)),
      DoubleCellValue(hoursOf(r.approvedOvertimeMin)),
      DoubleCellValue(hoursOf(r.afterHoursMin)),
    ]);
  }

  final daily = excel[dailyName];
  header(daily, [
    l10n.reportEmployee,
    l10n.reportDate,
    l10n.reportStatus,
    l10n.reportSite,
    l10n.checkIn,
    l10n.checkOut,
    l10n.reportCheckOutType,
    l10n.reportLateMinutes,
    l10n.reportWorkedHours,
    l10n.reportOvertimeHours,
    l10n.reportOvertimeApprovedHours,
    l10n.reportStayedAfterHours,
  ], widths: {0: 28, 2: 22, 3: 22, 6: 26});
  final dayFormat = DateFormat('EEE yyyy-MM-dd', x.languageCode);
  for (final r in rows) {
    for (final d in r.days) {
      final res = d.result;
      final status = res != null && res.checkedIn ? l10n.dayAttended : reportDayStatus(l10n, d);
      if (status.isEmpty) continue; // future days, days before they started
      daily.appendRow([
        TextCellValue(r.user.name),
        TextCellValue(dayFormat.format(d.date)),
        TextCellValue(status),
        TextCellValue(x.siteNames[res?.siteId] ?? ''),
        res?.checkInAt == null ? null : TextCellValue(clock.format(res!.checkInAt!)),
        res?.checkOutAt == null ? null : TextCellValue(clock.format(res!.checkOutAt!)),
        res?.checkOutType == null ? null : TextCellValue(checkOutTypeLabel(l10n, res!.checkOutType)),
        res?.lateMin == null ? null : IntCellValue(res!.lateMin!),
        res?.countedMin == null ? null : DoubleCellValue(hoursOf(res!.countedMin!)),
        res?.overtimeMin == null ? null : DoubleCellValue(hoursOf(res!.overtimeMin!)),
        d.approvedOvertimeMin == null ? null : DoubleCellValue(hoursOf(d.approvedOvertimeMin!)),
        res?.afterHoursMin == null ? null : DoubleCellValue(hoursOf(res!.afterHoursMin!)),
      ]);
    }
  }
  return excel.encode()!;
}
