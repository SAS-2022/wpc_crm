import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../core/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'attendance_rules.dart' show defaultOvertimeMaxMin, formatMinutes;
import 'overtime.dart';

/// Attendance → Overtime permission (`/attendance/overtime`, user request
/// 2026-11-05): a department head switches overtime on / off for each of
/// their employees and sets the most a day. Off = time after the end of the
/// work day never counts, even when they stay ([canSetOvertimeFor]).
class OvertimePermissionScreen extends ConsumerStatefulWidget {
  const OvertimePermissionScreen({super.key});

  @override
  ConsumerState<OvertimePermissionScreen> createState() => _OvertimePermissionScreenState();
}

class _OvertimePermissionScreenState extends ConsumerState<OvertimePermissionScreen> {
  final _busy = <String>{};
  String _search = '';

  Future<void> _save(AppUser u, {required bool allowed, int? maxMin}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(u.id));
    try {
      await ref.read(usersRepositoryProvider).setOvertime(u.id, allowed: allowed, maxMin: maxMin);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final people = me == null
        ? const <AppUser>[]
        : ([
            for (final u in users)
              if (u.checksAttendance && canSetOvertimeFor(me, u, users)) u,
          ]..sort((a, b) => a.name.compareTo(b.name)));
    final shown = [
      for (final u in people)
        if (_search.isEmpty || searchHas(u.name, _search) || searchHas(u.role.label(l10n), _search)) u,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.overtimePermission)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(l10n.overtimePermissionHelp, style: theme.textTheme.bodyMedium),
          ),
          if (people.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: l10n.search, isDense: true),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
            ),
          if (people.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text(l10n.overtimePermissionNone, textAlign: TextAlign.center)),
          for (final u in shown)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(u.name),
                    subtitle: Text([
                      u.role.label(l10n),
                      if (u.overtimeAllowed) l10n.overtimeUpTo(formatMinutes(u.overtimeCapMin)),
                    ].join(' · ')),
                    value: u.overtimeAllowed,
                    onChanged: _busy.contains(u.id) ? null : (v) => _save(u, allowed: v, maxMin: u.overtimeMaxMin),
                  ),
                  if (u.overtimeAllowed)
                    ListTile(
                      dense: true,
                      title: Text(l10n.overtimeMax),
                      trailing: DropdownButton<int>(
                        value: u.overtimeCapMin,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final h in ({1, 2, 3, 4, 5, 6, 8, 10, 12, if (u.overtimeCapMin % 60 == 0) u.overtimeCapMin ~/ 60}.toList()..sort()))
                            DropdownMenuItem(value: h * 60, child: Text(l10n.hoursCount(h))),
                          if (u.overtimeCapMin % 60 != 0)
                            DropdownMenuItem(value: u.overtimeCapMin, child: Text('${u.overtimeCapMin} min')),
                        ],
                        onChanged: _busy.contains(u.id)
                            ? null
                            : (v) => _save(u, allowed: true, maxMin: v == defaultOvertimeMaxMin ? null : v),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
