import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'kam_meeting.dart';
import 'kam_meeting_widgets.dart';
import 'kam_meetings_repository.dart';

/// `/kam-meetings/:id`: the meeting's time, KAM, conclusion and tasks. SM /
/// GM edit or delete it; the KAM marks tasks done with a comment.
class KamMeetingScreen extends ConsumerWidget {
  const KamMeetingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    final loading = ref.watch(kamMeetingsProvider).isLoading;
    final meeting = ref.watch(kamMeetingProvider(id));
    if (meeting == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: loading ? const CircularProgressIndicator() : Text(l10n.kamMeetingNotFound)),
      );
    }
    final manages = managesKamMeetings(me);
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    String nameOf(String uid) => users.where((u) => u.id == uid).firstOrNull?.name ?? '';
    final tasks = sortKamTasks(ref.watch(meetingTasksProvider(id)), DateTime.now());
    final done = tasks.where((t) => t.done).length;

    Future<void> delete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.kamDeleteMeeting),
          content: Text(l10n.kamDeleteMeetingConfirm(tasks.length)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await deleteKamMeeting(id);
      if (context.mounted) context.pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kamMeeting),
        actions: [
          if (manages) ...[
            IconButton(
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/kam-meetings/$id/edit'),
            ),
            IconButton(tooltip: l10n.delete, icon: const Icon(Icons.delete_outline), onPressed: delete),
          ],
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(nameOf(meeting.kamId), style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(meetingWhen(context, meeting.at))),
                  if (meeting.isUpcoming(DateTime.now()))
                    Chip(visualDensity: VisualDensity.compact, label: Text(l10n.kamUpcoming)),
                ],
              ),
              if (meeting.createdBy.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l10n.kamMeetingBy(nameOf(meeting.createdBy)), style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 16),
              Text(l10n.kamConclusion, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    meeting.conclusion.isEmpty ? l10n.kamNoConclusion : meeting.conclusion,
                    style: meeting.conclusion.isEmpty
                        ? theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)
                        : theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tasks.isEmpty ? l10n.kamTasksTab : '${l10n.kamTasksTab} · ${l10n.kamTasksDoneOf(done, tasks.length)}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.kamNoTasks, style: theme.textTheme.bodyMedium),
                ),
              for (final t in tasks) KamTaskTile(task: t),
            ],
          ),
        ),
      ),
    );
  }
}
