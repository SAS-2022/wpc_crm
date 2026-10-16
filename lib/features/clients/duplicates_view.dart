import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'client.dart';
import 'clients_repository.dart';
import 'duplicates.dart';
import 'merge.dart';
import 'person_style.dart';

String duplicateReasonLabel(DuplicateReason r, AppLocalizations l10n) => switch (r) {
      DuplicateReason.sameVat => l10n.dupSameVat,
      DuplicateReason.sameName => l10n.dupSameName,
      DuplicateReason.samePhone => l10n.dupSamePhone,
      DuplicateReason.similarName => l10n.dupSimilarName,
      DuplicateReason.nearby => l10n.dupNearby,
    };

/// The client list's "Possible duplicates" view: one card per group, where
/// KAM / managers hide a client or mark the group as different clients, and
/// the sales manager / GM merge it.
class DuplicatesList extends StatelessWidget {
  const DuplicatesList({super.key, required this.groups});

  final List<DuplicateGroup> groups;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      children: [
        if (groups.isEmpty)
          Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.noDuplicates))),
        for (final g in groups) _GroupCard(group: g),
      ],
    );
  }
}

class _GroupCard extends ConsumerStatefulWidget {
  const _GroupCard({required this.group});

  final DuplicateGroup group;

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
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

  Future<void> _merge(AppUser me) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<(Client, List<Client>)>(
      context: context,
      builder: (_) => _MergeDialog(clients: widget.group.clients),
    );
    if (choice == null) return;
    final (keep, others) = choice;
    await _run(
      () => ref.read(clientsRepositoryProvider).merge(keep, others, byId: me.id),
      l10n.clientsMerged(others.length + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final repo = ref.read(clientsRepositoryProvider);
    final g = widget.group;
    final now = DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final r in DuplicateReason.values.where(g.reasons.contains))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(duplicateReasonLabel(r, l10n)),
                      backgroundColor: g.identical ? theme.colorScheme.errorContainer : null,
                    ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            for (final c in g.clients)
              ListTile(
                onTap: () => context.push('/clients/${c.id}'),
                leading: PersonBadge(userId: c.assignedTo, name: users[c.assignedTo]?.name ?? l10n.unassigned),
                title: Text(c.name),
                subtitle: Text(
                  [
                    [c.city, users[c.assignedTo]?.name ?? l10n.unassigned].where((s) => s.isNotEmpty).join(' · '),
                    [
                      if (c.vat.isNotEmpty) '${l10n.vat}: ${c.vat}',
                      if (c.phone.isNotEmpty) c.phone,
                      if (c.mobile.isNotEmpty && c.mobile != c.phone) c.mobile,
                    ].join(' · '),
                    [
                      '${l10n.lastVisit}: ${c.lastVisitAt == null ? l10n.never : l10n.daysAgo(now.difference(c.lastVisitAt!).inDays)}',
                      if (!c.hasLocation) l10n.noLocation,
                      c.source == 'manual' ? l10n.addedInApp : 'Odoo',
                    ].join(' · '),
                  ].where((s) => s.isNotEmpty).join('\n'),
                ),
                isThreeLine: true,
                trailing: me == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.visibility_off_outlined),
                        tooltip: l10n.hideClient,
                        onPressed: _busy
                            ? null
                            : () => _run(() => repo.setHidden(c.id, hidden: true, by: me.id), l10n.clientHidden),
                      ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : () => _run(() => repo.markNotDuplicates(g.clients), l10n.markedNotDuplicates),
                    icon: const Icon(Icons.call_split),
                    label: Text(l10n.notDuplicates),
                  ),
                  // Merging edits visits and deletes clients: sales manager / GM.
                  if (me?.role.isAdmin ?? false)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _merge(me!),
                      icon: const Icon(Icons.merge),
                      label: Text(l10n.mergeClients),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pick the client to keep and which of the others to merge into it.
class _MergeDialog extends StatefulWidget {
  const _MergeDialog({required this.clients});

  final List<Client> clients;

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  late String _keep = suggestedKeep(widget.clients).id;
  late final _include = {for (final c in widget.clients) c.id};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final keep = widget.clients.firstWhere((c) => c.id == _keep);
    final others = [for (final c in widget.clients) if (c.id != _keep && _include.contains(c.id)) c];
    return AlertDialog(
      title: Text(l10n.mergeClientsTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mergeHint),
              const SizedBox(height: 8),
              for (final c in widget.clients)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => setState(() {
                    _keep = c.id;
                    _include.add(c.id);
                  }),
                  leading: Icon(
                    c.id == _keep ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: c.id == _keep ? scheme.primary : null,
                  ),
                  title: Text(c.name),
                  subtitle: Text(c.id == _keep
                      ? l10n.mergeKeep
                      : [c.city, if (c.vat.isNotEmpty) c.vat].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: c.id == _keep
                      ? null
                      : Checkbox(
                          value: _include.contains(c.id),
                          onChanged: (v) => setState(() => v == true ? _include.add(c.id) : _include.remove(c.id)),
                        ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: others.isEmpty ? null : () => Navigator.pop(context, (keep, others)),
          child: Text(l10n.mergeCount(others.length + 1)),
        ),
      ],
    );
  }
}
