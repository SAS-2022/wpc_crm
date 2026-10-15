import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/client.dart';
import '../clients/client_location_dialog.dart';
import '../clients/client_widgets.dart';
import '../clients/clients_repository.dart';
import '../clients/visit_rules.dart';
import '../notifications/notifications.dart';
import '../users/users_repository.dart';
import 'plan_repository.dart';

/// Adds client visits (several at once) or a free task to [owner]'s plan for
/// [date]. A sales exec's additions wait for approval and notify their
/// reviewer; a KAM / manager's additions are approved and notify the owner.
Future<void> showAddTaskSheet(
  BuildContext context, {
  required AppUser owner,
  required String date,
  Set<String> alreadyPlanned = const {},
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddTaskSheet(owner: owner, date: date, alreadyPlanned: alreadyPlanned),
    );

class _AddTaskSheet extends ConsumerStatefulWidget {
  const _AddTaskSheet({required this.owner, required this.date, required this.alreadyPlanned});

  final AppUser owner;
  final String date;
  final Set<String> alreadyPlanned;

  @override
  ConsumerState<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<_AddTaskSheet> {
  final _title = TextEditingController();
  final _selected = <String, Client>{};
  bool _visit = true;
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final me = ref.read(currentUserProvider).value!;
    if (_visit ? _selected.isEmpty : _title.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(_visit ? l10n.chooseClient : l10n.required)));
      return;
    }
    setState(() => _busy = true);
    try {
      final approved = me.role.isSupervisor;
      await ref.read(planRepositoryProvider).addMany(
            ownerId: widget.owner.id,
            date: widget.date,
            createdBy: me.id,
            approved: approved,
            clients: _visit ? [for (final c in _selected.values) (id: c.id, name: c.name)] : const [],
            title: _title.text.trim(),
          );
      final count = _visit ? _selected.length : 1;
      final users = ref.read(usersProvider).value ?? const <AppUser>[];
      await sendNotifications(
        toIds: approved ? [widget.owner.id] : reviewersOf(widget.owner, users),
        type: approved ? NotificationType.planItemsAdded : NotificationType.planSubmitted,
        fromId: me.id,
        ownerId: widget.owner.id,
        date: widget.date,
        count: count,
      );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(approved ? l10n.planUpdated(count) : l10n.planSentForApproval(count))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final rules = ref.watch(visitRulesProvider).value ?? VisitRules.defaults;
    final now = DateTime.now();
    final all = ref.watch(clientsProvider).value ?? const <Client>[];
    // A sales exec plans their own clients; a KAM's own plan can include any client.
    final candidates = all
        .where((c) => widget.owner.role != UserRole.salesExec || c.assignedTo == widget.owner.id)
        .where((c) => !widget.alreadyPlanned.contains(c.id))
        .where((c) => _query.isEmpty || c.nameKey.contains(_query) || c.city.toLowerCase().contains(_query))
        .toList()
      // Most overdue first: those are the ones to plan.
      ..sort((a, b) => visitStatus(b, rules, now).index.compareTo(visitStatus(a, rules, now).index));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.addToPlan, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, icon: const Icon(Icons.store), label: Text(l10n.clientVisit)),
                      ButtonSegment(value: false, icon: const Icon(Icons.checklist), label: Text(l10n.task)),
                    ],
                    selected: {_visit},
                    onSelectionChanged: (s) => setState(() => _visit = s.first),
                  ),
                  const SizedBox(height: 8),
                  if (_visit)
                    TextField(
                      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.search),
                      onChanged: (v) => setState(() => _query = Client.normalizeName(v)),
                    ),
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: _visit ? l10n.noteOptional : l10n.taskDescription),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !_visit
                  ? const SizedBox.shrink()
                  : candidates.isEmpty
                      ? Center(child: Text(l10n.noClients))
                      : ListView.builder(
                          itemCount: candidates.length,
                          itemBuilder: (_, i) {
                            final c = candidates[i];
                            final selected = _selected.containsKey(c.id);
                            void toggle() => setState(() => selected ? _selected.remove(c.id) : _selected[c.id] = c);
                            return ListTile(
                              onTap: toggle,
                              leading: CategoryBadge(category: c.category, color: clientColor(c, rules, now)),
                              title: Text(c.name),
                              subtitle: Text([
                                c.city,
                                if (c.hasLocation) visitStatusLabel(visitStatus(c, rules, now), l10n) else l10n.noLocation,
                              ].where((s) => s.isNotEmpty).join(' · ')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClientLocationButton(client: c),
                                  Checkbox(value: selected, onChanged: (_) => toggle()),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!(me?.role.isSupervisor ?? false))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.needsApprovalHint, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_visit && _selected.isNotEmpty ? l10n.saveCount(_selected.length) : l10n.save),
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
