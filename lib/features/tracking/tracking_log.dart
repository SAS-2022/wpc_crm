import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

/// One change in a person's tracking, from RTDB `tracking_events/{uid}/{day}`
/// (written by the `trackingAlerts` Cloud Function, kept 30 days).
class TrackingEvent {
  const TrackingEvent({required this.at, required this.type, this.value = ''});

  final DateTime at;

  /// online, offline, gpsOn, gpsOff, onDuty, offDuty, permission (see
  /// [value]), batteryOn, batteryOff, notificationsOff, notificationsOn;
  /// from the wake-up check (`offlineAlerts`, 2026-10-24): quiet (phone sent
  /// nothing for 10 min), woken (answered the silent ping), resumed (sending
  /// again by itself), noAnswer (managers told).
  final String type;

  /// For 'permission': always, whileInUse, denied, deniedForever.
  final String value;

  /// Something that stops or may stop tracking.
  bool get isProblem =>
      const {'offline', 'gpsOff', 'batteryOn', 'notificationsOff', 'quiet', 'noAnswer'}.contains(type) || (type == 'permission' && value != 'always');
}

/// A log row: the event and, for offline / GPS off / battery optimization /
/// notifications off,
/// how long it lasted (null while it lasts or when it ran past the day).
typedef TrackingLogEntry = ({TrackingEvent event, Duration? lasted});

const _endedBy = {
  'offline': {'online'},
  'gpsOff': {'gpsOn'},
  'batteryOn': {'batteryOff'},
  'notificationsOff': {'notificationsOn'},
  'quiet': {'woken', 'resumed'},
};

/// The day's events in time order, each problem paired with the event that
/// ended it.
List<TrackingLogEntry> trackingLog(List<TrackingEvent> events) {
  final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final (i, e) in sorted.indexed)
      (
        event: e,
        lasted: switch (_endedBy[e.type]) {
          final Set<String> end => sorted.skip(i + 1).where((n) => end.contains(n.type)).firstOrNull?.at.difference(e.at),
          _ => null,
        },
      ),
  ];
}

final trackingEventsProvider = StreamProvider.autoDispose.family<List<TrackingEvent>, (String, String)>(
  (ref, key) => FirebaseDatabase.instance.ref('tracking_events/${key.$1}/${key.$2}').onValue.map((event) => [
        if (event.snapshot.value case final Map<Object?, Object?> events)
          for (final e in events.values)
            if (e case {'t': final num t, 'type': final String type})
              TrackingEvent(
                at: DateTime.fromMillisecondsSinceEpoch(t.toInt()),
                type: type,
                value: e['value'] as String? ?? '',
              ),
      ]),
);

/// "45 min" / "1 h 5 min".
String formatLasted(AppLocalizations l10n, Duration d) {
  final m = d.inMinutes;
  return m < 60 ? l10n.durationMinutes(m) : l10n.durationHoursMinutes(m ~/ 60, m % 60);
}

/// The day's tracking log, newest last, for the route history page.
class TrackingLogList extends ConsumerWidget {
  const TrackingLogList({super.key, required this.userId, required this.day});

  final String userId;

  /// 'yyyy-MM-dd'.
  final String day;

  String _label(AppLocalizations l10n, TrackingEvent e) => switch (e.type) {
        'offline' => l10n.logOffline,
        'online' => l10n.logOnline,
        'gpsOff' => l10n.logGpsOff,
        'gpsOn' => l10n.logGpsOn,
        'onDuty' => l10n.logOnDuty,
        'offDuty' => l10n.logOffDuty,
        'batteryOn' => l10n.logBatteryOn,
        'batteryOff' => l10n.logBatteryOff,
        'notificationsOff' => l10n.logNotificationsOff,
        'notificationsOn' => l10n.logNotificationsOn,
        'quiet' => l10n.logQuiet,
        'woken' => l10n.logWoken,
        'resumed' => l10n.logResumed,
        'noAnswer' => l10n.logNoAnswer,
        'permission' => l10n.logPermission(switch (e.value) {
            'always' => l10n.permissionAlways,
            'whileInUse' => l10n.permissionWhileInUse,
            _ => l10n.permissionDenied,
          }),
        _ => e.type,
      };

  IconData _icon(TrackingEvent e) => switch (e.type) {
        'offline' => Icons.signal_wifi_off,
        'online' => Icons.wifi,
        'gpsOff' => Icons.location_off,
        'gpsOn' => Icons.location_on,
        'onDuty' || 'offDuty' => Icons.schedule,
        'batteryOn' || 'batteryOff' => Icons.battery_alert,
        'notificationsOff' => Icons.notifications_off,
        'notificationsOn' => Icons.notifications_active,
        'quiet' => Icons.phonelink_off,
        'woken' || 'resumed' => Icons.phonelink_ring,
        'noAnswer' => Icons.report_problem_outlined,
        _ => Icons.lock_outline,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = DateFormat.Hm(Localizations.localeOf(context).toString());
    final entries = trackingLog(ref.watch(trackingEventsProvider((userId, day))).value ?? const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(l10n.trackingLog, style: theme.textTheme.titleSmall),
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(l10n.trackingLogEmpty, style: theme.textTheme.bodySmall),
          ),
        for (final (:event, :lasted) in entries)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(_icon(event), color: event.isProblem ? theme.colorScheme.error : theme.colorScheme.primary),
            title: Text(_label(l10n, event)),
            subtitle: lasted == null ? null : Text(l10n.logLasted(formatLasted(l10n, lasted))),
            trailing: Text(time.format(event.at), style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}
