import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_user.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../clients/person_style.dart' show initialsOf;
import '../settings/page_access.dart';
import '../tracking/live_data.dart';
import '../tracking/live_map_screen.dart' show timeAgo;
import '../tracking/tracking_schedule.dart';
import '../tracking/work_hours.dart';
import '../users/companies.dart';
import '../users/company_filter.dart';
import '../users/users_repository.dart';
import 'device_status.dart';
import '../../core/search_text.dart';

/// Phone status (user request 2026-11-01): a card per employee with their
/// phone's GPS, internet (Wi-Fi / mobile data) and permissions, problems in
/// red; the map button (top right) opens the live map.
class PhoneStatusScreen extends ConsumerStatefulWidget {
  const PhoneStatusScreen({super.key});

  @override
  ConsumerState<PhoneStatusScreen> createState() => _PhoneStatusScreenState();
}

class _PhoneStatusScreenState extends ConsumerState<PhoneStatusScreen> {
  String _search = '';
  bool _problemsOnly = false;

  /// Only phones with one of these turned off (user 2026-11-02): GPS,
  /// internet, battery optimization. Empty = no filter.
  final Set<PhoneCheck> _off = {};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keeps "5 min ago" current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider).value;
    if (me == null) return const SizedBox.shrink();
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final statuses = ref.watch(deviceStatusesProvider).value ?? const <String, DeviceStatus>{};
    final presence = ref.watch(presenceProvider).value ?? const <String, Presence>{};
    final live = ref.watch(liveLocationsProvider).value ?? const <String, LiveLocation>{};
    final company = ref.watch(workHoursProvider).value ?? WorkHours.defaults;
    final schedules = ref.watch(trackingSchedulesProvider).value ?? const <String, TrackingSchedule>{};
    final companies = ref.watch(companyNamesProvider);
    final companyId = ref.watch(peopleCompanyProvider);
    final access = ref.watch(pageAccessProvider).value ?? PageAccess.defaults;
    final now = DateTime.now();
    final q = foldSearch(_search);

    final everyone = phoneStatusPeople(me, users);
    // Office staff send no live position, only route points (last one of today).
    final recordedIds = [for (final u in everyone) if (u.recordsGps) u.id]..sort();
    final recorded = recordedIds.isEmpty
        ? const <String, LiveLocation>{}
        : ref.watch(recordedLocationsProvider((DateFormat('yyyy-MM-dd').format(now), recordedIds.join(',')))).value ??
            const <String, LiveLocation>{};
    final reports = {
      for (final u in everyone)
        u.id: phoneReport(
          device: statuses[u.id],
          presence: presence[u.id],
          liveAt: live[u.id]?.updatedAt,
          recordedAt: recorded[u.id]?.updatedAt,
          versions: u.appVersions,
          shouldShare: (u.role.isLocationTracked || u.recordsGps) &&
              (schedules[u.id] ?? const TrackingSchedule.standard()).isOn(
                now,
                company,
                driver: u.role.isDriver,
                recordOnly: u.recordsGps,
                days: u.workSchedule?.days,
              ),
          now: now,
        ),
    };
    final stoppedCount = reports.values.where((r) => r.stopped).length;
    bool hasProblem(AppUser u, Set<PhoneCheck> checks) {
      final st = reports[u.id]!.status;
      return st != null && checks.any((c) => st.state(c) == CheckState.problem);
    }

    final people = [
      for (final u in everyone)
        if ((companyId == null || u.companyId == companyId) &&
            searchHas(u.name, q) &&
            (!_problemsOnly || reports[u.id]!.problemCount > 0) &&
            (_off.isEmpty || hasProblem(u, _off)))
          u,
    ];
    // Stopped reporting first, then the most problems, then no phone, then all good.
    int rank(AppUser u) {
      final r = reports[u.id]!;
      if (r.stopped) return -1000;
      if (r.problemCount > 0) return -r.problemCount;
      return r.signal == PhoneSignal.noPhone ? 1000 : 1001;
    }

    people.sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.name.compareTo(b.name));

    // The map: the live map for KAM / managers, the drivers' map for the
    // logistics manager.
    final mapPath = me.role.isSupervisor && access.allowsUser(me, AppPage.liveTracking)
        ? '/live'
        : me.role.seesDrivers && access.allowsUser(me, AppPage.drivers)
            ? '/drivers'
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.phoneStatus),
        actions: [
          if (mapPath != null)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: l10n.phoneStatusShowMap,
              // The live map keeps this page's filters: the company is
              // shared, a search / "Problems only" passes the people shown.
              onPressed: () => context.push(
                q.isEmpty && !_problemsOnly && _off.isEmpty ? mapPath : '$mapPath?ids=${people.map((u) => u.id).join(',')}',
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.phoneStatusSearch,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.warning_amber, size: 16),
                label: Text(l10n.phoneStatusProblemsOnly),
                selected: _problemsOnly,
                onSelected: (v) => setState(() => _problemsOnly = v),
              ),
              for (final (check, icon, label) in [
                (PhoneCheck.gps, Icons.location_disabled, l10n.filterGpsOff),
                (PhoneCheck.network, Icons.wifi_off, l10n.filterNoInternet),
                (PhoneCheck.battery, Icons.battery_alert, l10n.filterBatteryOptimized),
              ])
                FilterChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(icon, size: 16),
                  label: Text('$label (${everyone.where((u) => (companyId == null || u.companyId == companyId) && hasProblem(u, {check})).length})'),
                  selected: _off.contains(check),
                  onSelected: (v) => setState(() => v ? _off.add(check) : _off.remove(check)),
                ),
              CompanyFilterButton(value: companyId, onChanged: ref.read(peopleCompanyProvider.notifier).set),
              if (stoppedCount > 0)
                Text(
                  l10n.phoneStatusStoppedCount(stoppedCount),
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.error),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.phoneStatusNote, style: theme.textTheme.bodySmall),
          ),
          if (people.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l10n.phoneStatusNoPeople)))
          else
            LayoutBuilder(builder: (context, c) {
              // About 280 px a card: one column on small phones, more on the web.
              final columns = (c.maxWidth / 280).floor().clamp(1, 6);
              final width = (c.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in people)
                    SizedBox(
                      width: width,
                      child: _PhoneCard(
                        user: u,
                        report: reports[u.id]!,
                        company: companies[u.companyId],
                        now: now,
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.user, required this.report, required this.company, required this.now});

  final AppUser user;
  final PhoneReport report;
  final String? company;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = report;
    final s = r.status;
    final problems = r.problemCount;
    final heard = r.lastHeard == null ? null : timeAgo(context, r.lastHeard, now);
    final headColor = r.signal == PhoneSignal.noPhone && problems == 0
        ? Colors.grey
        : problems > 0
            ? theme.colorScheme.error
            : r.signal == PhoneSignal.recent
                ? Colors.green.shade600
                : Colors.orange.shade800;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: headColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: headColor.withValues(alpha: 0.15),
                  child: Text(initialsOf(user.name), style: TextStyle(color: headColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        [user.role.label(l10n), ?company].join(' · '),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (s != null)
                  Icon(s.android ? Icons.android : Icons.phone_iphone, size: 18, color: theme.colorScheme.outline),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              switch (r.signal) {
                PhoneSignal.noPhone => l10n.phoneStatusNoPhone,
                PhoneSignal.stopped =>
                  heard == null ? l10n.phoneStatusStoppedNever : l10n.phoneStatusStopped(heard),
                PhoneSignal.recent || PhoneSignal.quiet => l10n.phoneStatusLastHeard(heard ?? '–'),
              },
              style: theme.textTheme.labelMedium?.copyWith(
                color: switch (r.signal) {
                  PhoneSignal.stopped => theme.colorScheme.error,
                  PhoneSignal.recent => Colors.green.shade700,
                  PhoneSignal.quiet => Colors.orange.shade800,
                  PhoneSignal.noPhone => theme.colorScheme.outline,
                },
                fontWeight: r.stopped ? FontWeight.bold : null,
              ),
            ),
            if (s != null)
              Text(
                s.problems.isNotEmpty ? l10n.phoneStatusProblems(s.problems.length) : l10n.phoneStatusAllGood,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: s.problems.isNotEmpty ? theme.colorScheme.error : Colors.green.shade700,
                ),
              ),
            if (s == null && user.appVersions.isNotEmpty)
              Text(
                l10n.phoneStatusApp(user.appVersions.values.map((v) => v.label).join(', ')),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            if (r.fromOldApp)
              Text(
                l10n.phoneStatusOldApp,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              )
            else if (s == null && r.signal != PhoneSignal.noPhone)
              Text(
                l10n.phoneStatusNoReport,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            if (s != null) ...[
              const Divider(height: 16),
              for (final check in s.checks)
                // Older builds report only what the tracker sends.
                if (!r.fromOldApp || s.state(check) != CheckState.unknown) PhoneCheckRow(status: s, check: check),
              if (s.app != null || s.phoneLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [if (s.app != null) l10n.phoneStatusApp(s.app!), ?s.phoneLabel].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One check of a phone (GPS, location, internet, …) with its value; also
/// on the employees map's person details.
class PhoneCheckRow extends StatelessWidget {
  const PhoneCheckRow({super.key, required this.status, required this.check});

  final DeviceStatus status;
  final PhoneCheck check;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = status;
    final state = s.state(check);
    final color = switch (state) {
      CheckState.ok => Colors.green.shade700,
      // The camera is only needed for photos: amber, not red.
      CheckState.problem => check == PhoneCheck.camera ? Colors.orange.shade800 : theme.colorScheme.error,
      CheckState.unknown => theme.colorScheme.outline,
    };
    String onOff(bool? v) => v == null ? l10n.valueNotReported : (v ? l10n.valueOn : l10n.valueOff);
    String allowed(bool? v) => v == null ? l10n.valueNotReported : (v ? l10n.valueAllowed : l10n.valueNotAllowed);
    final net = s.network;
    final (IconData icon, String label, String value) = switch (check) {
      PhoneCheck.gps => (s.gps == false ? Icons.location_disabled : Icons.gps_fixed, l10n.checkGps, onOff(s.gps)),
      PhoneCheck.location => (
          Icons.location_on_outlined,
          l10n.checkLocation,
          switch (s.location) {
            null => l10n.valueNotReported,
            'always' => l10n.locationAlways,
            'whileInUse' => l10n.locationWhileInUse,
            _ => l10n.locationDenied,
          },
        ),
      PhoneCheck.precise => (
          Icons.my_location,
          l10n.checkPrecise,
          s.precise == null ? l10n.valueNotReported : (s.precise! ? l10n.precisePrecise : l10n.preciseApproximate),
        ),
      PhoneCheck.network => (
          net == null || net.isEmpty ? Icons.wifi_off : (net.contains('wifi') ? Icons.wifi : Icons.signal_cellular_alt),
          l10n.checkNetwork,
          net == null
              ? l10n.valueNotReported
              : net.isEmpty
                  ? l10n.networkNone
                  : [
                      for (final n in net)
                        switch (n) {
                          'wifi' => l10n.networkWifi,
                          'mobile' => l10n.networkMobile,
                          _ => l10n.networkOther,
                        },
                    ].join(' + '),
        ),
      PhoneCheck.notifications => (Icons.notifications_outlined, l10n.checkNotifications, allowed(s.notifications)),
      PhoneCheck.battery => (
          Icons.battery_charging_full,
          l10n.checkBattery,
          s.batteryOptimized == null
              ? l10n.valueNotReported
              : (s.batteryOptimized! ? l10n.batteryOptimizedValue : l10n.batteryUnrestricted),
        ),
      PhoneCheck.background => (
          Icons.layers_outlined,
          l10n.checkBackground,
          s.backgroundRestricted == true
              ? l10n.backgroundRestrictedValue
              : s.sleeping == true
                  ? l10n.backgroundSleeping
                  : state == CheckState.unknown
                      ? l10n.valueNotReported
                      : l10n.valueAllowed,
        ),
      PhoneCheck.camera => (Icons.photo_camera_outlined, l10n.checkCamera, allowed(s.camera)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
