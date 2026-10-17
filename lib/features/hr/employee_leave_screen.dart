import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';
import 'leave_widgets.dart';
import 'my_leave_screen.dart';

/// HR area: one employee's balances for a year (HR / GM tap a type to set
/// the person's days or add an adjustment, e.g. days carried over), the
/// adjustments made, and all their requests.
class EmployeeLeaveScreen extends ConsumerWidget {
  const EmployeeLeaveScreen({super.key, required this.uid, required this.year});

  final String uid;
  final int year;

  Future<void> _editType(BuildContext context, WidgetRef ref, AppUser me, LeaveType type, LeaveBalanceRecord record) async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final days = TextEditingController(text: record.entitled[type.id]?.toString() ?? '');
    final adjust = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('${type.name(lang)} · $year'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.daysThisYear,
                  helperText: l10n.daysThisYearHelper(type.yearlyDays ?? 0),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: adjust,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: InputDecoration(labelText: l10n.adjustDays, helperText: l10n.adjustDaysHelper),
              ),
              TextField(controller: note, decoration: InputDecoration(labelText: l10n.adjustNote)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
        ],
      ),
    );
    final daysText = days.text.trim();
    final adjustValue = double.tryParse(adjust.text.trim().replaceAll(',', '.'));
    final noteText = note.text.trim();
    for (final c in [days, adjust, note]) {
      c.dispose();
    }
    if (ok != true) return;
    final repo = ref.read(leaveRepositoryProvider);
    final newDays = daysText.isEmpty ? null : num.tryParse(daysText);
    if (newDays != record.entitled[type.id]) await repo.setEntitled(uid, year, type.id, newDays);
    if (adjustValue != null && adjustValue != 0) {
      await repo.addAdjustment(uid, year, type.id, adjustValue, noteText, me.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final person = users[uid];
    final requests = ref.watch(userLeaveRequestsProvider(uid)).value ?? const <LeaveRequest>[];
    final record = ref.watch(leaveBalanceRecordProvider((uid, year))).value ?? LeaveBalanceRecord.empty;
    final types = {for (final t in ref.watch(leaveTypesProvider).value ?? LeaveType.defaults) t.id: t};
    final canEdit = me?.role.canManageHr ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(person?.name ?? '')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(l10n.tapTypeToEdit, style: theme.textTheme.bodySmall),
            ),
          LeaveBalancesCard(
            uid: uid,
            year: year,
            requests: requests,
            onTap: canEdit && me != null ? (t) => _editType(context, ref, me, t, record) : null,
          ),
          if (record.adjustments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(l10n.adjustments, style: theme.textTheme.titleMedium),
            ),
            for (final a in record.adjustments.reversed)
              ListTile(
                dense: true,
                leading: Icon(a.days >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline),
                title: Text('${a.days > 0 ? '+' : ''}${formatLeaveDays(a.days)} · ${types[a.typeId]?.name(lang) ?? a.typeId}'),
                subtitle: Text([
                  if (a.note.isNotEmpty) a.note,
                  users[a.byId]?.name ?? '',
                  if (a.at != null) DateFormat.yMMMd(locale).format(a.at!),
                ].where((s) => s.isNotEmpty).join(' · ')),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l10n.leaveRequests, style: theme.textTheme.titleMedium),
          ),
          if (requests.isEmpty) ListTile(title: Text(l10n.noLeaveRequests)),
          for (final r in requests) LeaveRequestTile(request: r),
        ],
      ),
    );
  }
}
