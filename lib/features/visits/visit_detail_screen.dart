import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../attachments/attachments.dart';
import '../attachments/attachments_section.dart';
import '../plan/checklist.dart';
import '../plan/plan_repository.dart';
import '../users/users_repository.dart';
import 'visit.dart';
import 'visits_repository.dart';

/// Visit notes and flags, photos & files, the KAM "I was there" mark, and comments.
class VisitDetailScreen extends ConsumerStatefulWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends ConsumerState<VisitDetailScreen> {
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Visit visit) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.deleteVisitTitle),
        content: Text(l10n.deleteVisitBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialog).colorScheme.error),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await _run(() async {
      await ref.read(visitsRepositoryProvider).delete(visit);
      messenger.showSnackBar(SnackBar(content: Text(l10n.visitDeleted)));
      router.pop();
    });
  }

  Future<void> _send(AppUser me) async {
    final body = _comment.text.trim();
    if (body.isEmpty) return;
    await _run(() async {
      await ref.read(visitsRepositoryProvider).addComment(widget.visitId, me.id, body);
      _comment.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final visit = ref.watch(visitProvider(widget.visitId)).value;
    if (me == null || visit == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final comments = ref.watch(visitCommentsProvider(widget.visitId)).value ?? const [];
    // Plan tasks at this client, as left by the visitor.
    final planTasks = (ref.watch(visitPlanTasksProvider((visit.id, visit.salesExecId))).value ?? const [])
        .where((t) => t.checklist.isNotEmpty)
        .toList();
    final locale = Localizations.localeOf(context).toString();
    String format(DateTime? t) => t == null ? '' : DateFormat.yMMMd(locale).add_jm().format(t);
    final error = Theme.of(context).colorScheme.error;
    final far = visit.distanceMeters != null && visit.distanceMeters! > visitRadiusMeters;
    final repo = ref.read(visitsRepositoryProvider);
    final isKam = me.role == UserRole.kam;
    final ownVisit = visit.salesExecId == me.id;

    Widget kamSection;
    if (visit.kamId != null) {
      final lateBy = visit.checkedInAt != null && visit.kamMarkedAt != null
          ? visit.kamMarkedAt!.difference(visit.checkedInAt!)
          : Duration.zero;
      kamSection = ListTile(
        leading: Icon(Icons.groups, color: Theme.of(context).colorScheme.primary),
        title: Text(l10n.kamWasThere(users[visit.kamId]?.name ?? '')),
        subtitle: lateBy.inMinutes >= 60 ? Text(l10n.markedHoursLater(lateBy.inHours)) : null,
        trailing: visit.kamId == me.id
            ? TextButton(
                onPressed: _busy ? null : () => _run(() => repo.setKam(visit.id, null)),
                child: Text(l10n.remove),
              )
            : null,
      );
    } else if (isKam && !ownVisit) {
      kamSection = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _run(() => repo.setKam(visit.id, me.id)),
          icon: const Icon(Icons.groups),
          label: Text(l10n.iWasThere),
        ),
      );
    } else {
      kamSection = const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(visit.clientName),
        actions: [
          if (me.role.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteVisitTitle,
              onPressed: _busy ? null : () => _delete(visit),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.event_available),
                  title: Text(format(visit.checkedInAt)),
                  subtitle: Text(l10n.visitedBy(users[visit.salesExecId]?.name ?? '')),
                ),
                ListTile(
                  leading: Icon(Icons.my_location, color: far || visit.mocked ? error : Colors.green.shade600),
                  title: Text(visit.distanceMeters == null
                      ? l10n.noLocation
                      : l10n.distanceFromClient(formatDistance(visit.distanceMeters!))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (visit.accuracy != null) Text(l10n.locationAccuracy(visit.accuracy!.round())),
                      if (far) Text(l10n.farFlag(formatDistance(visit.distanceMeters!)), style: TextStyle(color: error)),
                      if (visit.mocked) Text(l10n.fakeGpsFlag, style: TextStyle(color: error)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(visit.notes, style: Theme.of(context).textTheme.bodyLarge),
                ),
                if (planTasks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Text(l10n.tasks, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final t in planTasks) PlanChecklist(task: t),
                ],
                AttachmentsSection(
                  owner: (parent: AttachmentParent.visits, id: visit.id),
                  canAdd: me.role.isSupervisor || ownVisit,
                  canDelete: me.role.isSupervisor,
                ),
                kamSection,
                ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(l10n.openClient),
                  onTap: () => context.push('/clients/${visit.clientId}'),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(l10n.comments, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (comments.isEmpty) ListTile(title: Text(l10n.noComments)),
                for (final c in comments)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text((users[c.authorId]?.name ?? '?').characters.firstOrNull ?? '?'),
                    ),
                    title: Text(c.body),
                    subtitle: Text([
                      users[c.authorId]?.name ?? '',
                      format(c.createdAt),
                    ].where((s) => s.isNotEmpty).join(' · ')),
                  ),
              ],
            ),
          ),
          // KAM / managers and the visit's author can comment.
          if (me.role.isSupervisor || ownVisit)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _comment,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(hintText: l10n.writeComment),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      tooltip: l10n.send,
                      onPressed: _busy ? null : () => _send(me),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
