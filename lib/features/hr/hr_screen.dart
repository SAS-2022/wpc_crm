import '../clients/client_tags.dart';
import 'hr_people.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../attendance/absence.dart';
import '../attendance/absence_screen.dart' show HrAbsencesTab;
import '../attendance/attendance_repository.dart' show attendanceDay;
import '../attendance/early_checkout.dart';
import '../users/users_repository.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';
import 'leave_widgets.dart';

enum _Filter { pending, waitingForMe, approved, rejected, all }

/// HR area (HR, GM, sales manager): every leave / other request, absence and
/// request to leave early — also those waiting for someone else, with whose
/// approval each waits for (user 2026-10-31) — each employee's balances, and
/// the leave types and public holidays. Only HR and
/// the GM change balances, types and holidays.
class HrScreen extends ConsumerWidget {
  const HrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.hrArea),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(child: _RequestsTabLabel()),
              // Reported "not coming to work" days (2026-10-22), with the waiting count.
              Tab(child: _AbsencesTabLabel()),
              Tab(child: _EarlyCheckoutsTabLabel()),
              Tab(text: l10n.leaveBalances),
              Tab(text: l10n.leaveTypesAndHolidays),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_RequestsTab(), HrAbsencesTab(), _EarlyCheckoutsTab(), _BalancesTab(), _TypesTab()],
        ),
      ),
    );
  }
}

/// Tab label with a waiting count.
class _CountLabel extends StatelessWidget {
  const _CountLabel(this.text, this.count);

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        offset: const Offset(14, -6),
        child: Text(text),
      );
}

class _RequestsTabLabel extends ConsumerWidget {
  const _RequestsTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = (ref.watch(allLeaveRequestsProvider).value ?? const <LeaveRequest>[])
        .where((r) => r.status == LeaveStatus.pending)
        .length;
    return _CountLabel(AppLocalizations.of(context).leaveRequests, waiting);
  }
}

class _EarlyCheckoutsTabLabel extends ConsumerWidget {
  const _EarlyCheckoutsTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = attendanceDay(DateTime.now());
    final waiting = (ref.watch(allEarlyCheckoutsProvider).value ?? const <EarlyCheckout>[])
        .where((r) => r.pending && r.date == today)
        .length;
    return _CountLabel(AppLocalizations.of(context).earlyCheckoutsTab, waiting);
  }
}

class _AbsencesTabLabel extends ConsumerWidget {
  const _AbsencesTabLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = (ref.watch(allAbsencesProvider).value ?? const <Absence>[]).where((a) => a.pending).length;
    return Badge(
      isLabelVisible: waiting > 0,
      label: Text('$waiting'),
      offset: const Offset(14, -6),
      child: Text(AppLocalizations.of(context).absencesTab),
    );
  }
}

class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab();

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  // Everything waiting by default, not only HR's own turn (user 2026-10-31).
  _Filter _filter = _Filter.pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final all = ref.watch(allLeaveRequestsProvider);
    final labels = {
      _Filter.pending: l10n.pendingStatus,
      _Filter.waitingForMe: l10n.waitingForMe,
      _Filter.approved: l10n.leaveApprovedStatus,
      _Filter.rejected: l10n.rejected,
      _Filter.all: l10n.allTime,
    };
    return all.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
      data: (requests) {
        bool mine(LeaveRequest r) => canDecide(me: me, requesterId: r.uid, awaitingKey: r.awaitingKey);
        final counts = {
          _Filter.pending: requests.where((r) => r.status == LeaveStatus.pending).length,
          _Filter.waitingForMe: requests.where(mine).length,
        };
        final list = requests.where((r) => switch (_filter) {
              _Filter.waitingForMe => mine(r),
              _Filter.pending => r.status == LeaveStatus.pending,
              _Filter.approved => r.status == LeaveStatus.approved,
              _Filter.rejected => r.status == LeaveStatus.rejected,
              _Filter.all => true,
            }).toList();
        return ListView(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(counts[f] == null ? labels[f]! : '${labels[f]!} (${counts[f]})'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ]),
            ),
            if (list.isEmpty) ListTile(title: Text(l10n.noLeaveRequests)),
            for (final r in list) ...[
              LeaveRequestTile(request: r, showPerson: true, yourTurn: mine(r)),
              // Waiting requests: the person's balance right under it.
              if (r.isLeave && r.status == LeaveStatus.pending)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 12),
                  child: LeaveBalanceTable(uid: r.uid, day: r.from, highlightTypeId: r.typeId),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Everyone's remaining annual leave; tap a person for all types and history.
