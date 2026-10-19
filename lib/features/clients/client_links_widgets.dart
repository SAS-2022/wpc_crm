import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'client.dart';
import 'client_links.dart';
import 'client_widgets.dart';
import 'clients_repository.dart';
import 'visit_rules.dart';

/// Client page: the main company this client belongs to and its branches;
/// KAM / managers link, add and unlink.
class ClientLinksSection extends ConsumerWidget {
  const ClientLinksSection({super.key, required this.client, required this.canEdit});

  final Client client;
  final bool canEdit;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final all = ref.watch(allClientsProvider).value ?? const <Client>[];
    final byId = {for (final c in all) c.id: c};
    final parent = client.parentId == null ? null : byId[client.parentId];
    final branches = branchesById(all)[client.id] ?? const <Client>[];
    if (!canEdit && parent == null && branches.isEmpty) return const SizedBox.shrink();

    Widget tile(Client c, String label, {required VoidCallback onUnlink}) => ListTile(
          dense: true,
          leading: Icon(label == l10n.mainCompany ? Icons.account_tree_outlined : Icons.subdirectory_arrow_right),
          title: Text(c.name),
          subtitle: Text([label, if (c.city.isNotEmpty) c.city].join(' · ')),
          onTap: () => context.push('/clients/${c.id}'),
          trailing: canEdit
              ? IconButton(icon: const Icon(Icons.link_off), tooltip: l10n.unlinkClient, onPressed: onUnlink)
              : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parent != null) tile(parent, l10n.mainCompany, onUnlink: () => _run(context, () => setClientParent([client.id], null))),
        for (final b in branches) tile(b, l10n.branch, onUnlink: () => _run(context, () => setClientParent([b.id], null))),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (parent == null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(l10n.linkToMainCompany),
                    onPressed: () async {
                      final picked = await pickClient(
                        context,
                        title: l10n.linkToMainCompany,
                        allowed: (c) => canLink(client.id, c.id, all),
                      );
                      if (picked != null && context.mounted) await _run(context, () => setClientParent([client.id], picked.id));
                    },
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_link),
                  label: Text(l10n.addBranch),
                  onPressed: () async {
                    final picked = await pickClient(
                      context,
                      title: l10n.addBranch,
                      allowed: (c) => c.parentId != client.id && canLink(c.id, client.id, all),
                    );
                    if (picked == null || !context.mounted) return;
                    // A branch already under another company moves here; ask first.
                    if (picked.parentId != null && byId[picked.parentId] != null) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          content: Text(l10n.moveBranchConfirm(picked.name, byId[picked.parentId]!.name, client.name)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
                            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.addBranch)),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                    }
                    await _run(context, () => setClientParent([picked.id], client.id));
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Search sheet over every client; returns the one tapped. [allowed] greys
/// out clients that can't be picked (e.g. the client itself).
Future<Client?> pickClient(BuildContext context, {required String title, required bool Function(Client) allowed}) =>
    showModalBottomSheet<Client>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ClientPicker(title: title, allowed: allowed),
    );

class _ClientPicker extends ConsumerStatefulWidget {
  const _ClientPicker({required this.title, required this.allowed});

  final String title;
  final bool Function(Client) allowed;

  @override
  ConsumerState<_ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends ConsumerState<_ClientPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = Client.normalizeName(_query);
    final list = [
      for (final c in ref.watch(clientsProvider).value ?? const <Client>[])
        if (q.isEmpty || c.nameKey.contains(q) || c.aliases.any((a) => Client.normalizeName(a).contains(q)) || c.vat.contains(q))
          c,
    ]..sort((a, b) => a.name.compareTo(b.name));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                final ok = widget.allowed(c);
                return ListTile(
                  enabled: ok,
                  title: Text(c.name),
                  subtitle: c.city.isEmpty ? null : Text(c.city),
                  onTap: ok ? () => Navigator.pop(context, c) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Clients list "Linked clients" view: each main company on the left, its
/// branches on the right (branches of branches indented under them).
class LinkedClientsTree extends ConsumerWidget {
  const LinkedClientsTree({super.key, required this.trees});

  final List<ClientNode> trees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final now = DateTime.now();
    if (trees.isEmpty) return Center(child: Text(l10n.noLinkedClients));

    Widget clientTile(Client c, {bool main = false}) => ListTile(
          dense: !main,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: CategoryBadge(category: c.category, color: clientColor(c, rules, now), size: main ? 36 : 28),
          title: Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: main ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600) : null),
          subtitle: c.city.isEmpty ? null : Text(c.city, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => context.push('/clients/${c.id}'),
        );

    List<Widget> branchTiles(List<ClientNode> nodes, int depth) => [
          for (final n in nodes) ...[
            Padding(
              padding: EdgeInsetsDirectional.only(start: 16.0 * depth),
              child: Row(
                children: [
                  if (depth > 0) Icon(Icons.subdirectory_arrow_right, size: 16, color: theme.colorScheme.outline),
                  Expanded(child: clientTile(n.client)),
                ],
              ),
            ),
            ...branchTiles(n.children, depth + 1),
          ],
        ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      children: [
        for (final t in trees)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          clientTile(t.client, main: true),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(l10n.branchCount(t.size), style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: branchTiles(t.children, 0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
