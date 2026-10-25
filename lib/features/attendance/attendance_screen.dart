import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../notifications/notifications.dart' show peopleUnder;
import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../plan/plan_screen.dart' show DayBar;
import '../tracking/work_hours.dart';
import '../users/companies.dart';
import '../users/users_repository.dart';
import 'absence.dart';
import 'absence_sheet.dart' show absenceReasonIcon, absenceReasonLabel, absenceStatusText;
import 'attendance_correction.dart';
import '../hr/leave_repository.dart';
import '../hr/leave_rules.dart';
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_day.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'work_sites.dart';

/// Which people the summary tiles narrow the list to.
enum _Show { all, onSite, notOnSite, checkedOut }

/// The three ways to read the day (user request 2026-10-21).
enum _View { status, hours, delays }

/// HR area, GM, sales manager: one day's attendance of everyone assigned to
/// a work site (2026-10-21 redesign): summary tiles (on site / not on site /
/// checked out / worked so far / delays), search + filters (site, role,
/// company), and three views — status sections, worked hours so far against
/// each schedule, and delays (late check-ins and people not in yet).
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, this.initialDate});

  /// The day shown first (`/attendance?date=`); today when null.
  final DateTime? initialDate;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late DateTime _day = widget.initialDate ?? DateTime.now();
  _Show _show = _Show.all;
  _View _view = _View.status;
  String _query = '';
  final _sites = <String>{};
  final _roles = <UserRole>{};
  final _companies = <String>{};

  int get _filterCount => _sites.length + _roles.length + _companies.length;

  Future<void> _openFilters(List<WorkSite> sites, List<UserRole> roles, List<Company> companies) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) => StatefulBuilder(
          builder: (sheet, setSheet) {
            final l10n = AppLocalizations.of(sheet);
            void toggle<T>(Set<T> set, T v) {
              setSheet(() => set.contains(v) ? set.remove(v) : set.add(v));
              setState(() {});
            }

            Widget section(String title, List<Widget> chips) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(sheet).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: chips),
                    ],
                  ),
                );
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sites.length > 1)
                      section(l10n.workSites, [
                        for (final s in sites)
                          FilterChip(label: Text(s.name), selected: _sites.contains(s.id), onSelected: (_) => toggle(_sites, s.id)),
                      ]),
                    if (roles.length > 1)
                      section(l10n.role, [
                        for (final r in roles)
                          FilterChip(label: Text(r.label(l10n)), selected: _roles.contains(r), onSelected: (_) => toggle(_roles, r)),
                      ]),
                    if (companies.length > 1)
                      section(l10n.company, [
                        for (final c in companies)
                          FilterChip(label: Text(c.name), selected: _companies.contains(c.id), onSelected: (_) => toggle(_companies, c.id)),
                      ]),
                    TextButton(
                      onPressed: () {
                        setSheet(() {
                          _sites.clear();
                          _roles.clear();
                          _companies.clear();
                        });
                        setState(() {});
                      },
                      child: Text(l10n.clearAllFilters),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = DateFormat.jm(Localizations.localeOf(context).toString());
    final dayKey = attendanceDay(_day);
    final midnight = DateTime(_day.year, _day.month, _day.day);
    final now = DateTime.now();
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final sites = ref.watch(workSitesProvider).value ?? const <WorkSite>[];
    final siteNames = {for (final s in sites) s.id: s.name};
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];
    final me = ref.watch(currentUserProvider).value;
    final allUsers = ref.watch(usersProvider).value ?? const <AppUser>[];
    // HR area: everyone; other managers: the people under them (2026-10-23).
    final visible = me == null || me.role.canSeeHr ? allUsers : peopleUnder(me, allUsers);
    final everyone = [
      for (final u in visible)
        if (u.active && u.checksAttendance) u,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final records = ref.watch(dayAttendanceProvider(dayKey)).value ?? const <String, AttendanceRecord>{};
    final absences = ref.watch(dayAbsencesProvider(dayKey)).value ?? const <String, Absence>{};
    // Approved leave covering the day, by person.
    final leave = {
      for (final r in ref.watch(allLeaveRequestsProvider).value ?? const <LeaveRequest>[])
        if (r.isLeave && r.status == LeaveStatus.approved && r.from != null && r.to != null &&
            r.from!.compareTo(dayKey) <= 0 && r.to!.compareTo(dayKey) >= 0)
          r.uid: r,
    };
    final role = me?.role;
    final canOpenUsers = role?.isAdmin ?? false;
    final canCorrect = role?.canManageHr ?? false;

    // Each person's day: the server's result (or the same rules here until
    // it has the day), then status, hours so far and delay.
    final results = {for (final u in everyone) u.id: records[u.id]?.best(u, company)};
    final days = {
      for (final u in everyone)
        u.id: personDay(
          results[u.id],
          schedule: u.scheduleOr(company),
          overtimeAllowed: u.overtimeAllowed,
          overtimeMaxMin: u.overtimeCapMin,
          day: midnight,
          now: now,
          reportedAbsent: absences.containsKey(u.id),
          onLeave: leave.containsKey(u.id),
        ),
    };

    // Search and filters (site, role, company); the tiles count these people.
    final q = Client.normalizeName(_query);
    final filtered = [
      for (final u in everyone)
        if ((q.isEmpty || Client.normalizeName(u.name).contains(q)) &&
            (_sites.isEmpty || u.workSiteIds.any(_sites.contains)) &&
            (_roles.isEmpty || _roles.contains(u.role)) &&
            (_companies.isEmpty || _companies.contains(u.companyId)))
          u,
    ];
    bool shows(AppUser u) => switch (_show) {
          _Show.all => true,
          _Show.onSite => days[u.id]!.status == DayStatus.onSite,
          _Show.notOnSite =>
            const [DayStatus.away, DayStatus.notIn, DayStatus.absent, DayStatus.onLeave].contains(days[u.id]!.status),
          _Show.checkedOut => days[u.id]!.status == DayStatus.checkedOut,
        };
    final shown = filtered.where(shows).toList();

    int count(bool Function(PersonDay) test) => filtered.where((u) => test(days[u.id]!)).length;
    final onSite = count((d) => d.status == DayStatus.onSite);
    final notOnSite =
        count((d) => const [DayStatus.away, DayStatus.notIn, DayStatus.absent, DayStatus.onLeave].contains(d.status));
    final checkedOut = count((d) => d.status == DayStatus.checkedOut);
    final workedTotal = filtered.fold(0, (n, u) => n + days[u.id]!.workedMin);
    final late = filtered.where((u) => days[u.id]!.lateMin > 0).toList();
    final lateTotal = late.fold(0, (n, u) => n + days[u.id]!.lateMin);

    String siteOf(AppUser u) =>
        siteNames[results[u.id]?.siteId] ?? u.workSiteIds.map((id) => siteNames[id]).nonNulls.firstOrNull ?? '';

    Widget avatar(AppUser u, Color color, IconData icon) =>
        CircleAvatar(backgroundColor: color.withValues(alpha: 0.14), child: Icon(icon, color: color));

    // Status view row: what happened today.
    Widget statusRow(AppUser u) {
      final d = results[u.id];
      final p = days[u.id]!;
      final (IconData icon, Color color, String line) = switch (p.status) {
        DayStatus.notIn => (
            Icons.person_off_outlined,
            theme.colorScheme.outline,
            p.notInYet ? '${l10n.notCheckedIn} · ${l10n.lateBy(formatMinutes(p.lateMin))}' : l10n.notCheckedIn,
          ),
        DayStatus.absent => (
            absenceReasonIcon(absences[u.id]!.reason),
            Colors.orange.shade800,
            [
              absenceReasonLabel(l10n, absences[u.id]!.reason),
              absences[u.id]!.note,
              absenceStatusText(l10n, absences[u.id]!),
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
        DayStatus.onLeave => (
            Icons.beach_access,
            Colors.blue.shade600,
            leave[u.id]?.typeName(Localizations.localeOf(context).languageCode) ?? l10n.dayOnLeave,
          ),
        DayStatus.onSite || DayStatus.away => (
            p.status == DayStatus.onSite ? Icons.how_to_reg : Icons.directions_walk,
            p.status == DayStatus.onSite ? Colors.green.shade700 : Colors.orange.shade800,
            [
              l10n.inSince(time.format(d!.checkInAt!)),
              if (p.lateMin > 0) l10n.lateBy(formatMinutes(p.lateMin)),
              if (p.status == DayStatus.away && d.lastExitAt != null) l10n.leftSiteAt(time.format(d.lastExitAt!)),
            ].join(' · '),
          ),
        DayStatus.checkedOut => (
            Icons.logout,
            theme.colorScheme.primary,
            [
              '${time.format(d!.checkInAt!)} – ${time.format(d.checkOutAt!)}',
              checkOutTypeLabel(l10n, d.checkOutType),
              if (p.lateMin > 0) l10n.lateBy(formatMinutes(p.lateMin)),
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
      };
      return ListTile(
        leading: avatar(u, color, icon),
        title: Text(u.name),
        subtitle: Text([
          [u.role.label(l10n), siteOf(u)].where((s) => s.isNotEmpty).join(' · '),
          line,
          if (records[u.id]?.correction != null) l10n.correctedByHr,
        ].join('\n')),
        isThreeLine: true,
        trailing: p.workedMin > 0 ? Text(formatMinutes(p.workedMin), style: theme.textTheme.titleSmall) : null,
        onTap: () => showAttendanceDaySheet(
          context,
          person: u,
          day: midnight,
          record: records[u.id],
          result: d,
          absence: absences[u.id],
          canCorrect: canCorrect,
          canOpenUser: canOpenUsers,
        ),
      );
    }

    // Worked hours view row: so far against their scheduled day.
    Widget hoursRow(AppUser u) {
      final p = days[u.id]!;
      final d = results[u.id];
      final open = p.status == DayStatus.onSite || p.status == DayStatus.away;
      final share = p.scheduledMin == 0 ? 0.0 : (p.workedMin / p.scheduledMin).clamp(0.0, 1.0);
      return ListTile(
        title: Text(u.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 8,
                color: open ? Colors.green.shade600 : theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text([
              if (p.scheduledMin > 0) l10n.workedOf(formatMinutes(p.workedMin), formatMinutes(p.scheduledMin)) else l10n.dayOff,
              if (open) l10n.stillIn,
              if ((d?.overtimeMin ?? 0) > 0) l10n.overtimeTime(formatMinutes(d!.overtimeMin!)),
            ].join(' · ')),
          ],
        ),
        trailing: Text(formatMinutes(p.workedMin), style: theme.textTheme.titleMedium),
        onTap: canOpenUsers ? () => context.push('/users/${u.id}') : null,
      );
    }

    // Delays view row: late check-in, or not in yet after their start.
    Widget delayRow(AppUser u) {
      final p = days[u.id]!;
      final d = results[u.id];
      final start = midnight.add(Duration(minutes: u.scheduleOr(company).startMinute));
      return ListTile(
        leading: avatar(u, theme.colorScheme.error, p.notInYet ? Icons.hourglass_bottom : Icons.schedule),
        title: Text(u.name),
        subtitle: Text([
          l10n.startAt(time.format(start)),
          if (p.notInYet) l10n.notInYet else l10n.checkedInAtTime(time.format(d!.checkInAt!)),
          siteOf(u),
        ].where((s) => s.isNotEmpty).join(' · ')),
        trailing: Text(
          formatMinutes(p.lateMin),
          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
        ),
        onTap: canOpenUsers ? () => context.push('/users/${u.id}') : null,
      );
    }

    Widget header(String text, int n) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('$text ($n)', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    final List<Widget> content;
    switch (_view) {
      case _View.status:
        content = [
          for (final (status, title) in [
            (DayStatus.onSite, l10n.onSite),
            (DayStatus.away, l10n.leftTheSite),
            (DayStatus.notIn, l10n.notCheckedIn),
            (DayStatus.absent, l10n.reportedAbsent),
            (DayStatus.onLeave, l10n.dayOnLeave),
            (DayStatus.checkedOut, l10n.checkedOutTitle),
          ])
            if (shown.where((u) => days[u.id]!.status == status).toList() case final list when list.isNotEmpty) ...[
              header(title, list.length),
              for (final u in list) statusRow(u),
            ],
        ];
      case _View.hours:
        final list = [...shown]..sort((a, b) => days[b.id]!.workedMin.compareTo(days[a.id]!.workedMin));
        content = [for (final u in list) hoursRow(u)];
      case _View.delays:
        final list = [for (final u in shown) if (days[u.id]!.lateMin > 0) u]
          ..sort((a, b) => days[b.id]!.lateMin.compareTo(days[a.id]!.lateMin));
        content = list.isEmpty
            ? [Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.noDelays)))]
            : [for (final u in list) delayRow(u)];
    }

    Widget tile(String label, String value, IconData icon, Color color, {_Show? show}) {
      final selected = show != null && _show == show;
      return Card(
        margin: EdgeInsets.zero,
        color: selected ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: selected ? BorderSide(color: color, width: 1.5) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Tapping a status tile shows only those people; again = everyone.
          onTap: show == null ? null : () => setState(() => _show = selected ? _Show.all : show),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 6),
                Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(label, style: theme.textTheme.bodySmall, maxLines: 2),
              ],
            ),
          ),
        ),
      );
    }

    final roles = {for (final u in everyone) u.role}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final usedCompanies = [for (final c in companies) if (everyone.any((u) => u.companyId == c.id)) c];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.attendance),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.table_chart_outlined),
            label: Text(l10n.attendanceReport),
            onPressed: () => context.push('/attendance/report'),
          ),
        ],
      ),
      body: everyone.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.noOneAssignedToSites, textAlign: TextAlign.center)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
                // Summary: who is on site and who isn't, hours so far, delays.
                // A grid (3 a row on phones) so none is hidden off screen.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(builder: (context, c) {
                    final tiles = [
                      tile(l10n.onSite, '$onSite', Icons.how_to_reg, Colors.green.shade700, show: _Show.onSite),
                      tile(l10n.notOnSite, '$notOnSite', Icons.person_off_outlined, Colors.orange.shade800, show: _Show.notOnSite),
                      tile(l10n.checkedOutTitle, '$checkedOut', Icons.logout, theme.colorScheme.primary, show: _Show.checkedOut),
                      tile(l10n.workedSoFar, formatMinutes(workedTotal), Icons.timer_outlined, Colors.teal),
                      tile(l10n.delaysCount(late.length), formatMinutes(lateTotal), Icons.schedule, theme.colorScheme.error),
                    ];
                    final perRow = c.maxWidth >= 700 ? tiles.length : 3;
                    return Column(children: [
                      for (var i = 0; i < tiles.length; i += perRow)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                          child: IntrinsicHeight(
                            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              for (var j = i; j < i + perRow; j++) ...[
                                if (j > i) const SizedBox(width: 8),
                                // Empty places keep the last row's tiles the same width.
                                Expanded(child: j < tiles.length ? tiles[j] : const SizedBox.shrink()),
                              ],
                            ]),
                          ),
                        ),
                    ]);
                  }),
                ),
                // Search and filters.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchBar(
                          hintText: l10n.searchByName,
                          leading: const Icon(Icons.search),
                          elevation: const WidgetStatePropertyAll(0),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: _filterCount > 0,
                        label: Text('$_filterCount'),
                        child: IconButton.filledTonal(
                          tooltip: l10n.filters,
                          icon: const Icon(Icons.filter_list),
                          onPressed: () => _openFilters(sites, roles, usedCompanies),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SegmentedButton<_View>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: _View.status, icon: const Icon(Icons.groups_outlined), label: Text(l10n.viewStatus)),
                      ButtonSegment(value: _View.hours, icon: const Icon(Icons.timer_outlined), label: Text(l10n.viewWorkedHours)),
                      ButtonSegment(value: _View.delays, icon: const Icon(Icons.schedule), label: Text(l10n.viewDelays)),
                    ],
                    selected: {_view},
                    onSelectionChanged: (v) => setState(() => _view = v.first),
                  ),
                ),
                if (shown.isEmpty)
                  Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.noOneMatches)))
                else
                  ...content,
              ],
            ),
    );
  }
}
