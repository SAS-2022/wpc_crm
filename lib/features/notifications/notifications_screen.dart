import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'notifications.dart';

/// Bell with the unread count; opens the notifications list.
class NotificationsBell extends ConsumerWidget {
  const NotificationsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: AppLocalizations.of(context).notifications,
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _text(AppLocalizations l10n, AppNotification n, String from, String owner, String day) => switch (n.type) {
        NotificationType.planSubmitted => l10n.notifPlanSubmitted(from, n.count, day),
        NotificationType.planApproved => l10n.notifPlanApproved(from, day),
        NotificationType.planRejected => l10n.notifPlanRejected(from, day),
        NotificationType.planChanged => l10n.notifPlanChanged(from, day),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(notificationsProvider).value ?? const <AppNotification>[];
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          if (list.any((n) => !n.read))
            TextButton(onPressed: () => markAllRead(list), child: Text(l10n.markAllRead)),
        ],
      ),
      body: list.isEmpty
          ? Center(child: Text(l10n.noNotifications))
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = list[i];
                final day = n.date.isEmpty ? '' : DateFormat.MMMEd(locale).format(DateTime.parse(n.date));
                return ListTile(
                  tileColor: n.read ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  leading: Icon(switch (n.type) {
                    NotificationType.planSubmitted => Icons.assignment,
                    NotificationType.planApproved => Icons.check_circle,
                    NotificationType.planRejected => Icons.cancel,
                    NotificationType.planChanged => Icons.edit_calendar,
                  }),
                  title: Text(_text(l10n, n, users[n.fromId]?.name ?? '', users[n.ownerId]?.name ?? '', day)),
                  subtitle: n.createdAt == null ? null : Text(DateFormat.MMMd(locale).add_jm().format(n.createdAt!)),
                  onTap: () {
                    if (!n.read) markRead(n.id);
                    context.push('/plan/${n.ownerId}?date=${n.date}');
                  },
                );
              },
            ),
    );
  }
}
