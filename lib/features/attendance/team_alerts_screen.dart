import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart' show BusyLabel;
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'team_alerts.dart';

/// "08:15" → "8:15 AM" in the reader's language.
String _clock(BuildContext context, String hhmm) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.first), m = p.length > 1 ? int.tryParse(p[1]) : null;
  if (h == null || m == null) return hhmm;
  return DateFormat.jm(Localizations.localeOf(context).toString()).format(DateTime(2026, 1, 1, h, m));
}

/// What happened, e.g. "Asked for a 30 min break".
String alertWhat(BuildContext context, AppLocalizations l10n, TeamAlert a) => switch (a.kind) {
      TeamAlertKind.late => l10n.alertLate(_clock(context, a.time)),
      TeamAlertKind.breakRequest => l10n.alertBreak(a.count),
      TeamAlertKind.earlyCheckout => l10n.alertEarlyCheckout,
      TeamAlertKind.absence => l10n.alertAbsence,
    };

IconData alertIcon(TeamAlertKind k) => switch (k) {
      TeamAlertKind.late => Icons.alarm,
      TeamAlertKind.breakRequest => Icons.free_breakfast_outlined,
      TeamAlertKind.earlyCheckout => Icons.directions_walk,
      TeamAlertKind.absence => Icons.event_busy_outlined,
    };

String presetLabel(AppLocalizations l10n, AlertActionPreset p) => switch (p) {
      AlertActionPreset.called => l10n.presetCalled,
      AlertActionPreset.toldInAdvance => l10n.presetToldInAdvance,
      AlertActionPreset.reminded => l10n.presetReminded,
      AlertActionPreset.talked => l10n.presetTalked,
      AlertActionPreset.askedDocument => l10n.presetAskedDocument,
      AlertActionPreset.toHr => l10n.presetToHr,
      AlertActionPreset.approved => l10n.presetApproved,
      AlertActionPreset.rejected => l10n.presetRejected,
      AlertActionPreset.other => l10n.presetOther,
    };

/// One line on the state: waiting for me / sent up / handled.
String _stateLine(AppLocalizations l10n, TeamAlert a, String me, Map<String, AppUser> users) {
  if (!a.open) {
    if (a.action?.auto == 'checkedIn') return l10n.alertAutoCheckedIn;
    return a.action?.taken == false ? l10n.alertNoActionTaken : l10n.alertHandled;
  }
  if (a.waitsFor(me)) return l10n.alertWaitingForYou;
  return l10n.alertSentUp(a.toIds.map((id) => users[id]?.name ?? '').where((n) => n.isNotEmpty).join(', '));
}

/// `/team-alerts`: every follow-up the person was told about.
class TeamAlertsScreen extends ConsumerWidget {
  const TeamAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final alerts = ref.watch(myTeamAlertsProvider);
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    if (me == null) return const SizedBox.shrink();
    final list = alerts.value ?? const <TeamAlert>[];
    final open = [for (final a in list) if (a.open) a];
    final done = [for (final a in list) if (!a.open) a];
    Widget tab(List<TeamAlert> items) => alerts.isLoading && !alerts.hasValue
        ? const Center(child: CircularProgressIndicator())
        : items.isEmpty
            ? Center(child: Text(l10n.alertNothingWaiting))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => TeamAlertTile(alert: items[i], me: me.id, users: users),
              );
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.teamAlerts),
          bottom: TabBar(tabs: [
            Tab(text: l10n.teamAlertsWaiting(open.length)),
            Tab(text: l10n.teamAlertsHandled(done.length)),
          ]),
        ),
        body: TabBarView(children: [tab(open), tab(done)]),
      ),
    );
  }
}

class TeamAlertTile extends StatelessWidget {
  const TeamAlertTile({super.key, required this.alert, required this.me, required this.users});

  final TeamAlert alert;
  final String me;
  final Map<String, AppUser> users;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final a = alert;
    final urgent = a.waitsFor(me);
    final color = !a.open
        ? theme.colorScheme.outline
        : urgent
            ? (a.escalated ? theme.colorScheme.error : Colors.orange.shade800)
            : theme.colorScheme.primary;
    return ListTile(
      leading: Icon(alertIcon(a.kind), color: color),
      title: Text(users[a.uid]?.name ?? ''),
      subtitle: Text(
        [
          alertWhat(context, l10n, a),
          if (a.createdAt != null) DateFormat.MMMd(locale).add_jm().format(a.createdAt!),
          _stateLine(l10n, a, me, users),
        ].join(' · '),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: a.escalated ? Chip(label: Text(l10n.alertLevel(a.level)), visualDensity: VisualDensity.compact) : null,
      onTap: () => context.push('/team-alerts/${a.id}'),
    );
  }
}

