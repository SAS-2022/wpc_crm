import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import '../clients/client_tags.dart';
import 'hr_people.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';
import 'leave_widgets.dart';
import 'my_leave_screen.dart';

/// HR area: one employee's joining date and department, their balances for a
/// leave year (HR / GM tap a type to set the person's days or add an
/// adjustment), the adjustments made, the closed years and all their
/// requests.
class EmployeeLeaveScreen extends ConsumerStatefulWidget {
  const EmployeeLeaveScreen({super.key, required this.uid, this.year});

  final String uid;

  /// Leave year to open; null = their current one.
  final int? year;

  @override
  ConsumerState<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends ConsumerState<EmployeeLeaveScreen> {
  int? _year;

  String get uid => widget.uid;

  Future<void> _editType(BuildContext context, WidgetRef ref, AppUser me, LeaveType type, LeaveBalanceRecord record, int year) async {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final person = users[uid];
    final requests = ref.watch(userLeaveRequestsProvider(uid)).value ?? const <LeaveRequest>[];
    final year = _year ?? widget.year ?? leaveYearOf(person?.joiningDate, DateTime.now());
    final history = ref.watch(leaveHistoryProvider(uid)).value ?? const <LeaveYearRecord>[];
    final departments = ref.watch(departmentsProvider).value ?? defaultDepartments;
    final record = ref.watch(leaveBalanceRecordProvider((uid, year))).value ?? LeaveBalanceRecord.empty;
    final types = {for (final t in ref.watch(leaveTypesProvider).value ?? LeaveType.defaults) t.id: t};
    final canEdit = me?.role.canManageHr ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(person?.name ?? '')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (person != null)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canEdit) ...[
                      JoiningDateField(
                        value: person.joiningDate,
                        onChanged: (v) => saveEmployeeHrFields(uid, joiningDate: v, department: person.department),
                      ),
                      DepartmentField(
                        value: person.department,
                        role: person.role,
                        onChanged: (v) => saveEmployeeHrFields(uid, joiningDate: person.joiningDate, department: v),
                      ),
                    ] else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(departmentName(departments, person.departmentId, lang)),
                        subtitle: Text(person.joiningDate == null
                            ? l10n.joiningDateNotSet
                            : DateFormat.yMMMd(locale).format(DateTime.parse(person.joiningDate!))),
                      ),
                    const SizedBox(height: 4),
                    Text(person.joiningDate == null ? l10n.leaveYearCalendarHint : l10n.leaveYearJoiningHint,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _year = year - 1)),
              Expanded(
                child: Text(leaveYearLabel(context, person?.joiningDate, year),
                    textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _year = year + 1)),
            ]),
          ),
          if (canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(l10n.tapTypeToEdit, style: theme.textTheme.bodySmall),
            ),
          LeaveBalancesCard(
            uid: uid,
            year: year,
            requests: requests,
            onTap: canEdit && me != null ? (t) => _editType(context, ref, me, t, record, year) : null,
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
          if (history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(l10n.pastLeaveYears, style: theme.textTheme.titleMedium),
            ),
            for (final h in history) _PastYearTile(record: h, types: types),
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

/// A closed leave year: days taken per type, and what moved to the next year.
class _PastYearTile extends StatelessWidget {
  const _PastYearTile({required this.record, required this.types});

  final LeaveYearRecord record;
  final Map<String, LeaveType> types;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final f = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    String day(String d) => DateTime.tryParse(d) == null ? d : f.format(DateTime.parse(d));
    final annual = record.types[annualLeaveTypeId];
    return ExpansionTile(
      leading: const Icon(Icons.history),
      title: Text('${day(record.from)} – ${day(record.to)}'),
      subtitle: Text([
        if (annual != null) l10n.annualTaken(formatLeaveDays(annual.used), formatLeaveDays(annual.entitled + annual.carried)),
        if (record.carriedOut != 0)
          l10n.carriedToNextYear('${record.carriedOut > 0 ? '+' : ''}${formatLeaveDays(record.carriedOut)}'),
      ].join(' · ')),
      children: [
        for (final e in record.types.entries)
          if (e.value.used != 0 || e.key == annualLeaveTypeId)
            ListTile(
              dense: true,
              title: Text(types[e.key]?.name(lang) ?? e.key),
              trailing: Text(
                l10n.pastYearRow(formatLeaveDays(e.value.used), formatLeaveDays(e.value.entitled + e.value.carried),
                    formatLeaveDays(e.value.remaining)),
                style: TextStyle(color: e.value.remaining < 0 ? theme.colorScheme.error : null),
              ),
            ),
      ],
    );
  }
}
