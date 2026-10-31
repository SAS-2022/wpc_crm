import 'hr_people.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../tracking/work_hours.dart';
import '../users/users_repository.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';
import 'leave_widgets.dart';

/// New leave / other request: type, dates (leave only), reason and the
/// document the type needs. Shows the days it uses, what's left, and who
/// will approve it in which order.
class LeaveRequestForm extends ConsumerStatefulWidget {
  const LeaveRequestForm({super.key});

  @override
  ConsumerState<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends ConsumerState<LeaveRequestForm> {
  final _reason = TextEditingController();
  final _files = <PendingFile>[];
  String? _typeId;
  DateTimeRange? _dates;
  bool _halfDay = false;

  /// Travelling after work on the first day: the leave counts from the next work day.
  bool _afterWork = false;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dates,
    );
    if (picked != null) {
      setState(() {
        _dates = picked;
        if (picked.start != picked.end) _halfDay = false;
        _afterWork = false;
      });
    }
  }

  Future<void> _submit({
    required AppUser me,
    required LeaveType type,
    required double days,
    required DateTime? countFrom,
    required List<ApprovalStep> chain,
    required List<AppUser> users,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? problem;
    if (chain.isEmpty) {
      problem = l10n.noApproverYet;
    } else if (type.isLeave && _dates == null) {
      problem = l10n.pickLeaveDates;
    } else if (type.isLeave && leaveYearOf(me.joiningDate, _dates!.start) != leaveYearOf(me.joiningDate, _dates!.end)) {
      problem = l10n.leaveAcrossYears;
    } else if (type.isLeave && days <= 0) {
      problem = l10n.leaveNoWorkDays;
    } else if (type.needsDocument && !type.documentLater && _files.isEmpty) {
      problem = l10n.leaveDocumentRequired(type.document(Localizations.localeOf(context).languageCode));
    } else if (!type.isLeave && _reason.text.trim().isEmpty) {
      problem = l10n.leaveReasonRequired;
    }
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref.read(leaveRepositoryProvider).submit(
            me: me,
            type: type,
            from: type.isLeave ? leaveDayKey(countFrom!) : null,
            to: type.isLeave ? leaveDayKey(_dates!.end) : null,
            halfDay: type.isLeave && _halfDay,
            travelDay: type.isLeave && _afterWork ? leaveDayKey(_dates!.start) : null,
            days: type.isLeave ? days : 0,
            reason: _reason.text.trim(),
            chain: chain,
            files: _files,
            users: users,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.leaveRequestSent)));
      if (mounted) context.pushReplacement('/leave/$id');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(currentUserProvider).value;
    final types = ref.watch(leaveTypesProvider).value ?? LeaveType.defaults;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    if (me == null) return const SizedBox.shrink();
    final usersById = {for (final u in users) u.id: u};
    final type = types.where((t) => t.id == _typeId).firstOrNull ?? types.first;
    // The person's own work days (own schedule, else company hours).
    final workDays = me.scheduleOr(ref.watch(workHoursProvider).value ?? WorkHours.defaults).days;
    final holidays = ref.watch(holidaysProvider).value ?? const <String>{};
    // Travelling after work is offered when the first day is one they work.
    final canTravelAfterWork = type.isLeave &&
        !type.calendarDays &&
        _dates != null &&
        !_halfDay &&
        workDays.contains(_dates!.start.weekday) &&
        !holidays.contains(leaveDayKey(_dates!.start));
    final afterWork = canTravelAfterWork && _afterWork;
    final countFrom = _dates == null ? null : (afterWork ? nextWorkDay(_dates!.start, workDays, holidays) : _dates!.start);
    final days = type.isLeave && _dates != null
        ? countFrom!.isAfter(_dates!.end)
            ? 0.0
            : leaveDays(
            from: countFrom,
            to: _dates!.end,
            calendarDays: type.calendarDays,
            workDays: workDays,
            holidays: holidays,
            halfDay: _halfDay,
          )
        : 0.0;
    final chain = approvalChain(me, users);

    // What's left of this type after this request.
    final year = leaveYearOf(me.joiningDate, _dates?.start ?? DateTime.now());
    final mine = ref.watch(myLeaveRequestsProvider).value ?? const <LeaveRequest>[];
    final balance = personLeaveBalances(ref, uid: me.id, year: year, types: [type], requests: [for (final r in mine) r.use])[type.id];
    final fmt = DateFormat.yMMMd(locale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newLeaveRequest)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: type.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.requestType),
            items: [
              for (final t in types)
                DropdownMenuItem(
                  value: t.id,
                  child: Row(children: [
                    Icon(t.isLeave ? Icons.beach_access : Icons.description_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.name(lang), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() {
              _typeId = v;
              _halfDay = false;
            }),
          ),
          if (type.isLeave) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range),
              label: Text(_dates == null
                  ? l10n.pickLeaveDates
                  : _dates!.start == _dates!.end
                      ? fmt.format(_dates!.start)
                      : '${fmt.format(_dates!.start)} – ${fmt.format(_dates!.end)}'),
            ),
            if (_dates != null && _dates!.start == _dates!.end)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _halfDay,
                onChanged: (v) => setState(() => _halfDay = v),
                title: Text(l10n.halfDay),
              ),
            if (canTravelAfterWork)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _afterWork,
                onChanged: (v) => setState(() => _afterWork = v),
                secondary: const Icon(Icons.flight_takeoff),
                title: Text(l10n.travelAfterWork(DateFormat.MMMEd(locale).format(_dates!.start))),
                subtitle: _afterWork
                    ? Text(l10n.travelAfterWorkHint(
                        DateFormat.EEEE(locale).format(_dates!.start), DateFormat.MMMEd(locale).format(countFrom!)))
                    : null,
              ),
            if (_dates != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(l10n.leaveDaysCount(formatLeaveDays(days))),
                subtitle: Text([
                  type.calendarDays ? l10n.countsCalendarDays : l10n.countsWorkDays,
                  if (balance != null)
                    l10n.leaveLeftAfter(formatLeaveDays(balance.remaining - days)),
                ].join(' · ')),
              ),
            if (balance != null && _dates != null && balance.remaining - days < 0)
              Text(l10n.leaveOverBalance, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: type.isLeave ? l10n.leaveReasonOptional : l10n.leaveRequestDetails,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          if (type.needsDocument)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                type.documentLater ? l10n.leaveDocumentLater(type.document(lang)) : l10n.leaveDocumentRequired(type.document(lang)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _files.isEmpty && !type.documentLater ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, f) in _files.indexed)
                InputChip(
                  avatar: Icon(f.contentType.startsWith('image/') ? Icons.image : Icons.insert_drive_file, size: 18),
                  label: Text(f.name, overflow: TextOverflow.ellipsis),
                  onDeleted: _busy ? null : () => setState(() => _files.removeAt(i)),
                ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final picked = await pickAttachments(context);
                        if (mounted) setState(() => _files.addAll(picked));
                      },
                icon: const Icon(Icons.attach_file),
                label: Text(l10n.addAttachment),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Who approves, in order.
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(l10n.approvalOrder),
              subtitle: Text(chain.isEmpty
                  ? l10n.noApproverYet
                  : chain.map((s) => stepLabel(s, usersById, l10n)).join(' → ')),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _submit(me: me, type: type, days: days, countFrom: countFrom, chain: chain, users: users),
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(l10n.sendRequest),
          ),
        ],
      ),
    );
  }
}
