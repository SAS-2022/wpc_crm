import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/work_hours.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';

// Breaks on the Attendance page, the day sheet and the Employee Map
// (2026-11-05, break_request.dart).

/// [person]'s exits on [record]'s day before the end of their work day,
/// each with its break; empty for people who don't request breaks.
List<ExitCheck> personExitChecks(AppUser person, AttendanceRecord? record, DayResult? d, WorkHours company) {
  if (record == null || !person.requestsBreaks) return const [];
  final day = DateTime.parse(record.date);
  final hours = person.scheduleOr(company);
  return record.exitChecks(
    d,
    day.add(Duration(minutes: hours.endMinute)),
    // Exits before the work day starts aren't checked (2026-11-07).
    start: hours.days.contains(day.weekday) ? day.add(Duration(minutes: hours.startMinute)) : null,
  );
}

/// A break still waiting counts as no permission once its day is over.
bool exitWithoutPermission(ExitCheck c, {required bool today}) =>
    c.permission == ExitPermission.none ||
    c.permission == ExitPermission.refused ||
    (c.permission == ExitPermission.waiting && !today);

/// "Out 10:05 – back 10:40 · 35 min · On break (30 min approved) · 5 min longer than the break".
String exitCheckLine(AppLocalizations l10n, DateFormat time, ExitCheck c, {required bool today}) {
  final back = c.backAt;
  final where = back == null
      ? l10n.exitStillOut(time.format(c.leftAt))
      : l10n.siteTripLine(time.format(c.leftAt), time.format(back), formatMinutes(back.difference(c.leftAt).inMinutes));
  final permission = switch (c.permission) {
    ExitPermission.onBreak => [
        l10n.exitOnBreak(c.slot!.minutes),
        if (c.overMin > 0) l10n.exitBreakOver(formatMinutes(c.overMin)),
      ].join(' · '),
    ExitPermission.waiting => today ? l10n.exitBreakWaiting : l10n.leftWithoutPermission,
    ExitPermission.refused => l10n.exitBreakRefused,
    ExitPermission.none => l10n.leftWithoutPermission,
  };
  return '$where · $permission';
}

/// Colour of an exit line: red without permission, orange over the break /
/// waiting, plain otherwise.
Color? exitCheckColor(BuildContext context, ExitCheck c, {required bool today}) => exitWithoutPermission(c, today: today)
    ? Theme.of(context).colorScheme.error
    : c.overMin > 0 || c.permission == ExitPermission.waiting
    ? Colors.orange.shade800
    : null;

/// "Asked at 10:02 · 30 min · Approved by Ali".
String breakSlotLine(AppLocalizations l10n, DateFormat time, BreakSlot b, Map<String, AppUser> users, {required bool today}) =>
    [
      l10n.breakAskedLine(time.format(b.at), b.minutes),
      switch (b.status) {
        BreakStatus.approved => l10n.breakStatusApproved(users[b.decidedBy]?.name ?? ''),
        BreakStatus.rejected => l10n.breakStatusRejected(users[b.decidedBy]?.name ?? ''),
        BreakStatus.pending => today ? l10n.breakStatusPending : l10n.breakStatusExpired,
      },
    ].join(' · ');
