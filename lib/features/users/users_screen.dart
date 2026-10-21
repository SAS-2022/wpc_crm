import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/app_version.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'users_repository.dart';
import '../clients/client_tags.dart';
import '../attendance/work_sites.dart';
import 'companies.dart';
import 'user_filters.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  /// Refreshes the reminder buttons when their one-minute wait ends.
  Timer? _tick;
  bool _sending = false;
  UserFilter _filter = const UserFilter();

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(UserFilter f) {
            setState(() => _filter = f);
            setSheet(() {});
          }

          return _UserFiltersSheet(filter: _filter, onChanged: update);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _remind(List<AppUser> people) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    setState(() => _sending = true);
    try {
      final sent = await sendUpdateReminders(people, me);
      messenger.showSnackBar(SnackBar(content: Text(l10n.updateRemindersSent(sent))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final users = ref.watch(usersProvider);
    final info = ref.watch(packageInfoProvider).value;
    final ownBuild = ref.watch(ownBuildProvider);
    final now = DateTime.now();
    final positions = ref.watch(positionsByIdProvider);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.users)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/users/new'),
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addUser),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorWithMessage('$e'))),
        data: (all) {
          var list = all;
          if (list.isEmpty) return Center(child: Text(l10n.noUsers));
          // Registrations waiting for approval first.
          list = [...list.where((u) => u.isPendingApproval), ...list.where((u) => !u.isPendingApproval)];
          final latest = latestBuild(list, ownBuild);
          // The version name of the newest build (ours, or a phone's).
          final latestName = latest == ownBuild && info != null
              ? info.version
              : [for (final u in list) for (final v in u.appVersions.values) if (v.build == latest) v.version].firstOrNull ?? '';
          final outdated = [for (final u in list) if (u.active && outdatedPlatforms(u, latest).isNotEmpty) u];
          final canRemind = [for (final u in outdated) if (reminderWait(u, now) == Duration.zero) u];
          final shown = [
            for (final u in list)
              if (_filter.matches(
                u,
                roleLabel: (r) => r.label(l10n),
                outdated: (u) => outdatedPlatforms(u, latest).isNotEmpty,
              ))
                u,
          ];
          int countOf(UserStatusFilter s) => [
                for (final u in list)
                  if (UserFilter(status: s).matches(
                    u,
                    roleLabel: (r) => '',
                    outdated: (u) => outdatedPlatforms(u, latest).isNotEmpty,
                  ))
                    u,
              ].length;

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  leading: const Icon(Icons.system_update),
                  title: Text(l10n.latestAppVersion('$latestName ($latest)')),
                  subtitle: Text(outdated.isEmpty ? l10n.everyoneUpToDate : l10n.peopleOnOlderVersion(outdated.length)),
                  trailing: outdated.isEmpty
                      ? null
                      : FilledButton.tonalIcon(
                          onPressed: _sending || canRemind.isEmpty ? null : () => _remind(canRemind),
                          icon: _sending
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.notifications_active_outlined),
                          label: Text(l10n.remindAll(canRemind.length)),
                        ),
                ),
              ),
              // Search and filters.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l10n.searchUsers),
                        onChanged: (v) => setState(() => _filter = _filter.copyWith(search: v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _openFilters,
                      icon: Badge(
                        isLabelVisible: _filter.sheetCount > 0,
                        label: Text('${_filter.sheetCount}'),
                        child: const Icon(Icons.tune),
                      ),
                      label: Text(l10n.filters),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    for (final (s, label) in [
                      (UserStatusFilter.all, l10n.statusAll),
                      (UserStatusFilter.active, l10n.active),
                      (UserStatusFilter.pending, l10n.waitingApproval),
                      (UserStatusFilter.inactive, l10n.inactive),
                      (UserStatusFilter.olderApp, l10n.olderAppVersion),
                    ])
                      if (s == UserStatusFilter.all || s == _filter.status || countOf(s) > 0)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text('$label (${countOf(s)})'),
                            selected: _filter.status == s,
                            onSelected: (_) => setState(() => _filter = _filter.copyWith(status: s)),
                          ),
                        ),
                  ],
                ),
              ),
              if (_filter.sheetCount > 0 || _filter.search.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.usersShown(shown.length, list.length), style: theme.textTheme.bodySmall)),
                      if (_filter.sheetCount > 0)
                        TextButton(
                          onPressed: () => setState(() => _filter = UserFilter(search: _filter.search, status: _filter.status)),
                          child: Text(l10n.clearFilters),
                        ),
                    ],
                  ),
                ),
              if (shown.isEmpty)
                Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.noUsersMatch))),
              for (final (i, u) in shown.indexed) ...[
                if (i > 0) const Divider(height: 1),
                Builder(builder: (context) {
                  final old = outdatedPlatforms(u, latest);
                  final wait = reminderWait(u, now);
                  return ListTile(
                    leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name.characters.first)),
                    title: Text(u.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.isPendingApproval
                            ? [
                                u.requestedRole?.label(l10n) ?? positionLabel(positions, u.position, lang),
                                u.email,
                              ].where((s) => s.isNotEmpty).join(' · ')
                            : '${u.role.label(l10n)} · ${u.email}'),
                        Text.rich(TextSpan(children: [
                          if (u.appVersions.isEmpty) TextSpan(text: l10n.noAppVersion),
                          for (final (j, MapEntry(key: platform, value: v)) in u.appVersions.entries.indexed) ...[
                            if (j > 0) const TextSpan(text: ' · '),
                            TextSpan(
                              text: '${platform == 'ios' ? 'iPhone' : 'Android'} ${v.label}',
                              style: old.contains(platform)
                                  ? TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)
                                  : null,
                            ),
                          ],
                        ]), style: theme.textTheme.bodySmall),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (u.isPendingApproval)
                          Chip(
                            avatar: const Icon(Icons.hourglass_top, size: 16),
                            label: Text(l10n.waitingApproval),
                            backgroundColor: theme.colorScheme.tertiaryContainer,
                          )
                        else if (u.approval == 'rejected')
                          Chip(label: Text(l10n.registrationRejectedShort))
                        else if (!u.active)
                          Chip(label: Text(l10n.inactive)),
                        if (u.active && old.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.notifications_active_outlined),
                            color: theme.colorScheme.error,
                            tooltip: wait == Duration.zero
                                ? l10n.remindToUpdate
                                : l10n.remindedWait(wait.inSeconds + 1),
                            onPressed: _sending || wait > Duration.zero ? null : () => _remind([u]),
                          ),
                      ],
                    ),
                    onTap: () => context.go('/users/${u.id}'),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Filters sheet: role (several), company and work site.
