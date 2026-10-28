import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_widgets.dart';
import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'notifications.dart';
import '../attendance/absence.dart';
import '../attendance/absence_sheet.dart' show absenceLeaveLabel, absenceReasonIcon, absenceReasonLabel;
import '../clients/client_status.dart';
import '../clients/client_status_widgets.dart';
import '../../core/app_version.dart';

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

  /// '08:15' → '8:15 AM' in the reader's language.
  static String _clock(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first), m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (h == null || m == null) return hhmm;
    return DateFormat.jm(Localizations.localeOf(context).toString()).format(DateTime(2026, 1, 1, h, m));
  }

  /// 'yyyy-MM-dd' – 'yyyy-MM-dd' as "Wed, Oct 22" or "Wed, Oct 22 – Thu, Oct 23".
  static String _range(BuildContext context, String from, String to) {
    final f = DateFormat.MMMEd(Localizations.localeOf(context).toString());
    final a = DateTime.tryParse(from), b = DateTime.tryParse(to);
    if (a == null) return from;
    return b == null || b == a ? f.format(a) : '${f.format(a)} – ${f.format(b)}';
  }

  static String _renewal(AppLocalizations l10n, String item) =>
      switch (Renewal.values.asNameMap()[item]) {
        final r? => renewalLabel(l10n, r),
        null => item,
      };

  String _checkIn(BuildContext context, AppLocalizations l10n, AppNotification n, String from, String meId) {
    final time = _clock(context, n.time);
    return [
      n.fromId == meId ? l10n.notifCheckedInSelf(time) : l10n.notifCheckedIn(from, time),
      if (n.siteName.isNotEmpty) n.siteName,
      if (n.count > 0) l10n.notifMinutesLate(n.count),
    ].join(' · ');
  }

  String _text(BuildContext context, AppLocalizations l10n, AppNotification n, String from, String owner, String day, String meId) =>
      switch (n.type) {
        NotificationType.attendanceCheckedIn => _checkIn(context, l10n, n, from, meId),
        NotificationType.attendanceLate => l10n.notifAttendanceLate(_clock(context, n.time)),
        NotificationType.attendanceAtSite => l10n.notifAtSite(n.siteName, _clock(context, n.time)),
        NotificationType.overtimeStarted => switch (n.issue) {
            'driving' => n.ownerId == meId
                ? l10n.notifDriveOvertimeSelf(_clock(context, n.time))
                : l10n.notifDriveOvertime(owner, _clock(context, n.time)),
            'site' => l10n.notifOvertimeConfirmed(owner, n.siteName.isEmpty ? '' : ' · ${n.siteName}', _clock(context, n.time)),
            _ => n.ownerId == meId
                ? l10n.notifOvertimeStartedSelf(n.siteName, _clock(context, n.time))
                : l10n.notifOvertimeStarted(owner, n.siteName, _clock(context, n.time)),
          },
        NotificationType.overtimeAsk => n.count > 0
            ? l10n.notifOvertimeAskReminder(_clock(context, n.time))
            : l10n.notifOvertimeAsk(_clock(context, n.time), n.siteName),
        NotificationType.absenceReported => [
            l10n.notifAbsenceReported(owner, day, absenceReasonLabel(l10n, AbsenceReason.fromKey(n.issue))),
            if (n.note.isNotEmpty) '“${n.note}”',
          ].join(' '),
        NotificationType.absenceAccepted => l10n.notifAbsenceAccepted(from, day, absenceLeaveLabel(l10n, AbsenceLeave.fromKey(n.issue))),
        NotificationType.absenceRejected => l10n.notifAbsenceRejected(from, day),
        NotificationType.teamOnLeave => l10n.notifTeamOnLeave(owner, _range(context, n.date, n.note)),
        NotificationType.earlyCheckoutRequested => [
            l10n.notifEarlyCheckoutRequested(owner),
            if (n.note.isNotEmpty) '“${n.note}”',
          ].join(' '),
        NotificationType.earlyCheckoutApproved => l10n.notifEarlyCheckoutApproved(from),
        NotificationType.earlyCheckoutRejected => [
            l10n.notifEarlyCheckoutRejected(from),
            if (n.note.isNotEmpty) '“${n.note}”',
          ].join(' '),
        NotificationType.vehicleRenewalDue => n.count > 0
            ? l10n.notifVehicleRenewalDue(n.vehicleName, _renewal(l10n, n.issue), n.count, day)
            : l10n.notifVehicleRenewalExpired(n.vehicleName, _renewal(l10n, n.issue), day),
        NotificationType.vehicleOilDue => n.count > 0
            ? l10n.notifVehicleOilDueSoon(n.vehicleName, n.count, formatKm(context, int.tryParse(n.note) ?? 0))
            : l10n.notifVehicleOilDue(n.vehicleName, formatKm(context, int.tryParse(n.note) ?? 0)),
        NotificationType.planSubmitted => l10n.notifPlanSubmitted(from, n.count, day),
        NotificationType.planApproved => l10n.notifPlanApproved(from, day),
        NotificationType.planRejected => l10n.notifPlanRejected(from, day),
        NotificationType.planChanged => l10n.notifPlanChanged(from, day),
        NotificationType.planItemsAdded => l10n.notifPlanItemsAdded(from, n.count, day),
        NotificationType.clientsTransferredIn => l10n.notifClientsTransferredIn(from, n.count),
        NotificationType.clientsTransferredOut =>
          l10n.notifClientsTransferredOut(from, n.count, n.ownerId.isEmpty ? l10n.unassigned : owner),
        NotificationType.leaveRequested => l10n.notifLeaveRequested(owner),
        NotificationType.leaveApproved => l10n.notifLeaveApproved(from),
        NotificationType.leaveRejected => l10n.notifLeaveRejected(from),
        NotificationType.clientStatusRequested =>
          l10n.notifClientStatusRequested(from, n.clientName, clientStatusLabel(l10n, ClientStatus.fromKey(n.issue))),
        NotificationType.clientStatusApproved =>
          l10n.notifClientStatusApproved(from, n.clientName, clientStatusLabel(l10n, ClientStatus.fromKey(n.issue))),
        NotificationType.updateReminder => l10n.notifUpdateReminder(from),
        NotificationType.registrationRequested => l10n.notifRegistrationRequested(owner),
        NotificationType.clientStatusRejected =>
          l10n.notifClientStatusRejected(from, n.clientName, clientStatusLabel(l10n, ClientStatus.fromKey(n.issue))),
        NotificationType.trackingIssue => switch (n.issue) {
            'gpsOff' => l10n.notifGpsOff(from),
            'locationDenied' => l10n.notifLocationDenied(from),
            'notAlways' => l10n.notifLocationNotAlways(from),
            'offline' => l10n.notifTrackingOffline(from),
            'noAnswer' => l10n.notifPhoneNoAnswer(from, _clock(context, n.time), n.count),
            'notificationsOff' => l10n.notifNotificationsOff(from),
            _ => l10n.notifBatteryOptimized(from),
          },
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(notificationsProvider).value ?? const <AppNotification>[];
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final meId = ref.watch(currentUserProvider).value?.id ?? '';
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
                    NotificationType.planItemsAdded => Icons.playlist_add,
                    NotificationType.clientsTransferredIn || NotificationType.clientsTransferredOut => Icons.swap_horiz,
                    NotificationType.leaveRequested => Icons.beach_access,
                    NotificationType.leaveApproved => Icons.event_available,
                    NotificationType.leaveRejected => Icons.event_busy,
                    NotificationType.clientStatusRequested => Icons.store_mall_directory_outlined,
                    NotificationType.clientStatusApproved => Icons.check_circle,
                    NotificationType.clientStatusRejected => Icons.cancel,
                    NotificationType.updateReminder => Icons.system_update,
                    NotificationType.registrationRequested => Icons.person_add_alt,
                    NotificationType.attendanceCheckedIn => Icons.how_to_reg,
                    NotificationType.attendanceLate => Icons.alarm,
                    NotificationType.attendanceAtSite => Icons.warning_amber_rounded,
                    NotificationType.overtimeStarted || NotificationType.overtimeAsk => Icons.more_time,
                    NotificationType.absenceReported => absenceReasonIcon(AbsenceReason.fromKey(n.issue)),
                    NotificationType.absenceAccepted => Icons.event_available,
                    NotificationType.absenceRejected => Icons.event_busy,
                    NotificationType.teamOnLeave => Icons.beach_access,
                    NotificationType.earlyCheckoutRequested => Icons.directions_walk,
                    NotificationType.earlyCheckoutApproved => Icons.check_circle,
                    NotificationType.earlyCheckoutRejected => Icons.cancel,
                    NotificationType.vehicleRenewalDue => Icons.directions_car_outlined,
                    NotificationType.vehicleOilDue => Icons.oil_barrel_outlined,
                    NotificationType.trackingIssue => switch (n.issue) {
                        'battery' => Icons.battery_alert,
                        'offline' => Icons.signal_wifi_off,
                        'noAnswer' => Icons.phonelink_off,
                        'notificationsOff' => Icons.notifications_off,
                        _ => Icons.location_off,
                      },
                  }, color: n.type == NotificationType.trackingIssue ? Theme.of(context).colorScheme.error : null),
                  title: Text(_text(context, l10n, n, users[n.fromId]?.name ?? '', users[n.ownerId]?.name ?? '', day, meId)),
                  subtitle: n.createdAt == null ? null : Text(DateFormat.MMMd(locale).add_jm().format(n.createdAt!)),
                  onTap: () {
                    if (!n.read) markRead(n.id);
                    switch (n.type) {
                      case NotificationType.clientsTransferredIn || NotificationType.clientsTransferredOut:
                        context.go('/clients');
                      case NotificationType.trackingIssue:
                        context.push('/live');
                      case NotificationType.leaveRequested ||
                            NotificationType.leaveApproved ||
                            NotificationType.leaveRejected:
                        context.push('/leave/${n.ref}');
                      case NotificationType.clientStatusRequested ||
                            NotificationType.clientStatusApproved ||
                            NotificationType.clientStatusRejected:
                        context.push('/clients/${n.ref}');
                      case NotificationType.updateReminder:
                        openAppStore();
                      case NotificationType.attendanceCheckedIn when n.fromId != meId:
                        context.push('/attendance');
                      case NotificationType.overtimeStarted when n.ownerId != meId:
                        context.push('/attendance');
                      // Home: the manager's requests card / the person's attendance card.
                      case NotificationType.attendanceCheckedIn ||
                            NotificationType.attendanceLate ||
                            NotificationType.attendanceAtSite ||
                            NotificationType.overtimeStarted ||
                            NotificationType.overtimeAsk ||
                            NotificationType.earlyCheckoutRequested ||
                            NotificationType.earlyCheckoutApproved ||
                            NotificationType.earlyCheckoutRejected:
                        context.go('/');
                      case NotificationType.absenceReported ||
                            NotificationType.absenceAccepted ||
                            NotificationType.absenceRejected:
                        if (n.ref.isNotEmpty) context.push('/absence/${n.ref}');
                      case NotificationType.teamOnLeave:
                        if (n.ref.isNotEmpty) context.push('/leave/${n.ref}');
                      case NotificationType.vehicleRenewalDue || NotificationType.vehicleOilDue:
                        if (n.ref.isNotEmpty) context.push('/vehicles/${n.ref}');
                      case NotificationType.registrationRequested:
                        context.push('/users/${n.ownerId}');
                      default:
                        context.push('/plan/${n.ownerId}?date=${n.date}');
                    }
                  },
                );
              },
            ),
    );
  }
}
