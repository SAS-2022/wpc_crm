import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../attendance/work_sites.dart';
import 'companies.dart';
import 'user_log.dart';
import 'users_repository.dart';

/// User history (2026-11-08, user: "who adds users or makes changes"):
/// every addition, registration, approval, change, password set and
/// deletion of a user, with who did it. GM / SM / HR (rules `managesHr`).
/// [userId] = one person's history (from their user form).
class UserLogScreen extends ConsumerStatefulWidget {
  const UserLogScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<UserLogScreen> createState() => _UserLogScreenState();
}

class _UserLogScreenState extends ConsumerState<UserLogScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    if (!me.role.canManageHr) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(l10n.noAccessTitle)));
    }
    final async = widget.userId == null ? ref.watch(userLogProvider) : ref.watch(userLogForProvider(widget.userId!));
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final target = widget.userId == null ? null : users[widget.userId];
    final q = foldSearch(_search);
    final names = _Names(
      l10n,
      users,
      ref.watch(companyNamesProvider),
      {for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[]) s.id: s.name},
    );

    return Scaffold(
      appBar: AppBar(title: Text(target == null ? l10n.userLogTitle : l10n.userLogTitleFor(target.name))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
        data: (entries) {
          final shown = [
            for (final e in entries)
              if (q.isEmpty || searchHas(e.targetName, q) || searchHas(names.actor(e), q)) e,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              if (widget.userId == null)
                TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.userLogSearch,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.userLogNote, style: Theme.of(context).textTheme.bodySmall),
              ),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.userLogEmpty)),
                ),
              for (final e in shown) _EntryCard(entry: e, names: names, showTarget: widget.userId == null),
            ],
          );
        },
      ),
    );
  }
}

/// Names for ids and readable values.
class _Names {
  _Names(this.l10n, this.users, this.companies, this.sites);

  final AppLocalizations l10n;
  final Map<String, AppUser> users;
  final Map<String, String> companies;
  final Map<String, String> sites;

  String person(String? id) => id == null || id.isEmpty ? '—' : users[id]?.name ?? l10n.deletedUser;

  String actor(UserLogEntry e) => e.actorId == null
      ? l10n.userLogUnknownActor
      : users[e.actorId]?.name ?? (e.actorName.isNotEmpty ? e.actorName : l10n.deletedUser);

  String field(String f) => switch (f) {
        'name' => l10n.userLogFieldName,
        'email' => l10n.userLogFieldEmail,
        'phone' => l10n.userLogFieldPhone,
        'role' => l10n.userLogFieldRole,
        'position' => l10n.userLogFieldPosition,
        'active' => l10n.userLogFieldActive,
        'approval' => l10n.userLogFieldApproval,
        'kamId' => l10n.userLogFieldKam,
        'managerId' => l10n.userLogFieldManager,
        'isManager' => l10n.userLogFieldIsManager,
        'supervisorId' => l10n.userLogFieldSupervisor,
        'odooName' => l10n.userLogFieldOdooName,
        'monthlyTarget' => l10n.userLogFieldTarget,
        'companyId' => l10n.userLogFieldCompany,
        'workSiteIds' => l10n.userLogFieldSites,
        'overtimeAllowed' => l10n.userLogFieldOvertime,
        'overtimeMaxMin' => l10n.userLogFieldOvertimeMax,
        'attendanceRequired' => l10n.userLogFieldAttendance,
        'leaveSiteAllowed' => l10n.userLogFieldLeaveSite,
        'workSchedule' => l10n.userLogFieldSchedule,
        'homeLocation' => l10n.userLogFieldHome,
        'joiningDate' => l10n.userLogFieldJoining,
        'department' => l10n.userLogFieldDepartment,
        _ => f,
      };

  String value(String f, Object? v) {
    if (v == null || v == '' || (v is List && v.isEmpty)) return '—';
    if (v is bool) return v ? l10n.yes : l10n.no;
    return switch (f) {
      'role' || 'position' when v is String => UserRole.fromValue(v).label(l10n),
      'kamId' || 'managerId' || 'supervisorId' when v is String => person(v),
      'companyId' when v is String => companies[v] ?? v,
      'workSiteIds' when v is List => v.map((s) => sites[s] ?? '$s').join(', '),
      'overtimeMaxMin' when v is num => l10n.userLogHours((v / 60).toStringAsFixed(v % 60 == 0 ? 0 : 1)),
      _ => v is List ? v.join(', ') : '$v',
    };
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.names, required this.showTarget});

  final UserLogEntry entry;
  final _Names names;
  final bool showTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = names.l10n;
    final theme = Theme.of(context);
    final e = entry;
    final actor = names.actor(e);
    final target = names.users[e.targetId]?.name ?? (e.targetName.isNotEmpty ? e.targetName : l10n.deletedUser);
    final (IconData icon, Color color, String title) = switch (e.action) {
      'registered' => (Icons.how_to_reg_outlined, Colors.teal, l10n.userLogRegistered(target)),
      'created' => (Icons.person_add_alt_1, Colors.green.shade700, l10n.userLogCreated(actor, target)),
      'approved' => (Icons.verified_user_outlined, Colors.green.shade700, l10n.userLogApproved(actor, target)),
      'rejected' => (Icons.person_off_outlined, theme.colorScheme.error, l10n.userLogRejected(actor, target)),
      'deleted' => (Icons.delete_outline, theme.colorScheme.error, l10n.userLogDeleted(actor, target)),
      'passwordSet' => (Icons.password, Colors.indigo, l10n.userLogPasswordSet(actor, target)),
      _ => (Icons.edit_outlined, theme.colorScheme.primary, l10n.userLogUpdated(actor, target)),
    };
    final locale = Localizations.localeOf(context).toString();
    final when = e.at == null ? '' : DateFormat.yMMMd(locale).add_Hm().format(e.at!);
    final added = e.action == 'registered' || e.action == 'created';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: showTarget && names.users.containsKey(e.targetId) ? () => context.push('/users/${e.targetId}') : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    Text(when, style: theme.textTheme.bodySmall),
                    if (e.changes.isNotEmpty) const SizedBox(height: 6),
                    for (final c in e.changes)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${names.field(c.field)}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (!added && c.from != null) ...[
                              TextSpan(
                                text: names.value(c.field, c.from),
                                style: TextStyle(color: theme.colorScheme.outline, decoration: TextDecoration.lineThrough),
                              ),
                              const TextSpan(text: '  →  '),
                            ],
                            TextSpan(text: names.value(c.field, c.to)),
                          ]),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
