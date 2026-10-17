import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../users/users_repository.dart';
import 'leave_repository.dart';
import 'leave_rules.dart';
import 'leave_widgets.dart';

/// One request: what, when, the approval steps in order (who decided, when,
/// comment), its documents, and the buttons for whoever acts now: Approve /
/// Reject for the current step's approver, Cancel for the owner while pending.
class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on StateError {
      messenger.showSnackBar(SnackBar(content: Text(l10n.leaveAlreadyDecided)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(AppUser me, {required bool approve}) async {
    final l10n = AppLocalizations.of(context);
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(approve ? l10n.approveRequest : l10n.rejectRequest),
        content: TextField(
          controller: comment,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(labelText: approve ? l10n.commentOptional : l10n.rejectReason),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(
            style: approve ? null : FilledButton.styleFrom(backgroundColor: Theme.of(dialog).colorScheme.error),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(approve ? l10n.approve : l10n.reject),
          ),
        ],
      ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (ok != true || !mounted) return;
    final users = ref.read(usersProvider).value ?? const <AppUser>[];
    await _run(() => ref
        .read(leaveRepositoryProvider)
        .decide(id: widget.id, me: me, approve: approve, comment: text, users: users));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lang = Localizations.localeOf(context).languageCode;
    final me = ref.watch(currentUserProvider).value;
    final async = ref.watch(leaveRequestProvider(widget.id));
    final r = async.value;
    if (me == null || r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: async.isLoading ? const CircularProgressIndicator() : Text(l10n.noAccessTitle)),
      );
    }
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final mine = r.uid == me.id;
    final canAct = canDecide(me: me, requesterId: r.uid, awaitingKey: r.awaitingKey);
    final fmt = DateFormat.yMMMd(locale).add_jm();
    final dates = leaveDatesText(r, locale, l10n);

    return Scaffold(
      appBar: AppBar(title: Text(r.typeName(lang))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            leading: CircleAvatar(child: Text((users[r.uid]?.name ?? '?').characters.firstOrNull ?? '?')),
            title: Text(users[r.uid]?.name ?? ''),
            subtitle: Text([users[r.uid]?.role.label(l10n) ?? '', if (r.createdAt != null) fmt.format(r.createdAt!)]
                .where((s) => s.isNotEmpty)
                .join(' · ')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: AlignmentDirectional.centerStart, child: LeaveStatusChip(request: r)),
          ),
          if (dates.isNotEmpty)
            ListTile(leading: const Icon(Icons.event), title: Text(dates), subtitle: r.halfDay ? Text(l10n.halfDay) : null),
          if (r.reason.isNotEmpty)
            ListTile(leading: const Icon(Icons.notes), title: SelectableText(r.reason)),
          AttachmentsSection(
            owner: (parent: AttachmentParent.leaveRequests, id: r.id),
            canAdd: (mine && r.status == LeaveStatus.pending) || me.role.canManageHr,
            canDelete: me.role.canManageHr,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.approvalOrder, style: theme.textTheme.titleMedium),
          ),
          for (final (i, s) in r.steps.indexed)
            ListTile(
              leading: Icon(
                switch (s.status) {
                  LeaveStatus.approved => Icons.check_circle,
                  LeaveStatus.rejected => Icons.cancel,
                  _ => i == r.stepIndex && r.status == LeaveStatus.pending ? Icons.hourglass_top : Icons.radio_button_unchecked,
                },
                color: switch (s.status) {
                  LeaveStatus.approved => Colors.green.shade700,
                  LeaveStatus.rejected => theme.colorScheme.error,
                  _ => i == r.stepIndex && r.status == LeaveStatus.pending ? Colors.orange.shade800 : theme.colorScheme.outline,
                },
              ),
              title: Text('${i + 1}. ${stepLabel(s, users, l10n)}'),
              subtitle: s.byId == null
                  ? null
                  : Text([
                      users[s.byId]?.name ?? '',
                      if (s.at != null) fmt.format(s.at!),
                      if (s.comment.isNotEmpty) '“${s.comment}”',
                    ].where((x) => x.isNotEmpty).join(' · ')),
            ),
          if (canAct)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: _busy ? null : () => _decide(me, approve: false),
                    icon: const Icon(Icons.close),
                    label: Text(l10n.reject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _decide(me, approve: true),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.approve),
                  ),
                ),
              ]),
            ),
          if (mine && r.status == LeaveStatus.pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(() => ref.read(leaveRepositoryProvider).cancel(r.id)),
                icon: const Icon(Icons.block),
                label: Text(l10n.cancelRequest),
              ),
            ),
        ],
      ),
    );
  }
}