class _BalancesTab extends ConsumerStatefulWidget {
  const _BalancesTab();

  @override
  ConsumerState<_BalancesTab> createState() => _BalancesTabState();
}

class _BalancesTabState extends ConsumerState<_BalancesTab> {
  String _query = '';

  /// Department ids shown; empty = everyone ('' = no department).
  Set<String> _departments = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    final q = _query.trim().toLowerCase();
    final departments = ref.watch(departmentsProvider).value ?? defaultDepartments;
    final all = (ref.watch(usersProvider).value ?? const <AppUser>[])
        .where((u) => u.active && u.role != UserRole.unknown)
        .toList();
    int count(String id) => all.where((u) => (u.departmentId ?? '') == id).length;
    final people = all
        .where((u) => q.isEmpty || u.name.toLowerCase().contains(q))
        .where((u) => _departments.isEmpty || _departments.contains(u.departmentId ?? ''))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    void toggle(String id, bool on) => setState(() => _departments = on ? {..._departments, id} : ({..._departments}..remove(id)));
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SearchBar(
            hintText: l10n.search,
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // Filter by department (several can be ticked).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final d in departments)
                if (count(d.id) > 0)
                  FilterChip(
                    label: Text('${d.label(lang)} (${count(d.id)})'),
                    selected: _departments.contains(d.id),
                    onSelected: (on) => toggle(d.id, on),
                  ),
              if (count('') > 0)
                FilterChip(
                  label: Text('${l10n.noDepartment} (${count('')})'),
                  selected: _departments.contains(''),
                  onSelected: (on) => toggle('', on),
                ),
            ],
          ),
        ),
        for (final u in people)
          ListTile(
            leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name.characters.first)),
            title: Text(u.name),
            subtitle: Text([
              u.role.label(l10n),
              if (u.departmentId != null) departmentName(departments, u.departmentId, lang),
              u.joiningDate == null
                  ? l10n.joiningDateNotSet
                  : l10n.joinedOn(DateFormat.yMMMd(locale).format(DateTime.parse(u.joiningDate!))),
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/hr/employee/${u.id}'),
          ),
      ],
    );
  }
}

/// Leave types (HR / GM edit) and public holidays.
class _TypesTab extends ConsumerWidget {
  const _TypesTab();

