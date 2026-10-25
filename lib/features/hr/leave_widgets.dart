import 'hr_people.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';

/// Who a step waits for: the KAM's name, else the role.
String stepLabel(ApprovalStep s, Map<String, AppUser> users, AppLocalizations l10n) =>
    s.uid != null ? users[s.uid]?.name ?? s.role.label(l10n) : s.role.label(l10n);

/// "Oct 20 – Oct 22 · 3 days", "Oct 20 · ½ day", or "" for requests without dates.
String leaveDatesText(LeaveRequest r, String locale, AppLocalizations l10n) {
  if (r.from == null) return '';
  final from = DateTime.parse(r.from!);
  final to = DateTime.parse(r.to ?? r.from!);
  final fmt = DateFormat.MMMd(locale);
  final range = from == to ? fmt.format(from) : '${fmt.format(from)} – ${fmt.format(to)}';
  return '$range · ${l10n.leaveDaysCount(formatLeaveDays(r.days))}';
}

/// Status text and colour: "Waiting for Sales manager", "Approved", …
(String, Color, IconData) leaveStatusStyle(
  LeaveRequest r,
  Map<String, AppUser> users,
  AppLocalizations l10n,
  ColorScheme scheme,
) =>
    switch (r.status) {
      LeaveStatus.pending => (
          l10n.waitingFor(r.currentStep == null ? '' : stepLabel(r.currentStep!, users, l10n)),
          Colors.orange.shade800,
          Icons.hourglass_top,
        ),
      LeaveStatus.approved => (l10n.leaveApprovedStatus, Colors.green.shade700, Icons.check_circle),
      LeaveStatus.rejected => (l10n.rejected, scheme.error, Icons.cancel),
      LeaveStatus.cancelled => (l10n.leaveCancelledStatus, scheme.onSurfaceVariant, Icons.block),
    };

class LeaveStatusChip extends ConsumerWidget {
  const LeaveStatusChip({super.key, required this.request});

  final LeaveRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final theme = Theme.of(context);
    final (label, color, icon) = leaveStatusStyle(request, users, AppLocalizations.of(context), theme.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// One request in a list; [showPerson] for lists of several people's requests.
class LeaveRequestTile extends ConsumerWidget {
  const LeaveRequestTile({super.key, required this.request, this.showPerson = false});

  final LeaveRequest request;
  final bool showPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final dates = leaveDatesText(request, locale, l10n);
    return ListTile(
      onTap: () => context.push('/leave/${request.id}'),
      leading: Icon(request.isLeave ? Icons.beach_access : Icons.description_outlined),
      title: Text([
        if (showPerson) users[request.uid]?.name ?? '?',
        request.typeName(Localizations.localeOf(context).languageCode),
      ].join(' · ')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dates.isNotEmpty) Text(dates),
          const SizedBox(height: 4),
          LeaveStatusChip(request: request),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

/// Home card: requests waiting for the signed-in user's approval. Hidden
/// when there are none.
class LeaveApprovalsCard extends ConsumerWidget {
  const LeaveApprovalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final waiting = ref.watch(leaveAwaitingMeProvider).value ?? const <LeaveRequest>[];
    if (waiting.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.leaveWaitingForYou(waiting.length), style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final r in waiting.take(5)) LeaveRequestTile(request: r, showPerson: true),
            if (waiting.length > 5)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: () => context.push('/hr'), child: Text(l10n.viewAll)),
              ),
          ],
        ),
      ),
    );
  }
}

/// A person's leave for one year as a table (2026-10-23, HR asked to see it
/// under each request): per leave type the days entitled, used (approved),
/// waiting for approval (this request included) and remaining. The row of
/// [highlightTypeId] (the request's type) is marked. Balances are readable
/// by the HR area only, so it is shown to them.
class LeaveBalanceTable extends ConsumerWidget {
  const LeaveBalanceTable({super.key, required this.uid, this.day, this.highlightTypeId});

  final String uid;

  /// 'yyyy-MM-dd' in the leave year to show (the person's own year, from
  /// their joining date); null = today's.
  final String? day;
  final String? highlightTypeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final types = ref.watch(leaveTypesProvider).value ?? LeaveType.defaults;
    final year = personLeaveYear(ref, uid, DateTime.tryParse(day ?? '') ?? DateTime.now());
    final requests = [
      for (final r in ref.watch(allLeaveRequestsProvider).value ?? const <LeaveRequest>[])
        if (r.uid == uid) r.use,
    ];
    final balances = personLeaveBalances(ref, uid: uid, year: year, types: types, requests: requests);
    if (balances.isEmpty) return const SizedBox.shrink();
    final anyCarried = balances.values.any((b) => b.carried != 0);
    final head = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget cell(String text, {TextStyle? style, bool first = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(text, style: style, textAlign: first ? TextAlign.start : TextAlign.end),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.leaveBalancePeriod(leaveYearLabel(context, joiningDateOf(ref, uid), year)), style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {0: FlexColumnWidth(2.2)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.dividerColor))),
              children: [
                cell(l10n.balanceColType, style: head, first: true),
                cell(l10n.balanceColEntitled, style: head),
                if (anyCarried) cell(l10n.balanceColCarried, style: head),
                cell(l10n.balanceColUsed, style: head),
                cell(l10n.balanceColWaiting, style: head),
                cell(l10n.balanceColLeft, style: head),
              ],
            ),
            for (final t in types)
              if (balances[t.id] case final b?)
                TableRow(
                  decoration: t.id == highlightTypeId
                      ? BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5))
                      : null,
                  children: [
                    cell(t.name(lang), first: true, style: t.id == highlightTypeId ? const TextStyle(fontWeight: FontWeight.w600) : null),
                    cell(formatLeaveDays(b.entitled)),
                    if (anyCarried)
                      cell(
                        b.carried == 0 ? '–' : '${b.carried > 0 ? '+' : ''}${formatLeaveDays(b.carried)}',
                        style: b.carried < 0 ? TextStyle(color: theme.colorScheme.error) : null,
                      ),
                    cell(formatLeaveDays(b.used)),
                    cell(b.pending > 0 ? formatLeaveDays(b.pending) : '–'),
                    cell(
                      formatLeaveDays(b.remaining),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: b.remaining < 0 ? theme.colorScheme.error : null,
                      ),
                    ),
                  ],
                ),
          ],
        ),
      ],
    );
  }
}
