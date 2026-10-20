import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../plan/plan_screen.dart' show DayBar;
import '../tracking/work_hours.dart';
import '../users/users_repository.dart';
import 'attendance_card.dart' show checkOutTypeLabel;
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'work_sites.dart';
import '../clients/client_tags.dart';

/// HR area, GM, sales manager: one day's attendance of everyone assigned to
/// a work site, by site: who is in, left, checked out or not checked in,
/// with check-in / check-out times, hours and overtime.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = DateFormat.jm(Localizations.localeOf(context).toString());
    final day = attendanceDay(_day);
    final hours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final sites = ref.watch(workSitesProvider).value ?? const <WorkSite>[];
    final people = [
      for (final u in ref.watch(usersProvider).value ?? const <AppUser>[])
        if (u.active && u.checksAttendance) u,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final records = ref.watch(dayAttendanceProvider(day)).value ?? const <String, AttendanceRecord>{};
    final positions = ref.watch(positionsByIdProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final canOpenUsers = ref.watch(currentUserProvider).value?.role.isAdmin ?? false;

    // The server's result once it has the day; until then the same rules here.
    DayResult? resultOf(AppUser u) {
      final r = records[u.id];
      if (r == null) return null;
      return r.best(u, hours);
    }

    final results = {for (final u in people) u.id: resultOf(u)};
    final inNow = results.values.where((d) => d != null && d.checkedIn && !d.closed).length;
    final out = results.values.where((d) => d != null && d.closed).length;
    final absent = results.values.where((d) => d == null || !d.checkedIn).length;

    Widget row(AppUser u) {
      final d = results[u.id];
      final String status;
      final Color color;
      if (d == null || !d.checkedIn) {
        status = l10n.notCheckedIn;
        color = theme.colorScheme.outline;
      } else if (!d.closed) {
        status = [
          l10n.inSince(time.format(d.checkInAt!)),
          if ((d.lateMin ?? 0) > 0) l10n.lateBy(formatMinutes(d.lateMin!)),
          if (!d.inside && d.lastExitAt != null) l10n.leftSiteAt(time.format(d.lastExitAt!)),
        ].join(' · ');
        color = Colors.green.shade700;
      } else {
        status = [
          '${time.format(d.checkInAt!)} – ${time.format(d.checkOutAt!)}',
          checkOutTypeLabel(l10n, d.checkOutType),
          if ((d.lateMin ?? 0) > 0) l10n.lateBy(formatMinutes(d.lateMin!)),
        ].join(' · ');
        color = theme.colorScheme.primary;
      }
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(d == null || !d.checkedIn ? Icons.person_off_outlined : (d.closed ? Icons.logout : Icons.how_to_reg), color: color),
        ),
        title: Text(u.name),
        subtitle: Text('${u.role.label(l10n)}${u.position.isEmpty ? '' : ' · ${positionLabel(positions, u.position, lang)}'}\n$status'),
        isThreeLine: true,
        trailing: d?.countedMin == null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMinutes(d!.countedMin!), style: theme.textTheme.titleSmall),
                  if ((d.overtimeMin ?? 0) > 0)
                    Text('+${formatMinutes(d.overtimeMin!)}', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade800)),
                  if ((d.afterHoursMin ?? 0) > 0)
                    Tooltip(
                      message: l10n.stayedAfterTime(formatMinutes(d.afterHoursMin!)),
                      child: Text('(+${formatMinutes(d.afterHoursMin!)})',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ),
                ],
              ),
        onTap: canOpenUsers ? () => context.push('/users/${u.id}') : null,
      );
    }

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
      body: Column(
        children: [
          DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(avatar: Icon(Icons.how_to_reg, size: 16, color: Colors.green.shade700), label: Text(l10n.attendanceIn(inNow))),
                Chip(avatar: const Icon(Icons.logout, size: 16), label: Text(l10n.attendanceOut(out))),
                Chip(avatar: const Icon(Icons.person_off_outlined, size: 16), label: Text(l10n.attendanceAbsent(absent))),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.noOneAssignedToSites, textAlign: TextAlign.center)))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final s in sites)
                        if (people.any((u) => u.workSiteIds.contains(s.id))) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(s.name, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
                          ),
                          // Listed under their first site only.
                          for (final u in people)
                            if (u.workSiteIds.firstWhere((id) => sites.any((x) => x.id == id), orElse: () => '') == s.id) row(u),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
