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

/// `/kam-meetings` (2026-11-22): SM / GM — meetings and tasks of every KAM
/// (KAM chips filter), "New meeting"; a KAM — their tasks first, then
/// their meetings.
class KamMeetingsScreen extends ConsumerStatefulWidget {
  const KamMeetingsScreen({super.key});

  @override
  ConsumerState<KamMeetingsScreen> createState() => _KamMeetingsScreenState();
}

class _KamMeetingsScreenState extends ConsumerState<KamMeetingsScreen> {
  /// null = every KAM.
  String? _kam;

  /// Tasks tab: show done ones too.
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final manages = managesKamMeetings(me);
    final now = DateTime.now();
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final kams = activeKams(users);
    final meetingsAsync = ref.watch(kamMeetingsProvider);
    final tasksAsync = ref.watch(kamTasksProvider);
    bool mineOrPicked(String kamId) => manages ? (_kam == null || kamId == _kam) : kamId == me.id;
    final meetings = sortKamMeetings((meetingsAsync.value ?? const <KamMeeting>[]).where((m) => mineOrPicked(m.kamId)), now);
    final allTasks = (tasksAsync.value ?? const <KamTask>[]).where((t) => mineOrPicked(t.kamId)).toList();
    final openCount = allTasks.where((t) => !t.done).length;
    final tasks = sortKamTasks(allTasks.where((t) => _showDone || !t.done), now);
    final upcoming = meetings.where((m) => m.isUpcoming(now)).toList();
    final past = meetings.where((m) => !m.isUpcoming(now)).toList();
    final loading = (meetingsAsync.isLoading && !meetingsAsync.hasValue) || (tasksAsync.isLoading && !tasksAsync.hasValue);
    final error = meetingsAsync.error ?? tasksAsync.error;

    Widget empty(String text) => Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)),
        );
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    final meetingsTab = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        if (meetings.isEmpty) empty(manages ? l10n.kamNoMeetingsManager : l10n.kamNoMeetings),
        if (upcoming.isNotEmpty) header(l10n.kamUpcomingMeetings(upcoming.length)),
        for (final m in upcoming) KamMeetingCard(meeting: m, showKam: manages),
        if (past.isNotEmpty) header(l10n.kamPastMeetings(past.length)),
        for (final m in past) KamMeetingCard(meeting: m, showKam: manages),
      ],
    );
    final tasksTab = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.kamOpenTasks(openCount)),
              selected: !_showDone,
              onSelected: (_) => setState(() => _showDone = false),
            ),
            ChoiceChip(
              label: Text(l10n.kamAllTasks(allTasks.length)),
              selected: _showDone,
              onSelected: (_) => setState(() => _showDone = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty) empty(_showDone ? l10n.kamNoTasks : l10n.kamNoOpenTasks),
        for (final t in tasks) KamTaskTile(task: t, showKam: manages && _kam == null, openMeeting: true),
      ],
    );

    final tabs = manages
        ? [(l10n.kamMeetingsTab, meetingsTab), (l10n.kamTasksTab, tasksTab)]
        : [(l10n.kamMyTasksTab, tasksTab), (l10n.kamMeetingsTab, meetingsTab)];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.kamMeetings),
          bottom: TabBar(tabs: [for (final (label, _) in tabs) Tab(text: label)]),
        ),
        floatingActionButton: manages
            ? FloatingActionButton.extended(
                onPressed: () => context.push(
                  Uri(path: '/kam-meetings/new', queryParameters: {'kam': ?_kam}).toString(),
                ),
                icon: const Icon(Icons.add),
                label: Text(l10n.kamNewMeeting),
              )
            : null,
        body: Column(
          children: [
            if (manages && kams.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(l10n.kamAllKams),
                        selected: _kam == null,
                        onSelected: (_) => setState(() => _kam = null),
                      ),
                    ),
                    for (final k in kams)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(k.name),
                          selected: _kam == k.id,
                          onSelected: (_) => setState(() => _kam = _kam == k.id ? null : k.id),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(l10n.errorWithMessage('$error')))
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: TabBarView(children: [for (final (_, w) in tabs) w]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
