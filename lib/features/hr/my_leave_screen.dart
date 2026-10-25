import 'hr_people.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';
import 'leave_widgets.dart';

/// Everyone's own leave: balance per type this year, own requests, and
/// "New request".
class MyLeaveScreen extends ConsumerWidget {
  const MyLeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final year = personLeaveYear(ref, me.id, DateTime.now());
    final requests = ref.watch(myLeaveRequestsProvider).value ?? const <LeaveRequest>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myLeave)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/leave/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.newLeaveRequest),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          LeaveBalancesCard(uid: me.id, year: year, requests: requests),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l10n.myRequests, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (requests.isEmpty) ListTile(title: Text(l10n.noLeaveRequests)),
          for (final r in requests) LeaveRequestTile(request: r),
        ],
      ),
    );
  }
}

/// Remaining days per leave type for [uid] in [year].
class LeaveBalancesCard extends ConsumerWidget {
  const LeaveBalancesCard({super.key, required this.uid, required this.year, required this.requests, this.onTap});

  final String uid;
  final int year;

  /// The person's requests (any year; filtered here).
  final List<LeaveRequest> requests;

  /// Tap a type (HR: edit the person's days).
  final void Function(LeaveType type)? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final types = ref.watch(leaveTypesProvider).value ?? LeaveType.defaults;
    final balances = personLeaveBalances(ref, uid: uid, year: year, types: types, requests: [for (final r in requests) r.use]);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(l10n.leaveBalancePeriod(leaveYearLabel(context, joiningDateOf(ref, uid), year)),
                  style: theme.textTheme.titleMedium),
            ),
            for (final t in types)
              if (balances[t.id] case final b?)
                ListTile(
                  dense: true,
                  onTap: onTap == null ? null : () => onTap!(t),
                  title: Text(t.name(lang)),
                  subtitle: b.pending > 0 || b.carried != 0
                      ? Text([
                          if (b.carried != 0) l10n.leaveCarriedDays('${b.carried > 0 ? '+' : ''}${formatLeaveDays(b.carried)}'),
                          if (b.pending > 0) l10n.leavePendingDays(formatLeaveDays(b.pending)),
                        ].join(' · '))
                      : null,
                  trailing: Text(
                    l10n.leaveRemainingOf(formatLeaveDays(b.remaining), formatLeaveDays(b.entitled)),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: b.remaining < 0 ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