  Future<void> _edit(BuildContext context, WidgetRef ref, List<LeaveType> types, LeaveType? type) async {
    final edited = await showDialog<LeaveType>(context: context, builder: (_) => _TypeDialog(type: type));
    if (edited == null) return;
    final list = [...types];
    final i = list.indexWhere((t) => t.id == edited.id);
    if (i >= 0) {
      list[i] = edited;
    } else {
      list.add(edited);
    }
    await ref.read(leaveRepositoryProvider).saveTypes(list);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locale = Localizations.localeOf(context).toString();
    final canEdit = ref.watch(currentUserProvider).value?.role.canManageHr ?? false;
    final types = ref.watch(leaveTypesProvider).value ?? LeaveType.defaults;
    final holidays = (ref.watch(holidaysProvider).value ?? const <String>{}).toList()..sort();
    final repo = ref.read(leaveRepositoryProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const AnnualCarryOverTile(),
        if (canEdit)
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(l10n.departments),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/departments'),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(l10n.leaveTypesHint, style: theme.textTheme.bodySmall),
        ),
        for (final t in types)
          ListTile(
            leading: Icon(t.isLeave ? Icons.beach_access : Icons.description_outlined),
            title: Text(t.name(lang)),
            subtitle: Text([
              if (t.isLeave) t.yearlyDays == null ? l10n.noYearlyLimit : l10n.daysPerYear(t.yearlyDays!),
              if (t.isLeave) t.calendarDays ? l10n.countsCalendarDays : l10n.countsWorkDays,
              if (t.isLeave && !t.paid) l10n.unpaid,
              if (!t.isLeave) l10n.otherRequest,
              if (t.needsDocument) l10n.needsDocumentNamed(t.document(lang)),
            ].join(' · ')),
            trailing: canEdit
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.delete,
                    onPressed: () => repo.saveTypes(types.where((x) => x.id != t.id).toList()),
                  )
                : null,
            onTap: canEdit ? () => _edit(context, ref, types, t) : null,
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => _edit(context, ref, types, null),
                icon: const Icon(Icons.add),
                label: Text(l10n.addLeaveType),
              ),
            ),
          ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(l10n.publicHolidays, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.publicHolidaysHint, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in holidays)
                InputChip(
                  label: Text(DateFormat.yMMMEd(locale).format(DateTime.parse(d))),
                  onDeleted: canEdit ? () => repo.saveHolidays({...holidays}..remove(d)) : null,
                ),
              if (canEdit)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addHoliday),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2, 12, 31),
                    );
                    if (picked == null) return;
                    await repo.saveHolidays({
                      ...holidays,
                      for (var d = picked.start; !d.isAfter(picked.end); d = DateTime(d.year, d.month, d.day + 1))
                        leaveDayKey(d),
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypeDialog extends StatefulWidget {
  const _TypeDialog({required this.type});

  /// null = new type.
  final LeaveType? type;

  @override
  State<_TypeDialog> createState() => _TypeDialogState();
}

class _TypeDialogState extends State<_TypeDialog> {
  late final _en = TextEditingController(text: widget.type?.en);
  late final _ar = TextEditingController(text: widget.type?.ar);
  late final _days = TextEditingController(text: widget.type?.yearlyDays?.toString() ?? '');
  late final _docEn = TextEditingController(text: widget.type?.documentEn);
  late final _docAr = TextEditingController(text: widget.type?.documentAr);
  late bool _isLeave = widget.type?.isLeave ?? true;
  late bool _calendar = widget.type?.calendarDays ?? false;
  late bool _paid = widget.type?.paid ?? true;
  late bool _needsDoc = widget.type?.needsDocument ?? false;

  @override
  void dispose() {
    for (final c in [_en, _ar, _days, _docEn, _docAr]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.type == null ? l10n.addLeaveType : l10n.editLeaveType),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _en, decoration: InputDecoration(labelText: l10n.nameEnglish)),
              TextField(controller: _ar, decoration: InputDecoration(labelText: l10n.nameArabic)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isLeave,
                onChanged: (v) => setState(() => _isLeave = v),
                title: Text(l10n.isLeaveType),
                subtitle: Text(l10n.isLeaveTypeHint),
              ),
              if (_isLeave) ...[
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.daysPerYearLabel, helperText: l10n.daysPerYearHelper),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _calendar,
                  onChanged: (v) => setState(() => _calendar = v),
                  title: Text(l10n.countsCalendarDays),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _paid,
                  onChanged: (v) => setState(() => _paid = v),
                  title: Text(l10n.paidLeave),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _needsDoc,
                onChanged: (v) => setState(() => _needsDoc = v),
                title: Text(l10n.needsDocument),
              ),
              if (_needsDoc) ...[
                TextField(controller: _docEn, decoration: InputDecoration(labelText: l10n.documentNameEnglish)),
                TextField(controller: _docAr, decoration: InputDecoration(labelText: l10n.documentNameArabic)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            final en = _en.text.trim();
            if (en.isEmpty) return;
            Navigator.pop(
              context,
              LeaveType(
                id: widget.type?.id ?? 't${DateTime.now().millisecondsSinceEpoch}',
                en: en,
                ar: _ar.text.trim(),
                isLeave: _isLeave,
                yearlyDays: int.tryParse(_days.text.trim()),
                calendarDays: _calendar,
                paid: _paid,
                needsDocument: _needsDoc,
                documentEn: _docEn.text.trim(),
                documentAr: _docAr.text.trim(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

enum _EarlyFilter { waiting, approved, rejected, all }

/// Requests to leave early (decided by the person's direct managers on
/// their Home card); HR sees them all here with whose approval each waits
/// for. Waiting = today's open requests; older open ones lapsed with the day.
class _EarlyCheckoutsTab extends ConsumerStatefulWidget {
  const _EarlyCheckoutsTab();

  @override
  ConsumerState<_EarlyCheckoutsTab> createState() => _EarlyCheckoutsTabState();
}

class _EarlyCheckoutsTabState extends ConsumerState<_EarlyCheckoutsTab> {
  _EarlyFilter _filter = _EarlyFilter.waiting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final day = DateFormat.yMMMEd(locale);
    final time = DateFormat.jm(locale);
    final me = ref.watch(currentUserProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    String name(String? id) => users[id]?.name ?? '?';
    final today = attendanceDay(DateTime.now());
    final labels = {
      _EarlyFilter.waiting: l10n.pendingStatus,
      _EarlyFilter.approved: l10n.leaveApprovedStatus,
      _EarlyFilter.rejected: l10n.rejected,
      _EarlyFilter.all: l10n.allTime,
    };
    return ref.watch(allEarlyCheckoutsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
          data: (requests) {
            bool waiting(EarlyCheckout r) => r.pending && r.date == today;
            final count = requests.where(waiting).length;
            final list = [
              for (final r in requests)
                if (switch (_filter) {
                  _EarlyFilter.waiting => waiting(r),
                  _EarlyFilter.approved => r.status == EarlyCheckoutStatus.approved,
                  _EarlyFilter.rejected => r.status == EarlyCheckoutStatus.rejected,
                  _EarlyFilter.all => true,
                })
                  r,
            ];
            return ListView(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(children: [
                    for (final f in _EarlyFilter.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(f == _EarlyFilter.waiting ? '${labels[f]!} ($count)' : labels[f]!),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ]),
                ),
                if (list.isEmpty) ListTile(title: Text(l10n.noEarlyCheckouts)),
                for (final r in list)
                  Builder(builder: (context) {
                    final (status, color) = switch (r.status) {
                      EarlyCheckoutStatus.pending => (
                          l10n.waitingFor(r.approverIds.map(name).join(' / ')),
                          Colors.orange.shade800,
                        ),
                      EarlyCheckoutStatus.approved => (l10n.approvedByName(name(r.decidedBy)), Colors.green.shade700),
                      EarlyCheckoutStatus.rejected => (l10n.rejectedByName(name(r.decidedBy)), theme.colorScheme.error),
                    };
                    final yourTurn = waiting(r) && me != null && r.approverIds.contains(me.id);
                    return ListTile(
                      leading: Icon(Icons.directions_walk, color: color),
                      title: Text(name(r.uid)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text([
                            day.format(DateTime.parse(r.date)),
                            if (r.createdAt != null) time.format(r.createdAt!),
                          ].join(' · ')),
                          Text(r.reason),
                          Text(
                            [status, if (yourTurn) l10n.yourTurn].join(' · '),
                            style: TextStyle(color: color, fontWeight: FontWeight.w600),
                          ),
                          if (r.comment.isNotEmpty) Text('“${r.comment}”'),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        );
  }
}
