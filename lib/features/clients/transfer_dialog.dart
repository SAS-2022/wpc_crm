import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'clients_repository.dart';
import 'transfer.dart';

/// Asks which sales executive to move [clients] to, then moves them. A KAM
/// only moves clients of their team, to their team; others are skipped.
/// Returns true when clients were moved.
Future<bool> showTransferDialog(BuildContext context, WidgetRef ref, List<Client> clients) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final me = ref.read(currentUserProvider).value;
  if (me == null || clients.isEmpty) return false;
  final users = ref.read(usersProvider).value ?? const <AppUser>[];
  final byId = {for (final u in users) u.id: u};
  final allowed = clients.where((c) => canTransferFrom(me, c.assignedTo, byId)).toList();
  if (allowed.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.transferNoneAllowed)));
    return false;
  }
  // '' = unassigned. The current owner is left out when all share one.
  final owners = {for (final c in allowed) c.assignedTo ?? ''};
  final options = [
    for (final u in transferTargets(me, users)) (id: u.id, name: u.name),
    if (canUnassign(me)) (id: '', name: l10n.unassigned),
  ].where((o) => owners.length > 1 || o.id != owners.single).toList();
  if (options.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.noTransferTargets)));
    return false;
  }

  String? picked;
  final target = await showDialog<String>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text(clients.length == 1 ? l10n.transferClientTitle : l10n.transferClientsTitle(allowed.length)),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final o in options)
                ListTile(
                  leading: Icon(picked == o.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  title: Text(o.name),
                  onTap: () => setState(() => picked = o.id),
                ),
              const SizedBox(height: 8),
              if (allowed.length < clients.length)
                Text(
                  l10n.transferSkipped(clients.length - allowed.length),
                  style: TextStyle(color: Theme.of(dialog).colorScheme.error),
                ),
              Text(l10n.transferPlanNote, style: Theme.of(dialog).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: picked == null ? null : () => Navigator.pop(dialog, picked),
            child: Text(l10n.transferClients),
          ),
        ],
      ),
    ),
  );
  if (target == null) return false;

  try {
    final toId = target.isEmpty ? null : target;
    final moved = await ref.read(clientsRepositoryProvider).transfer(allowed, toId: toId, by: me);
    final name = toId == null ? l10n.unassigned : byId[toId]?.name ?? '';
    messenger.showSnackBar(SnackBar(content: Text(l10n.clientsTransferredCount(moved, name))));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    return false;
  }
}
