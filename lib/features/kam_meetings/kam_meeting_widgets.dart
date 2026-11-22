import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'kam_meeting.dart';
import 'kam_meetings_repository.dart';

/// Active KAMs (main or extra role), by name.
List<AppUser> activeKams(List<AppUser> users) =>
    [for (final u in users) if (u.active && u.hasRole(UserRole.kam)) u]..sort((a, b) => a.name.compareTo(b.name));

String meetingWhen(BuildContext context, DateTime? at) {
  if (at == null) return '';
  final locale = Localizations.localeOf(context).toString();
  return '${DateFormat.yMMMEd(locale).format(at)} · ${DateFormat.jm(locale).format(at)}';
}

/// The KAM's "Mark as done" dialog: the comment is required.
Future<void> showMarkDoneDialog(BuildContext context, WidgetRef ref, KamTask task) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = TextEditingController();
  var tried = false;
  final comment = await showDialog<String>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setState) => AlertDialog(
        title: Text(l10n.kamTaskMarkDone),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.text, style: Theme.of(dialog).textTheme.titleSmall),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: '${l10n.kamTaskComment} *',
                  helperText: l10n.kamTaskCommentHelp,
                  errorText: tried && !validDoneComment(controller.text) ? l10n.kamTaskCommentRequired : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (!validDoneComment(controller.text)) return setState(() => tried = true);
              Navigator.pop(dialog, controller.text);
            },
            child: Text(l10n.kamTaskMarkDone),
          ),
        ],
      ),
    ),
  );
  if (comment == null) return;
  final meeting = ref.read(kamMeetingProvider(task.meetingId));
  final users = ref.read(usersProvider).value ?? const <AppUser>[];
  final notify = [
    if (meeting != null && meeting.createdBy.isNotEmpty) meeting.createdBy
    else
      for (final u in users)
        if (u.active && u.can.isAdmin) u.id,
  ];
  try {
    await markKamTaskDone(task, comment, notifyIds: notify);
    messenger.showSnackBar(SnackBar(content: Text(l10n.kamTaskDoneSaved)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
  }
}

/// One task: done tick, text, due day (red when overdue), the KAM's done
/// comment; KAM: "Mark as done"; SM / GM: reopen.
class KamTaskTile extends ConsumerWidget {
  const KamTaskTile({super.key, required this.task, this.showKam = false, this.openMeeting = false});

  final KamTask task;
  final bool showKam;

  /// Tapping opens the task's meeting.
  final bool openMeeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final kamName = users.where((u) => u.id == task.kamId).firstOrNull?.name ?? '';
    final now = DateTime.now();
    final overdue = task.overdue(now);
    final isKam = me?.id == task.kamId;
    final manages = managesKamMeetings(me);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: openMeeting ? () => context.push('/kam-meetings/${task.meetingId}') : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                task.done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: task.done ? Colors.green.shade600 : (overdue ? theme.colorScheme.error : theme.colorScheme.outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: task.done ? TextDecoration.lineThrough : null,
                        color: task.done ? theme.colorScheme.outline : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (showKam && kamName.isNotEmpty) kamName,
                        if (task.due != null)
                          overdue
                              ? l10n.kamTaskOverdue(DateFormat.MMMd(locale).format(task.due!))
                              : l10n.kamTaskDue(DateFormat.MMMd(locale).format(task.due!)),
                        if (task.done && task.doneAt != null) l10n.kamTaskDoneOn(DateFormat.yMMMd(locale).format(task.doneAt!)),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: overdue ? theme.colorScheme.error : null),
                    ),
                    if (task.comment.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${l10n.kamTaskComment}: ${task.comment}', style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ],
                ),
              ),
              if (isKam && !task.done)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: FilledButton.tonal(
                    onPressed: () => showMarkDoneDialog(context, ref, task),
                    child: Text(l10n.kamTaskMarkDone),
                  ),
                )
              else if (manages && task.done)
                IconButton(
                  tooltip: l10n.kamTaskReopen,
                  icon: const Icon(Icons.undo),
                  onPressed: () => reopenKamTask(task),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A meeting in a list: when, the KAM, tasks done / all, the conclusion's
/// first lines.
class KamMeetingCard extends ConsumerWidget {
  const KamMeetingCard({super.key, required this.meeting, this.showKam = true});

  final KamMeeting meeting;
  final bool showKam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final tasks = ref.watch(meetingTasksProvider(meeting.id));
    final done = tasks.where((t) => t.done).length;
    final upcoming = meeting.isUpcoming(DateTime.now());
    final kamName = users.where((u) => u.id == meeting.kamId).firstOrNull?.name ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/kam-meetings/${meeting.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(upcoming ? Icons.event : Icons.event_available,
                      size: 20, color: upcoming ? theme.colorScheme.primary : theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [if (showKam) kamName, meetingWhen(context, meeting.at)].where((s) => s.isNotEmpty).join(' · '),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(l10n.kamTasksDoneOf(done, tasks.length)),
                      backgroundColor: done == tasks.length ? Colors.green.withValues(alpha: 0.12) : null,
                    ),
                ],
              ),
              if (meeting.conclusion.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(meeting.conclusion, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
              ] else if (upcoming)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(l10n.kamMeetingUpcoming, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home (KAM, SM / GM): the KAM's open tasks and next meeting; SM / GM the
/// next meetings and open tasks across KAMs. Hidden with nothing to show.
class KamMeetingsCard extends ConsumerWidget {
  const KamMeetingsCard({super.key, required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!seesKamMeetings(me)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final manages = managesKamMeetings(me);
    final meetings = ref.watch(kamMeetingsProvider).value ?? const <KamMeeting>[];
    final tasks = ref.watch(kamTasksProvider).value ?? const <KamTask>[];
    final mine = manages ? tasks : tasks.where((t) => t.kamId == me.id);
    final open = sortKamTasks(mine.where((t) => !t.done), now);
    final upcoming = sortKamMeetings(
      (manages ? meetings : meetings.where((m) => m.kamId == me.id)).where((m) => m.isUpcoming(now)),
      now,
    );
    if (open.isEmpty && upcoming.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.kamMeetings, style: theme.textTheme.titleMedium)),
                TextButton(onPressed: () => context.push('/kam-meetings'), child: Text(l10n.viewAll)),
              ],
            ),
            for (final m in upcoming.take(manages ? 3 : 1)) KamMeetingCard(meeting: m, showKam: manages),
            if (open.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Text(l10n.kamOpenTasks(open.length), style: theme.textTheme.labelLarge),
              ),
              for (final t in open.take(3)) KamTaskTile(task: t, showKam: manages, openMeeting: true),
            ],
          ],
        ),
      ),
    );
  }
}
