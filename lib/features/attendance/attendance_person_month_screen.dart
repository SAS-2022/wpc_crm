import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import 'attendance_rules.dart' show formatMinutes;
import '../tracking/work_hours_editor.dart';
import 'attendance_calendar.dart';
import 'attendance_calendar_view.dart' show dayMarkColor;
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_report.dart';
import 'attendance_report_screen.dart' show watchAttendanceReport;
import 'work_sites.dart';

/// Web, from the monthly attendance report (user request 2026-10-31): one
/// person's month as a calendar, each day with its check-in, check-out,
/// worked, away, late, overtime and after-hours times. A day with more
/// than fits shows "+n more"; tapping a day shows everything. Phones keep
/// the report's bottom sheet.
class AttendancePersonMonthScreen extends ConsumerStatefulWidget {
  const AttendancePersonMonthScreen({super.key, required this.uid, this.month});

  final String uid;

  /// 'yyyy-MM'; null = this month.
  final String? month;

  @override
  ConsumerState<AttendancePersonMonthScreen> createState() => _AttendancePersonMonthScreenState();
}

/// One line of a day: "In 08:02 · Riyadh office".
typedef _Line = ({String label, String value, Color? color});

class _AttendancePersonMonthScreenState extends ConsumerState<AttendancePersonMonthScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final parsed = DateTime.tryParse('${widget.month ?? ''}-01');
    final now = DateTime.now();
    _month = DateTime((parsed ?? now).year, (parsed ?? now).month);
  }

  List<_Line> _lines(AttendanceReportDay d, AppLocalizations l10n, DateFormat time, Map<String, String> sites) {
    final res = d.result;
    if (res == null || !res.checkedIn) {
      final status = reportDayStatus(l10n, d);
      return status.isEmpty
          ? const []
          : [(label: status, value: '', color: dayMarkColor(d.mark, Theme.of(context).colorScheme))];
    }
    final warn = Colors.orange.shade800;
    return [
      (label: l10n.calIn, value: [time.format(res.checkInAt!), ?sites[res.siteId]].join(' · '), color: null),
      if (res.checkOutAt != null)
        (
          label: l10n.calOut,
          value: '${time.format(res.checkOutAt!)} · ${checkOutTypeLabel(l10n, res.checkOutType)}',
          color: null,
        ),
      if (res.countedMin != null) (label: l10n.calWorked, value: formatMinutes(res.countedMin!), color: null),
      if ((res.lateMin ?? 0) > 0)
        (label: l10n.calLate, value: formatMinutes(res.lateMin!), color: Theme.of(context).colorScheme.error),
      if ((res.awayMin ?? 0) > 0) (label: l10n.calAway, value: formatMinutes(res.awayMin!), color: warn),
      if ((res.overtimeMin ?? 0) > 0)
        (
          label: l10n.calOvertime,
          value:
              '${formatMinutes(res.overtimeMin!)} · ${d.approvedOvertimeMin == null ? l10n.calOvertimeWaiting : l10n.calOvertimeApproved(formatMinutes(d.approvedOvertimeMin!))}',
          color: Colors.purple.shade400,
        ),
      if ((res.afterHoursMin ?? 0) > 0)
        (label: l10n.calAfterHours, value: formatMinutes(res.afterHoursMin!), color: null),
      if (res.checkInEventAt != null)
        (label: l10n.arrivedByGps(time.format(res.checkInEventAt!)), value: '', color: null),
      if (res.overtimeEndUnknown && res.lastSeenAt != null)
        (label: l10n.overtimeEndUnknown(time.format(res.lastSeenAt!)), value: '', color: warn),
      if (res.checkInSource == 'hr') (label: l10n.correctedByHr, value: '', color: null),
    ];
  }

  void _showDay(AttendanceReportDay d, List<_Line> lines) {
    final locale = Localizations.localeOf(context).toString();
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.circle, size: 14, color: dayMarkColor(d.mark, Theme.of(context).colorScheme)),
            const SizedBox(width: 8),
            Expanded(child: Text(DateFormat.yMMMMEEEEd(locale).format(d.date))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: _LineText(l)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale);
    final report = watchAttendanceReport(ref, _month);
    final row = report.rows.where((r) => r.user.id == widget.uid).firstOrNull;
    final sites = {for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[]) s.id: s.name};
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    // Weeks start on the locale's first day, as in the person's own calendar.
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final names = DateFormat.E(locale).dateSymbols.STANDALONEWEEKDAYS; // Sunday first
    final lead = (DateTime(_month.year, _month.month, 1).weekday % 7 - firstWeekday) % 7;
    final cells = <AttendanceReportDay?>[for (var i = 0; i < lead; i++) null, ...?row?.days];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Scaffold(
      appBar: AppBar(title: Text(row?.user.name ?? '')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrentMonth
                    ? null
                    : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          if (report.loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (row == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(l10n.personMonthEmpty)),
            )
          else ...[
            Text(
              WorkHoursEditor.summary(context, row.schedule),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _Summary(row: row),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        names[(firstWeekday + i) % 7],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  ),
              ],
            ),
            for (var w = 0; w < cells.length ~/ 7; w++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in cells.sublist(w * 7, w * 7 + 7))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: d == null
                              ? const SizedBox(height: _DayCell.height)
                              : Builder(
                                  builder: (_) {
                                    final lines = _lines(d, l10n, time, sites);
                                    return _DayCell(
                                      day: d,
                                      lines: lines,
                                      onTap: lines.isEmpty ? null : () => _showDay(d, lines),
                                    );
                                  },
                                ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LineText extends StatelessWidget {
  const _LineText(this.line, {this.maxLines});

  final _Line line;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.copyWith(color: line.color);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: line.label,
            style: TextStyle(fontWeight: line.value.isEmpty ? null : FontWeight.w600),
          ),
          if (line.value.isNotEmpty) TextSpan(text: ' ${line.value}'),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// A calendar day: number with the day's colour, then as many lines as fit.
class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.lines, this.onTap});

  static const height = 132.0;
  static const _shown = 5;

  final AttendanceReportDay day;
  final List<_Line> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = dayMarkColor(day.mark, scheme);
    final strong =
        day.mark == DayMark.attended ||
        day.mark == DayMark.missed ||
        day.mark == DayMark.leave ||
        day.mark == DayMark.absent;
    final muted = day.mark == DayMark.off || day.mark == DayMark.future || day.mark == DayMark.none;
    final extra = lines.length - _shown;
    return Material(
      color: strong ? color.withValues(alpha: 0.07) : (muted ? scheme.surfaceContainerLow : scheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: day.mark == DayMark.today ? color : scheme.outlineVariant,
          width: day.mark == DayMark.today ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: strong ? color : Colors.transparent, width: 4)),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 6, 4),
          child: DefaultTextStyle(
            style: theme.textTheme.bodySmall!.copyWith(height: 1.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.date.day}',
                  style: theme.textTheme.titleSmall?.copyWith(color: muted ? scheme.outline : (strong ? color : null)),
                ),
                const SizedBox(height: 2),
                for (final l in lines.take(extra > 0 ? _shown - 1 : _shown)) _LineText(l, maxLines: 1),
                if (extra > 0)
                  Text(
                    AppLocalizations.of(context).calMore(extra + 1),
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Month totals above the calendar.
class _Summary extends StatelessWidget {
  const _Summary({required this.row});

  final AttendanceReportRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String text, [Color? color]) => Chip(
      avatar: color == null ? null : Icon(Icons.circle, size: 12, color: color),
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          l10n.reportSummaryLine(row.attended, row.workDays, row.missed, row.leave),
          dayMarkColor(DayMark.attended, scheme),
        ),
        chip(l10n.monthHours(formatMinutes(row.workedMin))),
        if (row.absent > 0) chip(l10n.daysReportedAbsent(row.absent), dayMarkColor(DayMark.absent, scheme)),
        if (row.lateDays > 0) chip(l10n.reportLateLine(row.lateDays, formatMinutes(row.lateMin)), scheme.error),
        if (row.overtimeMin > 0)
          chip(
            '${l10n.overtimeTime(formatMinutes(row.overtimeMin))} (${l10n.overtimeApprovedText(formatMinutes(row.approvedOvertimeMin))})',
            Colors.purple.shade400,
          ),
        if (row.afterHoursMin > 0) chip(l10n.reportStayedLine(formatMinutes(row.afterHoursMin))),
      ],
    );
  }
}
