import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/clients_repository.dart' show hiddenClientIdsProvider;
import '../plan/plan_task.dart' show monthKey;
import '../users/users_repository.dart';
import 'call_chip.dart' show callColor;
import 'visit.dart';
import 'visit_calendar.dart';

/// One person's visits and calls of a month ('yyyy-MM'), by `month`.
final personMonthVisitsProvider = StreamProvider.family<List<Visit>, (String, String)>((ref, key) =>
    FirebaseFirestore.instance
        .collection('visits')
        .where('salesExecId', isEqualTo: key.$1)
        .where('month', isEqualTo: key.$2)
        .snapshots()
        .map((s) => s.docs.map(Visit.fromDoc).toList()));

const _visitColor = Color(0xFF2E7D32);

/// Visits calendar (2026-11-22, user: "like we did in attendance"): a
/// salesperson's month as a grid, each day with its visits (green) and
/// calls (purple); tap a day for the list. KAM / managers pick the person
/// (KAM: their team and themselves), sales execs see their own.
class VisitsCalendarScreen extends ConsumerStatefulWidget {
  const VisitsCalendarScreen({super.key, this.uid, this.month});

  final String? uid;

  /// 'yyyy-MM'; null = this month.
  final String? month;

  @override
  ConsumerState<VisitsCalendarScreen> createState() => _VisitsCalendarScreenState();
}

class _VisitsCalendarScreenState extends ConsumerState<VisitsCalendarScreen> {
  late DateTime _month;
  String? _uid;

  @override
  void initState() {
    super.initState();
    final parsed = DateTime.tryParse('${widget.month ?? ''}-01');
    final now = DateTime.now();
    _month = DateTime((parsed ?? now).year, (parsed ?? now).month);
    _uid = widget.uid;
  }

  /// Whose calendars [me] may open: KAM their team + themselves, SM / GM
  /// every active salesperson, sales execs only themselves.
  List<AppUser> _people(AppUser me, List<AppUser> users) {
    if (!me.can.isSupervisor) return [me];
    final list = [
      for (final u in users)
        if (u.active && u.role.isTracked && (!me.kamOnly || u.id == me.id || u.kamId == me.id)) u,
    ]..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _showDay(DateTime day, List<Visit> list) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale);
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(DateFormat.yMMMMEEEEd(locale).format(day)),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final v in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(v.isCall ? Icons.call : Icons.where_to_vote, color: v.isCall ? callColor : _visitColor),
                  title: Text(v.clientName),
                  subtitle: Text([
                    if (v.checkedInAt != null) time.format(v.checkedInAt!),
                    v.isCall ? l10n.call : l10n.visitKind,
                    if (v.notes.isNotEmpty) v.notes,
                  ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(dialog);
                    context.push('/visits/${v.id}');
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final people = _people(me, users);
    final uid = people.any((u) => u.id == _uid) ? _uid! : (people.any((u) => u.id == me.id) ? me.id : people.firstOrNull?.id);
    final person = people.where((u) => u.id == uid).firstOrNull;
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    final hidden = ref.watch(hiddenClientIdsProvider);
    final async = uid == null ? const AsyncValue<List<Visit>>.data([]) : ref.watch(personMonthVisitsProvider((uid, monthKey(_month))));
    final month = visitMonth(
      (async.value ?? const <Visit>[]).where((v) => !hidden.contains(v.clientId)),
      _month,
      now: now,
    );

    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final names = DateFormat.E(locale).dateSymbols.STANDALONEWEEKDAYS;
    final lead = (DateTime(_month.year, _month.month, 1).weekday % 7 - firstWeekday) % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <int?>[for (var i = 0; i < lead; i++) null, for (var d = 1; d <= daysInMonth; d++) d];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final target = person?.monthlyTarget ?? 0;

    Widget chip(String text, [Color? color]) => Chip(
          avatar: color == null ? null : Icon(Icons.circle, size: 12, color: color),
          label: Text(text),
          visualDensity: VisualDensity.compact,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.visitsCalendar)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (people.length > 1)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: DropdownButtonFormField<String>(
                  initialValue: uid,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.salesExecutive),
                  items: [for (final u in people) DropdownMenuItem(value: u.id, child: Text(u.name))],
                  onChanged: (v) => setState(() => _uid = v),
                ),
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(locale).format(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isCurrentMonth ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
              ),
            ],
          ),
          if (async.isLoading && !async.hasValue)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (async.hasError)
            Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.errorWithMessage('${async.error}'))))
          else ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(l10n.calVisitsCount(month.visits), _visitColor),
                chip(l10n.calCallsCount(month.calls), callColor),
                if (target > 0) chip(l10n.calTargetLine(month.visits + month.calls, target)),
                chip(l10n.calFieldDays(month.fieldDays)),
                chip(l10n.calClientsCount(month.clients)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        names[(firstWeekday + i) % 7],
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  ),
              ],
            ),
            for (var w = 0; w < cells.length ~/ 7; w++)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final d in cells.sublist(w * 7, w * 7 + 7))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: d == null
                              ? const SizedBox(height: _DayCell.height)
                              : _DayCell(
                                  date: DateTime(_month.year, _month.month, d),
                                  visits: month.byDay[d] ?? const [],
                                  today: isCurrentMonth && d == now.day,
                                  future: isCurrentMonth && d > now.day,
                                  onTap: (month.byDay[d] ?? const []).isEmpty
                                      ? null
                                      : () => _showDay(DateTime(_month.year, _month.month, d), month.byDay[d]!),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A calendar day: number with "visits + calls", then client names.
class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.visits, required this.today, required this.future, this.onTap});

  static const height = 116.0;
  static const _shown = 4;

  final DateTime date;
  final List<Visit> visits;
  final bool today;
  final bool future;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final has = visits.isNotEmpty;
    final nVisits = visits.where((v) => !v.isCall).length;
    final nCalls = visits.length - nVisits;
    final extra = visits.length - _shown;
    return Material(
      color: has ? _visitColor.withValues(alpha: 0.06) : (future ? scheme.surfaceContainerLow : scheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: today ? scheme.primary : scheme.outlineVariant, width: today ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: height),
          decoration: BoxDecoration(
            border: BorderDirectional(start: BorderSide(color: has ? _visitColor : Colors.transparent, width: 4)),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 6, 4),
          child: DefaultTextStyle(
            style: theme.textTheme.bodySmall!.copyWith(height: 1.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${date.day}', style: theme.textTheme.titleSmall?.copyWith(color: has ? null : scheme.outline)),
                    const Spacer(),
                    if (nVisits > 0)
                      Text('$nVisits', style: const TextStyle(color: _visitColor, fontWeight: FontWeight.w700)),
                    if (nVisits > 0 && nCalls > 0) const Text(' + '),
                    if (nCalls > 0) Text('$nCalls', style: const TextStyle(color: callColor, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                for (final v in visits.take(extra > 0 ? _shown - 1 : _shown))
                  Row(
                    children: [
                      Icon(v.isCall ? Icons.call : Icons.circle, size: v.isCall ? 10 : 7, color: v.isCall ? callColor : _visitColor),
                      const SizedBox(width: 3),
                      Expanded(child: Text(v.clientName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                if (extra > 0)
                  Text(
                    AppLocalizations.of(context).calMore(extra + 1),
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
