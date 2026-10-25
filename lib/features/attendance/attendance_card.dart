import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_user.dart';
import '../../core/location.dart';
import '../../core/location_disclosure.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notifications.dart' show directManagersOf;
import '../users/users_repository.dart';
import '../tracking/device_health.dart';
import '../tracking/tracking_card.dart' show PhoneHealthTips, makerSetupText;
import '../tracking/work_hours.dart';
import '../visits/visit.dart' show formatDistance;
import 'absence.dart';
import 'absence_sheet.dart';
import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'early_checkout.dart';
import 'geofences.dart';
import 'identity_check.dart';
import 'work_sites.dart';

String checkOutTypeLabel(AppLocalizations l10n, String? type) => switch (type) {
  'left' => l10n.checkOutLeft,
  'manual' => l10n.checkOutManual,
  'leftSite' => l10n.checkOutLeftSite,
  'leftEarly' => l10n.checkOutLeftEarly,
  'endOfDay' => l10n.checkOutEndOfDay,
  'auto' => l10n.checkOutAuto,
  'hr' => l10n.checkOutHr,
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
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      ref.invalidate(phoneHealthProvider);
    }
  }

  Future<void> _checkPermission() async {
    if (!geofencesSupported) return;
    final ok = await hasAlwaysLocation();
    if (!mounted) return;
    if (ok && _always == false) {
      await refreshAttendanceGeofences(_mySites());
    } else if (ok) {
      await ensureAttendanceGeofences(_mySites());
    }
    setState(() => _always = ok);
    await _askBackgroundOnce();
  }

  /// Asked once per app start (2026-10-21): Android's pop-up that lets the
  /// app run in the background, so arrivals wake it. The tracking card asks
  /// tracked staff itself.
  static bool _askedBackground = false;

  Future<void> _askBackgroundOnce() async {
    if (_askedBackground || widget.me.role.isLocationTracked || widget.me.workSiteIds.isEmpty) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _askedBackground = true;
    if (!await Permission.ignoreBatteryOptimizations.isGranted) await _allowBackground();
  }

  List<WorkSite> _mySites() => [
    for (final s in ref.read(workSitesProvider).value ?? const <WorkSite>[])
      if (s.active && widget.me.workSiteIds.contains(s.id)) s,
  ];

  Future<void> _allowAlways() async {
    // Google Play: say what location is for before Android asks.
    if (!await showLocationDisclosure(context, LocationUse.attendance)) return;
    // Android / iOS ask for "while in use" first, then "Always".
    var status = await Permission.locationWhenInUse.request();
    if (status.isGranted) status = await Permission.locationAlways.request();
    if (!status.isGranted) await openAppSettings();
    await _checkPermission();
  }

  /// What's missing for a check-in: GPS on, the location permission and
  /// "Allow all the time" (user decision 2026-10-20), and on Android what
  /// stops the phone from waking the app at the site (2026-10-21): battery
  /// optimization, battery use "Restricted" and the maker's Autostart /
  /// battery saver checklist.
  Future<List<_SetupNeed>> _missingSetup() async {
    final missing = <_SetupNeed>[];
    if (!await Geolocator.isLocationServiceEnabled()) missing.add(_SetupNeed.gps);
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      missing.add(_SetupNeed.permission);
    } else if (permission != LocationPermission.always) {
      missing.add(_SetupNeed.always);
    }
    ref.invalidate(phoneHealthProvider);
    final health = await ref.read(phoneHealthProvider.future).catchError((_) => null);
    if (health != null) {
      if (health.batteryOptimized) missing.add(_SetupNeed.battery);
      if (health.backgroundRestricted) missing.add(_SetupNeed.restricted);
      if (health.needsBrandSetup) missing.add(_SetupNeed.maker);
    }
    return missing;
  }

  Future<void> _fix(_SetupNeed need) async {
    switch (need) {
      case _SetupNeed.gps:
        await Geolocator.openLocationSettings();
      case _SetupNeed.permission:
        await _allowAlways();
      case _SetupNeed.always:
        await _allowAlways();
      case _SetupNeed.battery:
        await _allowBackground();
      case _SetupNeed.restricted:
        await openAppSettings();
      case _SetupNeed.maker:
        await openBackgroundSettings();
    }
  }

  /// Android's own "Let the app always run in the background?" pop-up.
  Future<void> _allowBackground() async {
    await Permission.ignoreBatteryOptimizations.request();
    ref.invalidate(phoneHealthProvider);
  }

  /// Lists what to turn on, each with a Fix button; nothing is recorded.
  Future<void> _showSetupNeeded(List<_SetupNeed> missing) {
    final l10n = AppLocalizations.of(context);
    final health = ref.read(phoneHealthProvider).value;
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: const Icon(Icons.location_off),
        title: Text(l10n.checkInNeedsLocation),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final need in missing)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (need) {
                    _SetupNeed.gps => l10n.checkInGpsOff,
                    _SetupNeed.permission => l10n.checkInNoPermission,
                    _SetupNeed.always => l10n.checkInNotAlways,
                    _SetupNeed.battery => l10n.checkInBatteryOptimized,
                    _SetupNeed.restricted => l10n.issueBackgroundRestricted,
                    _SetupNeed.maker => health?.autostart == false ? l10n.checkInAutostartOff : l10n.phoneSetupTitle,
                  }),
                  subtitle: need == _SetupNeed.maker && health != null ? Text(makerSetupText(l10n, health.brand)) : null,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.pop(dialog);
                          _fix(need);
                        },
                        child: Text(l10n.fix),
                      ),
                      // Separate from Autostart (user request 2026-10-21).
                      if (need == _SetupNeed.battery)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialog);
                            openBatterySettings();
                          },
                          child: Text(l10n.openBatterySaver),
                        ),
                      // Settings the phone can't report: the person confirms.
                      if (need == _SetupNeed.maker && health?.autostart == null)
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(dialog);
                            await markBrandSetupDone();
                            ref.invalidate(phoneHealthProvider);
                          },
                          child: Text(l10n.phoneSetupDone),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.cancel))],
      ),
    );
  }

  Future<void> _checkIn() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // No check-in until location and the background settings are right.
    final missing = await _missingSetup();
    if (missing.isNotEmpty) {
      if (mounted) await _showSetupNeeded(missing);
      return;
    }
    // Fingerprint / face / PIN when the phone has a screen lock (2026-10-22).
    if (!mounted) return;
    final verified = await confirmIdentity(context);
    if (verified == null || !mounted) return;
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
        messenger.showSnackBar(
          SnackBar(content: Text(nearest.isFinite ? l10n.notAtWorkSite(formatDistance(nearest)) : l10n.noWorkSiteAssigned)),
        );
        return;
      }
      await recordAttendance(widget.me.id, AttendanceEventType.checkIn, siteId: at.id, extra: {'verified': verified});
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
    if (ok != true || !mounted) return;
    final verified = await confirmIdentity(context);
    if (verified == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await recordAttendance(widget.me.id, AttendanceEventType.checkOut, extra: {'verified': verified});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Before the end of the work day: asks the direct manager(s) first.
  Future<void> _askEarly(List<String> approverIds, String names, String endTime) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.askLeaveEarly),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.askLeaveEarlyHelp(endTime, names)),
              const SizedBox(height: 12),
              TextFormField(
                controller: reason,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(labelText: l10n.absenceReasonField),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, true);
            },
            child: Text(l10n.sendRequest),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => reason.dispose());
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await askEarlyCheckout(me: widget.me, approverIds: approverIds, reason: text);
      messenger.showSnackBar(SnackBar(content: Text(l10n.earlyRequestSent(names))));
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
    if (!me.needsAttendance) return const SizedBox.shrink();
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
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final hours = me.scheduleOr(company);
    final sites = {for (final s in ref.watch(workSitesProvider).value ?? const <WorkSite>[]) s.id: s};
    final record = ref.watch(myAttendanceTodayProvider).value;
    final day = record?.best(me, company);
    final siteName = sites[day?.siteId]?.name ?? '';
    final health = ref.watch(phoneHealthProvider).value;
    // "Not coming to work" reported for today / tomorrow (2026-10-22).
    final now = DateTime.now();
    final absences = ref.watch(myAbsencesProvider).value ?? const <String, Absence>{};
    final checkedIn = day != null && day.checkedIn;
    final absentToday = checkedIn ? null : absences[attendanceDay(now)];
    final absentTomorrow = absences[attendanceDay(DateTime(now.year, now.month, now.day + 1))];
    // Leaving early (2026-10-23): before the end of the work day the direct
    // manager approves first. Users not loaded yet: the button waits.
    final open = day != null && day.checkedIn && !day.closed;
    final users = ref.watch(usersProvider).value;
    final byId = {for (final u in users ?? const <AppUser>[]) u.id: u};
    final approvers = users == null ? const <String>[] : directManagersOf(me, users);
    final approverNames = approvers.map((id) => byId[id]?.name ?? '').where((n) => n.isNotEmpty).join(', ');
    final early = open ? ref.watch(myEarlyCheckoutTodayProvider).value : null;
    final mustAsk = open && approvers.isNotEmpty && needsEarlyCheckoutApproval(now, hours) && !(early?.approved ?? false);
    final endTime = time.format(DateTime(now.year, now.month, now.day).add(Duration(minutes: hours.endMinute)));

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
      final end = DateTime(now.year, now.month, now.day).add(Duration(minutes: hours.endMinute));
      final capEnd = end.add(Duration(minutes: me.overtimeAllowed ? me.overtimeCapMin : 0));
      final upTo = now.isBefore(capEnd) ? now : capEnd;
      final so = upTo.difference(day.checkInAt!) - Duration(minutes: day.awayMin ?? 0);
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
        if ((day.afterHoursMin ?? 0) > 0) l10n.stayedAfterTime(formatMinutes(day.afterHoursMin!)),
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
            if (absentToday != null)
              AbsenceNotice(absence: absentToday, today: true)
            else
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color),
                ),
                title: Text(title, style: theme.textTheme.titleMedium),
                subtitle: detail.isEmpty ? null : Text(detail),
              ),
            if (absentTomorrow != null) AbsenceNotice(absence: absentTomorrow, today: false),
            if (early != null)
              ListTile(
                dense: true,
                leading: Icon(
                  early.pending ? Icons.hourglass_top : early.approved ? Icons.check_circle : Icons.cancel,
                  color: early.pending
                      ? Colors.orange.shade800
                      : early.approved
                      ? Colors.green.shade700
                      : theme.colorScheme.error,
                ),
                title: Text(early.pending
                    ? l10n.earlyWaiting(approverNames)
                    : early.approved
                    ? l10n.earlyApproved(byId[early.decidedBy]?.name ?? '')
                    : l10n.earlyRejected(byId[early.decidedBy]?.name ?? '')),
                subtitle: Text([early.reason, if (early.comment.isNotEmpty) '“${early.comment}”'].join('\n')),
                trailing: early.pending
                    ? TextButton(
                        onPressed: _busy ? null : () => cancelEarlyCheckout(early),
                        child: Text(l10n.cancelRequest),
                      )
                    : null,
              ),
            if (_always == false)
              ListTile(
                dense: true,
                leading: Icon(Icons.location_off, color: theme.colorScheme.error),
                title: Text(l10n.allowAlwaysForAttendance),
                trailing: TextButton(onPressed: _allowAlways, child: Text(l10n.allow)),
              ),
            if (!me.role.isLocationTracked && (health?.batteryOptimized ?? false))
              ListTile(
                dense: true,
                leading: Icon(Icons.battery_alert, color: theme.colorScheme.error),
                title: Text(l10n.allowBackgroundForAttendance),
                subtitle: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonal(onPressed: _allowBackground, child: Text(l10n.allow)),
                    OutlinedButton(onPressed: openBatterySettings, child: Text(l10n.openBatterySaver)),
                  ],
                ),
              ),
            // Battery / autostart settings that keep the phone from waking the
            // app at the site (the tracking card shows them to tracked staff).
            if (!me.role.isLocationTracked && PhoneHealthTips.needed(health))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PhoneHealthTips(health: health!),
              ),
            if (absentToday == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: widget.prominent ? Alignment.center : AlignmentDirectional.centerEnd,
                  widthFactor: widget.prominent ? null : 1,
                  child: open && mustAsk
                      ? OutlinedButton.icon(
                          style: widget.prominent ? OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)) : null,
                          // Waiting for an answer: nothing to press yet.
                          onPressed: _busy || (early?.pending ?? false)
                              ? null
                              : () => _askEarly(approvers, approverNames, endTime),
                          icon: const Icon(Icons.directions_walk),
                          label: Text(early != null && !early.pending ? l10n.earlyAskAgain : l10n.askLeaveEarly),
                        )
                      : open
                      ? OutlinedButton.icon(
                          style: widget.prominent ? OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)) : null,
                          onPressed: _busy || users == null ? null : _checkOut,
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
            // Report an absence: today (until they check in) or tomorrow.
            if ((absentToday == null && !checkedIn) || absentTomorrow == null)
              Align(
                alignment: widget.prominent ? Alignment.center : AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton.icon(
                    onPressed: () => showAbsenceSheet(
                      context,
                      me,
                      todayOpen: absentToday == null && !checkedIn,
                      tomorrowOpen: absentTomorrow == null,
                    ),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text(l10n.absenceButton),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _SetupNeed { gps, permission, always, battery, restricted, maker }
