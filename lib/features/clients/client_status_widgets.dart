import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'client_status.dart';

String clientStatusLabel(AppLocalizations l10n, ClientStatus s) => switch (s) {
      ClientStatus.active => l10n.clientStatusActive,
      ClientStatus.closed => l10n.clientStatusClosed,
      ClientStatus.notWorking => l10n.clientStatusNotWorking,
    };

IconData clientStatusIcon(ClientStatus s) => switch (s) {
      ClientStatus.active => Icons.storefront,
      ClientStatus.closed => Icons.block,
      ClientStatus.notWorking => Icons.do_not_disturb_on_outlined,
    };

/// Client page: asks for (sales exec) or makes (KAM / managers) a status
/// change. Returns when done or cancelled.
Future<void> showClientStatusDialog(BuildContext context, WidgetRef ref, Client client) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final me = ref.read(currentUserProvider).value;
  if (me == null) return;
  final users = ref.read(usersProvider).value ?? const <AppUser>[];
  final direct = canSetStatusDirectly(me, client, {for (final u in users) u.id: u});
  final result = await showDialog<(ClientStatus, String)>(
    context: context,
    builder: (_) => _StatusDialog(current: client.status, direct: direct),
  );
  if (result == null) return;
  final (status, note) = result;
  try {
    if (direct) {
      await setClientStatus(client, status, me: me, note: note);
      messenger.showSnackBar(SnackBar(content: Text(l10n.clientStatusChanged)));
    } else {
      await requestClientStatus(client, status, me: me, users: users, note: note);
      messenger.showSnackBar(SnackBar(content: Text(l10n.clientStatusRequestSent)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.current, required this.direct});

  final ClientStatus current;
  final bool direct;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  final _note = TextEditingController();
  late ClientStatus _status =
      ClientStatus.values.firstWhere((s) => s != widget.current && s != ClientStatus.active, orElse: () => ClientStatus.active);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.changeClientStatus),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<ClientStatus>(
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v ?? _status),
              child: Column(
                children: [
                  for (final s in ClientStatus.values)
                    if (s != widget.current)
                      RadioListTile<ClientStatus>(
                        contentPadding: EdgeInsets.zero,
                        value: s,
                        secondary: Icon(clientStatusIcon(s)),
                        title: Text(clientStatusLabel(l10n, s)),
                      ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.clientStatusReason),
            ),
            if (!widget.direct)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.clientStatusNeedsApproval, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_status, _note.text.trim())),
          child: Text(widget.direct ? l10n.save : l10n.sendForApproval),
        ),
      ],
    );
  }
}

/// Client page, top: the status when not active, and a pending request
/// with Approve / Reject (approvers) or Cancel (the requester).
class ClientStatusBanners extends ConsumerStatefulWidget {
  const ClientStatusBanners({super.key, required this.client});

  final Client client;

  @override
  ConsumerState<ClientStatusBanners> createState() => _ClientStatusBannersState();
}

class _ClientStatusBannersState extends ConsumerState<ClientStatusBanners> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(AppUser me) async {
    final l10n = AppLocalizations.of(context);
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.reject),
        content: TextField(
          controller: comment,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(labelText: l10n.clientStatusReason),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.reject)),
        ],
      ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (ok != true || !mounted) return;
    await _run(() => decideClientStatus(widget.client, approve: false, me: me, comment: text), l10n.clientStatusRejected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final locale = Localizations.localeOf(context).toString();
    final c = widget.client;
    final req = c.statusRequest;
    if (me == null || (c.isActive && req == null)) return const SizedBox.shrink();

    Widget banner({required Color color, required Color onColor, required IconData icon, required String title, String? subtitle, List<Widget> actions = const []}) =>
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          color: color,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(icon, color: onColor),
                  title: Text(title, style: TextStyle(color: onColor, fontWeight: FontWeight.w600)),
                  subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle, style: TextStyle(color: onColor)),
                ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
                  ),
              ],
            ),
          ),
        );

    return Column(
      children: [
        if (!c.isActive)
          banner(
            color: theme.colorScheme.surfaceContainerHighest,
            onColor: theme.colorScheme.onSurface,
            icon: clientStatusIcon(c.status),
            title: c.statusAt == null
                ? clientStatusLabel(l10n, c.status)
                : l10n.clientStatusSince(clientStatusLabel(l10n, c.status), DateFormat.yMMMd(locale).format(c.statusAt!)),
            subtitle: c.statusLog.lastOrNull?.note,
          ),
        if (req != null)
          banner(
            color: theme.colorScheme.tertiaryContainer,
            onColor: theme.colorScheme.onTertiaryContainer,
            icon: Icons.hourglass_top,
            title: req.byId == me.id
                ? l10n.clientStatusWaiting(clientStatusLabel(l10n, req.status))
                : l10n.clientStatusAsked(users[req.byId]?.name ?? '?', clientStatusLabel(l10n, req.status)),
            subtitle: [
              if (req.note.isNotEmpty) req.note,
              if (req.at != null) DateFormat.yMMMd(locale).add_jm().format(req.at!),
            ].join('\n'),
            actions: [
              if (req.byId == me.id)
                TextButton(
                  onPressed: _busy ? null : () => _run(() => cancelClientStatusRequest(c), l10n.clientStatusRequestCancelled),
                  child: Text(l10n.cancelRequest),
                ),
              if (canDecideStatus(me, c, users)) ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _reject(me),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.reject),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => decideClientStatus(c, approve: true, me: me), l10n.clientStatusApproved),
                  icon: _busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(l10n.approve),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Client page: every status change, newest first.
class ClientStatusHistory extends ConsumerWidget {
  const ClientStatusHistory({super.key, required this.client});

  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final s in client.statusLog.reversed)
          ListTile(
            dense: true,
            leading: Icon(s.approved ? clientStatusIcon(s.status) : Icons.cancel_outlined,
                color: s.approved ? null : theme.colorScheme.error),
            title: Text(s.approved
                ? clientStatusLabel(l10n, s.status)
                : l10n.clientStatusRejectedEntry(clientStatusLabel(l10n, s.status))),
            subtitle: Text([
              if (s.at != null) DateFormat.yMMMd(locale).format(s.at!),
              if (s.requestedBy.isNotEmpty) l10n.clientStatusRequestedBy(users[s.requestedBy]?.name ?? '?'),
              l10n.clientStatusDecidedBy(users[s.decidedBy]?.name ?? '?'),
              if (s.note.isNotEmpty) s.note,
              if (s.comment.isNotEmpty) s.comment,
            ].join(' · ')),
          ),
      ],
    );
  }
}
