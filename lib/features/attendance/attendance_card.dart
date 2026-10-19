import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_user.dart';
import '../../core/location.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/work_hours.dart';
import '../visits/visit.dart' show formatDistance;
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'geofences.dart';
import 'work_sites.dart';

String checkOutTypeLabel(AppLocalizations l10n, String? type) => switch (type) {
      'left' => l10n.checkOutLeft,
      'manual' => l10n.checkOutManual,
      'leftEarly' => l10n.checkOutLeftEarly,
      'endOfDay' => l10n.checkOutEndOfDay,
      'auto' => l10n.checkOutAuto,
      _ => '',
    };

/// Home: today's attendance for people assigned to a work site — status,
/// "Check in" (must be at the site) / "Check out", and the "Always"
/// location permission automatic check-in needs.
class AttendanceCard extends ConsumerStatefulWidget {
  const AttendanceCard({super.key, required this.me, this.prominent = false});

  final AppUser me;

  /// Attendance-only roles' Home: shown even without a work site (with a
  /// note), with a large button.
  final bool prominent;

  @override
  ConsumerState<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends ConsumerState<AttendanceCard> with WidgetsBindingObserver {
  bool _busy = false;
  bool? _always;

  /// Keeps "checked in for …" current.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the phone's settings: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    if (!geofencesSupported) return;
    final ok = await hasAlwaysLocation();
    if (!mounted) return;
    if (ok && _always == false) await refreshAttendanceGeofences(_mySites());
    setState(() => _always = ok);
  }

  List<WorkSite> _mySites() => [
        for (final s in ref.read(workSitesProvider).value ?? const <WorkSite>[])
          if (s.active && widget.me.workSiteIds.contains(s.id)) s,
      ];

  Future<void> _allowAlways() async {
    // Android / iOS ask for "while in use" first, then "Always".
    var status = await Permission.locationWhenInUse.request();
    if (status.isGranted) status = await Permission.locationAlways.request();
    if (!status.isGranted) await openAppSettings();
    await _checkPermission();
  }

  Future<void> _checkIn() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final fix = await currentPosition();
      final p = fix.position;
      if (p == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.locationUnavailable)));
        return;
      }
      // The nearest of their sites, inside its radius (plus a little for GPS error).
      WorkSite? at;
      var nearest = double.infinity;
      for (final s in _mySites()) {
        final d = Geolocator.distanceBetween(p.latitude, p.longitude, s.lat, s.lng);
        if (d < nearest) nearest = d;
        if (d <= s.radius + p.accuracy.clamp(0, 50)) at = s;
      }
      if (at == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(nearest.isFinite ? l10n.notAtWorkSite(formatDistance(nearest)) : l10n.noWorkSiteAssigned),
        ));
        return;
      }
      await recordAttendance(widget.me.id, AttendanceEventType.checkIn, siteId: at.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.checkedInAt(at.name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOut() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.checkOutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.checkOut)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await recordAttendance(widget.me.id, AttendanceEventType.checkOut);
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
    final me = widget.me;
    if (me.workSiteIds.isEmpty) {
      if (!widget.prominent) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(Icons.info_outline, color: theme.colorScheme.outline),
          title: Text(l10n.notCheckedIn),
          subtitle: Text(l10n.noWorkSiteYet),
        ),
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale);
    final hours = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final sites = {for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[]) s.id: s};
    final record = ref.watch(myAttendanceTodayProvider).value;
    final day = record?.result(hours: hours, leavesSite: me.role.leavesSiteForWork, overtimeAllowed: me.overtimeAllowed);
    final siteName = sites[day?.siteId]?.name ?? '';

    final String title;
    final String detail;
    final IconData icon;
    final Color color;
    if (day == null || !day.checkedIn) {
      title = l10n.notCheckedIn;
      detail = l10n.autoCheckInHelp;
      icon = Icons.login;
      color = theme.colorScheme.outline;
    } else if (!day.closed) {
      title = l10n.checkedInSince(time.format(day.checkInAt!), siteName);
      // Hours so far today (without overtime when it isn't allowed).
      final now = DateTime.now();
      final end = DateTime(now.year, now.month, now.day).add(Duration(minutes: hours.endMinute));
      final upTo = me.overtimeAllowed || now.isBefore(end) ? now : end;
      final so = upTo.difference(day.checkInAt!);
      detail = [
        l10n.checkedInFor(formatMinutes(so.isNegative ? 0 : so.inMinutes)),
        day.inside || day.lastExitAt == null ? l10n.atTheSite : l10n.leftSiteAt(time.format(day.lastExitAt!)),
      ].join(' · ');
      icon = Icons.how_to_reg;
      color = Colors.green.shade700;
    } else {
      title = l10n.checkedOutAt(time.format(day.checkOutAt!));
      detail = [
        checkOutTypeLabel(l10n, day.checkOutType),
        l10n.workedTime(formatMinutes(day.countedMin ?? 0)),
        if ((day.overtimeMin ?? 0) > 0) l10n.overtimeTime(formatMinutes(day.overtimeMin!)),
      ].where((s) => s.isNotEmpty).join(' · ');
      icon = Icons.logout;
      color = theme.colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.14), child: Icon(icon, color: color)),
              title: Text(title, style: theme.textTheme.titleMedium),
              subtitle: detail.isEmpty ? null : Text(detail),
            ),
            if (_always == false)
              ListTile(
                dense: true,
                leading: Icon(Icons.location_off, color: theme.colorScheme.error),
                title: Text(l10n.allowAlwaysForAttendance),
                trailing: TextButton(onPressed: _allowAlways, child: Text(l10n.allow)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: widget.prominent ? Alignment.center : AlignmentDirectional.centerEnd,
                widthFactor: widget.prominent ? null : 1,
                child: day != null && day.checkedIn && !day.closed
                    ? OutlinedButton.icon(
                        style: widget.prominent ? OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)) : null,
                        onPressed: _busy ? null : _checkOut,
                        icon: const Icon(Icons.logout),
                        label: Text(l10n.checkOut),
                      )
                    : FilledButton.icon(
                        style: widget.prominent ? FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)) : null,
                        onPressed: _busy || !geofencesSupported ? null : _checkIn,
                        icon: _busy
                            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.login),
                        label: Text(day != null && day.closed ? l10n.checkInAgain : l10n.checkIn),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