/// The employee's attendance day: their follow-ups and the action recorded
/// (hidden when none).
class DayTeamAlerts extends ConsumerWidget {
  const DayTeamAlerts({super.key, required this.uid, required this.date});

  final String uid;

  /// 'yyyy-MM-dd'.
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final list = ref.watch(dayTeamAlertsProvider((uid: uid, date: date))).value ?? const <TeamAlert>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(l10n.teamAlerts, style: theme.textTheme.titleSmall),
        for (final a in list)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(alertIcon(a.kind), color: a.open ? theme.colorScheme.error : theme.colorScheme.outline),
            title: Text(alertWhat(context, l10n, a)),
            subtitle: Text(alertOutcome(context, l10n, a, users, locale)),
            onTap: () => context.push('/team-alerts/${a.id}'),
          ),
      ],
    );
  }
}

/// "Called the employee – “…” · Sami · 8:40 AM", or where it waits now.
String alertOutcome(BuildContext context, AppLocalizations l10n, TeamAlert a, Map<String, AppUser> users, String locale) {
  final names = a.toIds.map((id) => users[id]?.name ?? '').where((n) => n.isNotEmpty).join(', ');
  if (a.open) return l10n.alertWaitingFor(names);
  final act = a.action;
  final what = switch (act?.auto) {
    'approved' || 'accepted' => l10n.alertAutoApproved,
    'rejected' => l10n.alertAutoRejected,
    'cancelled' => l10n.alertAutoCancelled,
    'checkedIn' => l10n.alertAutoCheckedIn,
    _ => act?.taken == false
        ? l10n.alertNoActionTaken
        : act?.preset != null
            ? presetLabel(l10n, act!.preset!)
            : l10n.alertTaken,
  };
  return [
    [what, if (act != null && act.note.isNotEmpty) '“${act.note}”'].join(' – '),
    ?users[act?.byId]?.name,
    if (act?.at case final at?) DateFormat.jm(locale).format(at),
  ].join(' · ');
}

/// Home: follow-ups waiting for the person's action (hidden when none).
class TeamAlertsCard extends ConsumerWidget {
  const TeamAlertsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(currentUserProvider).value;
    final list = ref.watch(openTeamAlertsProvider);
    if (me == null || list.isEmpty) return const SizedBox.shrink();
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    const shown = 5;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.teamAlertsCardTitle(list.length), style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final a in list.take(shown)) TeamAlertTile(alert: a, me: me.id, users: users),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: () => context.push('/team-alerts'), child: Text(l10n.teamAlertsViewAll)),
            ),
          ],
        ),
      ),
    );
  }
}

/// `/team-alerts/:id`: what happened, who was told when, and the action.
class TeamAlertScreen extends ConsumerStatefulWidget {
  const TeamAlertScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<TeamAlertScreen> createState() => _TeamAlertScreenState();
}

