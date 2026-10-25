import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import 'page_access.dart';

String appPageLabel(AppLocalizations l10n, AppPage p) => switch (p) {
      AppPage.clients => l10n.clients,
      AppPage.map => l10n.map,
      AppPage.visits => l10n.visits,
      AppPage.teamPlans => l10n.teamPlans,
      AppPage.reports => l10n.reports,
      AppPage.transfers => l10n.transferredClients,
      AppPage.liveTracking => l10n.liveTracking,
      AppPage.routeHistory => l10n.routeHistory,
      AppPage.drivers => l10n.driversPage,
      AppPage.vehicles => l10n.vehicles,
      AppPage.attendance => l10n.attendance,
      AppPage.hrArea => l10n.hrArea,
      AppPage.users => l10n.users,
      AppPage.importClients => l10n.importClients,
      AppPage.settings => l10n.appSettings,
    };

/// App settings → Page access (`/settings/page-access`, SM / GM): one card
/// per role with every page of the app under it; highlighted = the role may
/// open it, tap to change (saved right away). Pages the role's data rules
/// don't allow are greyed out with a lock.
class PageAccessScreen extends ConsumerWidget {
  const PageAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final access = ref.watch(pageAccessProvider).value ?? PageAccess.defaults;
    final messenger = ScaffoldMessenger.of(context);
    Future<void> toggle(AppPage page, UserRole role, bool on) async {
      try {
        await savePageAccess(access.turned(page, role, on));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageAccess)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(l10n.pageAccessHelp, style: theme.textTheme.bodySmall),
          ),
          for (final role in UserRole.assignable)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.label(l10n), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final page in AppPage.values)
                          if (!page.possible.contains(role))
                            // Not possible for this role: shown greyed out.
                            Tooltip(
                              message: l10n.pageNotForRole,
                              child: FilterChip(
                                avatar: const Icon(Icons.lock_outline, size: 16),
                                label: Text(appPageLabel(l10n, page)),
                                selected: false,
                                onSelected: null,
                              ),
                            )
                          else
                            FilterChip(
                              label: Text(appPageLabel(l10n, page)),
                              selected: access.allows(role, page),
                              onSelected: page.locked(role) ? null : (on) => toggle(page, role, on),
                            ),
                      ],
                    ),
                    if (AppPage.settings.locked(role)) ...[
                      const SizedBox(height: 6),
                      Text(l10n.pageAccessLocked, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(l10n.pageAccessMarkedManagers, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
