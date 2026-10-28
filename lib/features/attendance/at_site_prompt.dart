import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../tracking/work_hours.dart';
import 'absence.dart';
import 'attendance_repository.dart';
import 'geofences.dart' show geofencesSupported;
import 'work_sites.dart';

/// Set by the "You're at the work site" pop-up: the Home attendance card
/// runs its Check in (setup checks, fingerprint, GPS) when it sees it.
final checkInRequested = ValueNotifier<bool>(false);

/// The site [p] is at among [sites] (same distance rule as the Check in
/// button: radius + the fix accuracy, up to 50 m), or null.
WorkSite? siteAt(Position p, List<WorkSite> sites) {
  for (final s in sites) {
    if (Geolocator.distanceBetween(p.latitude, p.longitude, s.lat, s.lng) <= s.radius + p.accuracy.clamp(0, 50)) {
      return s;
    }
  }
  return null;
}

/// "You're at the work site – check in" pop-up (2026-10-28, user request
/// after Driver Number Two's 27 Oct: at the site from 08:42, the geofence
/// never fired, checked in by hand at 09:22). When the app is in front
/// (opened, resumed, and every 5 min while open) and the person needs
/// attendance, isn't checked in and it's their work day (2 h before the
/// start until the end; not reported absent), one GPS fix — only with the
/// location permission already given — tells whether they're at one of their
/// sites; then the pop-up asks them to check in. "Later" = not again for
/// 30 min. Phones only. Tracked people also get the server's push
/// (`atSiteReminders`).
class AtSitePromptGate extends ConsumerStatefulWidget {
  const AtSitePromptGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AtSitePromptGate> createState() => _AtSitePromptGateState();
}

class _AtSitePromptGateState extends ConsumerState<AtSitePromptGate> with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;
  DateTime? _quietUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
    // After the first frame and once the day's record has had a moment to load.
    Future.delayed(const Duration(seconds: 3), _check);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Future.delayed(const Duration(seconds: 2), _check);
  }

  Future<void> _check() async {
    if (kIsWeb || !geofencesSupported || _busy || !mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    if (_quietUntil != null && now.isBefore(_quietUntil!)) return;
    final me = ref.read(currentUserProvider).value;
    if (me == null || !me.checksAttendance) return;
    final today = ref.read(myAttendanceTodayProvider);
    if (!today.hasValue) return;
    final company = ref.read(workHoursProvider).value ?? WorkHours.defaults;
    if (today.value?.best(me, company).checkedIn ?? false) return;
    final hours = me.scheduleOr(company);
    final minute = now.hour * 60 + now.minute;
    if (!hours.days.contains(now.weekday) || minute < hours.startMinute - 120 || minute >= hours.endMinute) return;
    if (ref.read(myAbsencesProvider).value?[attendanceDay(now)] != null) return;
    final sites = [
      for (final s in ref.read(workSitesProvider).value ?? const <WorkSite>[])
        if (s.active && me.workSiteIds.contains(s.id)) s,
    ];
    if (sites.isEmpty) return;
    _busy = true;
    try {
      // Never asks for a permission here: only a fix the phone may already take.
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      final site = siteAt(p, sites);
      if (site == null || !mounted) return;
      // Checked in meanwhile (e.g. the geofence fired while the fix was taken).
      if (ref.read(myAttendanceTodayProvider).value?.best(me, company).checkedIn ?? false) return;
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
      await _ask(me, site);
    } catch (_) {
      // No fix: ask another time.
    } finally {
      _busy = false;
    }
  }

  Future<void> _ask(AppUser me, WorkSite site) async {
    final l10n = AppLocalizations.of(context);
    final checkIn = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 40),
        title: Text(l10n.atSiteNotCheckedInTitle),
        content: Text(l10n.atSiteNotCheckedIn(site.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.later)),
          FilledButton.icon(
            icon: const Icon(Icons.login),
            label: Text(l10n.checkIn),
            onPressed: () => Navigator.pop(dialog, true),
          ),
        ],
      ),
    );
    _quietUntil = DateTime.now().add(const Duration(minutes: 30));
    if (checkIn != true || !mounted) return;
    context.go('/');
    checkInRequested.value = true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