class _UserFiltersSheet extends ConsumerWidget {
  const _UserFiltersSheet({required this.filter, required this.onChanged});

  final UserFilter filter;
  final ValueChanged<UserFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final companies = ref.watch(companiesProvider).value ?? const <Company>[];
    final sites = ref.watch(workSitesProvider).value ?? const <WorkSite>[];
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.filters, style: theme.textTheme.titleLarge)),
              TextButton(
                onPressed: filter.sheetCount == 0
                    ? null
                    : () => onChanged(UserFilter(search: filter.search, status: filter.status)),
                child: Text(l10n.clearFilters),
              ),
            ],
          ),
          heading(l10n.role),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in UserRole.assignable)
                FilterChip(
                  label: Text(r.label(l10n)),
                  selected: filter.roles.contains(r),
                  onSelected: (on) => onChanged(filter.copyWith(roles: on ? {...filter.roles, r} : ({...filter.roles}..remove(r)))),
                ),
            ],
          ),
          if (companies.isNotEmpty) ...[
            heading(l10n.company),
            DropdownButton<String?>(
              value: filter.companyId,
              isExpanded: true,
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.statusAll)),
                for (final c in companies) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => onChanged(filter.copyWith(companyId: () => v)),
            ),
          ],
          if (sites.isNotEmpty) ...[
            heading(l10n.workSites),
            DropdownButton<String?>(
              value: filter.siteId,
              isExpanded: true,
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.statusAll)),
                for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => onChanged(filter.copyWith(siteId: () => v)),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done)),
        ],
      ),
    );
  }
}
