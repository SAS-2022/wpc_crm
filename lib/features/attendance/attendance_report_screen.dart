import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_user.dart';
import '../../core/save_file.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client_tags.dart';
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import '../tracking/work_hours.dart';
import '../tracking/work_hours_editor.dart';
import '../users/companies.dart';
import '../users/users_repository.dart';
import 'attendance_calendar.dart';
import 'attendance_calendar_view.dart' show dayMarkColor;
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_report.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'work_sites.dart';

const _xlsxType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// HR area: the month's attendance per person who needs it (days, lateness,
/// hours, overtime, time stayed after hours) and the Excel export.
class AttendanceReportScreen extends ConsumerStatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  ConsumerState<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends ConsumerState<AttendanceReportScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _export(List<AttendanceReportRow> rows, AttendanceReportContext x) async {
    final bytes = buildAttendanceXlsx(rows, x);
    final name = 'attendance_${DateFormat('yyyy-MM').format(_month)}.xlsx';
    if (kIsWeb) {
      saveBytes(bytes, name, _xlsxType);
    } else {
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: _xlsxType, name: name)],
        fileNameOverrides: [name],
      ));
    }
  }

  void _showPerson(AttendanceReportRow r, Map<String, String> siteNames) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale);
    final scheme = Theme.of(context).colorScheme;
    final days = r.days.where((d) => d.result?.checkedIn == true || dayMarkLabel(l10n, d.mark).isNotEmpty).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            ListTile(
              title: Text(r.user.name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text('${DateFormat.yMMMM(locale).format(_month)} · ${WorkHoursEditor.summary(context, r.schedule)}'),
            ),
            const Divider(height: 1),
            for (final d in days)
              ListTile(
                dense: true,
                leading: Icon(Icons.circle, size: 12, color: dayMarkColor(d.mark, scheme)),
                title: Text(DateFormat.MMMEd(locale).format(d.date)),
                subtitle: Text(switch (d.result) {
                  final res? when res.checkedIn => [
                      [
                        time.format(res.checkInAt!),
                        if (res.checkOutAt != null) time.format(res.checkOutAt!),
                      ].join(' – '),
                      ?siteNames[res.siteId],
                      if ((res.lateMin ?? 0) > 0) l10n.lateBy(formatMinutes(res.lateMin!)),
                      if (res.checkOutType != null) checkOutTypeLabel(l10n, res.checkOutType),
                      if ((res.overtimeMin ?? 0) > 0) l10n.overtimeTime(formatMinutes(res.overtimeMin!)),
                      if ((res.afterHoursMin ?? 0) > 0) l10n.stayedAfterTime(formatMinutes(res.afterHoursMin!)),
                    ].where((s) => s.isNotEmpty).join(' · '),
                  _ => dayMarkLabel(l10n, d.mark),
                }),
                trailing: d.result?.countedMin == null ? null : Text(formatMinutes(d.result!.countedMin!)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lang = Localizations.localeOf(context).languageCode;
    final monthKey = DateFormat('yyyy-MM').format(_month);
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final records = ref.watch(monthAttendanceProvider(monthKey));
    final holidays = ref.watch(holidaysProvider).value ?? const <String>{};
    final requests = ref.watch(allLeaveRequestsProvider).value ?? const <LeaveRequest>[];
    final sites = ref.watch(workSitesProvider).value ?? const <WorkSite>[];
    final siteNames = {for (final s in sites) s.id: s.name};
    final positions = ref.watch(positionsByIdProvider);
    final companies = {for (final c in ref.watch(companiesProvider).value ?? const <Company>[]) c.id: c.name};
    final people = [
      for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
        if (u.active && u.checksAttendance) u,
    ]..sort((a, b) => a.name.compareTo(b.name));

    final byUser = <String, Map<String, DayResult>>{};
    final users = {for (final u in people) u.id: u};
    for (final r in records.value ?? const <AttendanceRecord>[]) {
      final u = users[r.uid];
      if (u != null) (byUser[r.uid] ??= {})[r.date] = r.best(u, company);
    }
    final now = DateTime.now();
    final rows = [
      for (final u in people)
        reportRow(
          user: u,
          schedule: u.scheduleOr(company),
          month: _month,
          results: byUser[u.id] ?? const {},
          holidays: holidays,
          leaveDays: {
            for (final r in requests)
              if (r.uid == u.id && r.isLeave && r.status == LeaveStatus.approved && r.from != null && r.to != null)
                ...daysBetween(r.from!, r.to!),
          },
          today: now,
        ),
    ];
    final x = AttendanceReportContext(
      l10n: l10n,
      languageCode: lang,
      month: _month,
      siteNames: siteNames,
      roleLabel: (u) => u.role.label(l10n),
      positionLabel: (u) => u.position.isEmpty ? '' : positionLabel(positions, u.position, lang),
      companyNames: companies,
      scheduleLabel: (h) => WorkHoursEditor.summary(context, h),
    );
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.attendanceReport),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: l10n.exportClients,
            onPressed: rows.isEmpty || records.isLoading ? null : () => _export(rows, x),
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(DateFormat.yMMMM(locale).format(_month), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrentMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          Expanded(
            child: records.isLoading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.attendanceReportEmpty, textAlign: TextAlign.center)))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          return ListTile(
                            title: Text(r.user.name),
                            subtitle: Text([
                              l10n.reportSummaryLine(r.attended, r.workDays, r.missed, r.leave),
                              [
                                if (r.lateDays > 0) l10n.reportLateLine(r.lateDays, formatMinutes(r.lateMin)),
                                if (r.overtimeMin > 0) l10n.overtimeTime(formatMinutes(r.overtimeMin)),
                                if (r.afterHoursMin > 0) l10n.reportStayedLine(formatMinutes(r.afterHoursMin)),
                              ].join(' · '),
                            ].where((s) => s.isNotEmpty).join('\n')),
                            trailing: Text(formatMinutes(r.workedMin), style: theme.textTheme.titleSmall),
                            onTap: () => _showPerson(r, siteNames),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
