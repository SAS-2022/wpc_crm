import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import '../clients/client_tags.dart';
import 'employee_record_widgets.dart';
import 'employment_contract_card.dart';
import 'hr_people.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';
import 'hr_actions_screen.dart';
import 'payroll_screen.dart';
import '../tracking/work_hours.dart';
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
                  helperText: type.id == annualLeaveTypeId
                      ? l10n.annualDaysHelper(type.yearlyDays ?? 21, seniorAnnualDays, seniorAfterYears)
                      : l10n.daysThisYearHelper(type.yearlyDays ?? 0),
                  helperMaxLines: 3,
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
    final canEdit = me?.can.canManageHr ?? false;

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
          EmployeeRecordCard(uid: uid, margin: const EdgeInsets.fromLTRB(12, 8, 12, 0)),
          // Payroll account only (2026-11-07).
          if (person != null) PersonSalaryCard(user: person),
          // HR and the payroll account (2026-11-13): its amounts fill the salary.
          if (person != null) EmploymentContractCard(user: person, margin: const EdgeInsets.fromLTRB(12, 8, 12, 0)),
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
          // Leave taken before (2026-11-08, user): entered by date.
          if (canEdit && me != null && person != null && (person.id != me.id || isDeveloper(me)))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history_edu),
                  label: Text(l10n.addPastLeave),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _PastLeaveDialog(me: me, person: person),
                  ),
                ),
              ),
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
          PersonHrActionsSection(uid: uid),
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

/// HR enters leave the person already took, by date ([LeaveRepository.recordPastLeave]).
class _PastLeaveDialog extends ConsumerStatefulWidget {
  const _PastLeaveDialog({required this.me, required this.person});

  final AppUser me;
  final AppUser person;

  @override
  ConsumerState<_PastLeaveDialog> createState() => _PastLeaveDialogState();
}

class _PastLeaveDialogState extends ConsumerState<_PastLeaveDialog> {
  String? _typeId;
  DateTimeRange? _dates;
  bool _halfDay = false;
  final _days = TextEditingController();
  final _note = TextEditingController();

  /// The day count the dialog last filled in; HR may type another.
  double? _counted;

  @override
  void dispose() {
    _days.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    final types = (ref.watch(leaveTypesProvider).value ?? LeaveType.defaults).where((t) => t.isLeave).toList();
    final type = types.where((t) => t.id == _typeId).firstOrNull ?? types.first;
    final workDays = widget.person.scheduleOr(ref.watch(workHoursProvider).value ?? WorkHours.defaults).days;
    final holidays = ref.watch(holidaysProvider).value ?? const <String>{};
    final oneDay = _dates != null && _dates!.start == _dates!.end;
    final counted = _dates == null
        ? null
        : leaveDays(
            from: _dates!.start,
            to: _dates!.end,
            calendarDays: type.calendarDays,
            workDays: workDays,
            holidays: holidays,
            halfDay: _halfDay && oneDay,
          );
    // Refresh the days field when the count changes, unless HR typed their own.
    if (counted != _counted) {
      if (_days.text.isEmpty || double.tryParse(_days.text) == _counted) _days.text = counted == null ? '' : formatLeaveDays(counted);
      _counted = counted;
    }
    final crossesYear = _dates != null &&
        leaveYearOf(widget.person.joiningDate, _dates!.start) != leaveYearOf(widget.person.joiningDate, _dates!.end);
    final days = double.tryParse(_days.text.trim().replaceAll(',', '.'));
    final f = DateFormat.yMMMEd(locale);
    final now = DateTime.now();
    return AlertDialog(
      title: Text(l10n.addPastLeave),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.pastLeaveHelp, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.pastLeaveType),
                items: [for (final t in types) DropdownMenuItem(value: t.id, child: Text(t.name(lang)))],
                onChanged: (v) => setState(() => _typeId = v),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_dates == null
                    ? l10n.pastLeavePickDates
                    : oneDay
                        ? f.format(_dates!.start)
                        : '${f.format(_dates!.start)} – ${f.format(_dates!.end)}'),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    initialDateRange: _dates,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year, now.month, now.day),
                  );
                  if (picked != null) setState(() => _dates = picked);
                },
              ),
              if (crossesYear)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(l10n.pastLeaveOneYear, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (oneDay)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.halfDay),
                  value: _halfDay,
                  onChanged: (v) => setState(() => _halfDay = v),
                ),
              TextField(
                controller: _days,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.pastLeaveDaysUsed, helperText: l10n.pastLeaveDaysHint, helperMaxLines: 2),
                onChanged: (_) => setState(() {}),
              ),
              TextField(controller: _note, decoration: InputDecoration(labelText: l10n.adjustNote)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _dates == null || crossesYear || days == null || days < 0
              ? null
              : () async {
                  await ref.read(leaveRepositoryProvider).recordPastLeave(
                        me: widget.me,
                        person: widget.person,
                        type: type,
                        from: leaveDayKey(_dates!.start),
                        to: leaveDayKey(_dates!.end),
                        halfDay: _halfDay && oneDay,
                        days: days,
                        note: _note.text.trim(),
                      );
                  if (context.mounted) Navigator.pop(context);
                },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