class _TeamAlertScreenState extends ConsumerState<TeamAlertScreen> {
  bool _taken = true;
  AlertActionPreset? _preset;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(TeamAlert a, AppUser me) async {
    final l10n = AppLocalizations.of(context);
    final note = _note.text.trim();
    if (_taken && _preset == null) {
      setState(() => _error = l10n.alertPickAction);
      return;
    }
    if (_taken && _preset == AlertActionPreset.other && note.isEmpty) {
      setState(() => _error = l10n.alertNoteRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await recordAlertAction(a, me, taken: _taken, preset: _preset, note: note);
      messenger.showSnackBar(SnackBar(content: Text(l10n.alertSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final me = ref.watch(currentUserProvider).value;
    final async = ref.watch(teamAlertProvider(widget.id));
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final time = DateFormat.jm(locale);
    final dayTime = DateFormat.MMMEd(locale).add_jm();
    String names(List<String> ids) => ids.map((id) => users[id]?.name ?? '').where((n) => n.isNotEmpty).join(', ');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alertActionTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
        data: (a) {
          if (a == null || me == null) return Center(child: Text(l10n.alertNotFound));
          final person = users[a.uid];
          final requestPath = switch (a.kind) {
            TeamAlertKind.absence => '/absence/${a.ref}',
            TeamAlertKind.breakRequest || TeamAlertKind.earlyCheckout => '/',
            TeamAlertKind.late => me.seesTeamAttendance ? '/attendance' : null,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(alertIcon(a.kind), size: 32, color: a.open ? theme.colorScheme.error : theme.colorScheme.outline),
                        title: Text(person?.name ?? '', style: theme.textTheme.titleMedium),
                        subtitle: Text([
                          if (person != null) person.role.label(l10n),
                          if (DateTime.tryParse(a.date) case final d?) DateFormat.MMMEd(locale).format(d),
                        ].join(' · ')),
                      ),
                      Text(alertWhat(context, l10n, a), style: theme.textTheme.bodyLarge),
                      if (a.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('“${a.note}”')),
                      if (requestPath != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(a.kind == TeamAlertKind.late ? l10n.attendance : l10n.alertOpenRequest),
                            onPressed: () => requestPath == '/' ? context.go('/') : context.push(requestPath),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.alertStepsTitle, style: theme.textTheme.titleSmall),
              for (final s in a.steps)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 12, child: Text('${s.level + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text(names(s.toIds)),
                  subtitle: s.at == null ? null : Text(dayTime.format(s.at!)),
                ),
              if (a.open)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    a.topReached
                        ? l10n.alertTopReached
                        : a.dayOver || a.nextAt == null
                            ? l10n.alertDayOver
                            : l10n.alertNextLevelAt(time.format(a.nextAt!)),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              if (!a.open) _Recorded(alert: a, users: users),
              if (a.canAct(me.id)) ..._form(a, me, l10n, theme),
              if (a.open && !a.canAct(me.id))
                Text(l10n.alertOnlyTold, style: theme.textTheme.bodyMedium),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _form(TeamAlert a, AppUser me, AppLocalizations l10n, ThemeData theme) => [
        Text(l10n.alertWhatDone, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, icon: const Icon(Icons.check_circle_outline), label: Text(l10n.alertTaken)),
            ButtonSegment(value: false, icon: const Icon(Icons.do_not_disturb_on_outlined), label: Text(l10n.alertNoActionTaken)),
          ],
          selected: {_taken},
          onSelectionChanged: (v) => setState(() {
            _taken = v.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        if (_taken)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presetsFor(a.kind))
                ChoiceChip(
                  label: Text(presetLabel(l10n, p)),
                  selected: _preset == p,
                  onSelected: (_) => setState(() {
                    _preset = p;
                    _error = null;
                  }),
                ),
            ],
          ),
        if (a.kind == TeamAlertKind.late)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.alertLateClosesOnCheckIn, style: theme.textTheme.bodySmall),
          ),
        if (_taken && (a.kind == TeamAlertKind.breakRequest || a.kind == TeamAlertKind.earlyCheckout))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.alertDecideOnHome, style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: _taken ? l10n.alertNoteLabel : l10n.alertNoteNoAction,
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : () => _save(a, me),
          child: BusyLabel(busy: _busy, child: Text(l10n.save)),
        ),
      ];
}

class _Recorded extends StatelessWidget {
  const _Recorded({required this.alert, required this.users});

  final TeamAlert alert;
  final Map<String, AppUser> users;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final act = alert.action;
    final by = users[act?.byId]?.name ?? '';
    final when = act?.at == null ? '' : DateFormat.MMMEd(locale).add_jm().format(act!.at!);
    final title = switch (act?.auto) {
      'approved' || 'accepted' => l10n.alertAutoApproved,
      'rejected' => l10n.alertAutoRejected,
      'cancelled' => l10n.alertAutoCancelled,
      'checkedIn' => l10n.alertAutoCheckedIn,
      _ => act?.taken == false
          ? l10n.alertNoActionTaken
          : [if (act?.preset case final p?) presetLabel(l10n, p) else l10n.alertTaken].join(),
    };
    // Closed by itself (decision on the request, check-in): not a missed action.
    final missed = act?.taken == false && act?.auto == null;
    return Card(
      margin: EdgeInsets.zero,
      color: missed ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer,
      child: ListTile(
        leading: Icon(missed ? Icons.do_not_disturb_on_outlined : Icons.check_circle_outline),
        title: Text(title),
        subtitle: Text([
          if (act != null && act.note.isNotEmpty) '“${act.note}”',
          [if (by.isNotEmpty) by, if (when.isNotEmpty) when].join(' · '),
        ].where((s) => s.isNotEmpty).join('\n')),
      ),
    );
  }
}
