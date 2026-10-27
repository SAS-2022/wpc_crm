import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_user.dart';
import '../../core/saving.dart';
import '../../l10n/app_localizations.dart';
import '../users/users_repository.dart';
import 'vehicle.dart';
import 'vehicle_widgets.dart';
import 'vehicles_repository.dart';

/// More → Vehicles (user request 2026-10-24; sales manager, GM, logistics
/// manager): the company's vehicles with their renewals, drivers and
/// mileage. Vehicles needing a renewal come first.
class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  bool _dueOnly = false;
  bool _showInactive = false;
  bool _refreshed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    final all = ref.watch(vehiclesProvider).value;
    final users = {for (final u in ref.watch(usersProvider).value ?? const <AppUser>[]) u.id: u};
    final vehicles = all ?? const <Vehicle>[];
    final from = firstKmDay(vehicles);
    final km = from == null ? const <DriverDayKm>[] : ref.watch(driverKmProvider(from)).value ?? const <DriverDayKm>[];
    // Once per visit: today's km and any missing day of every vehicle's drivers.
    if (!_refreshed && all != null) {
      _refreshed = true;
      refreshDriverKm({for (final v in vehicles) ...v.driverIds}.toList(), from);
    }
    final mileage = {for (final v in vehicles) v.id: vehicleMileage(v, km)};
    bool needs(Vehicle v) => vehicleNeedsAttention(v, today, mileage[v.id]!.estimate);
    final due = vehicles.where(needs).length;
    final inactive = vehicles.where((v) => !v.active).length;
    final shown = [
      for (final v in vehicles)
        if ((v.active || _showInactive) && (!_dueOnly || needs(v))) v,
    ]..sort((a, b) {
        // Active first, then expired / oil due, then due soon, then by plate.
        int rank(Vehicle v) {
          if (!v.active) return 3;
          final oil = v.oil(mileage[v.id]!.estimate);
          final worst = v.worstState(today);
          if (worst == RenewalState.expired || oil == OilState.due) return 0;
          if (worst == RenewalState.dueSoon || oil == OilState.dueSoon) return 1;
          return 2;
        }
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.plate.compareTo(b.plate);
      });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehicles)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicles/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addVehicle),
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : vehicles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noVehicles, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                if (due > 0 || inactive > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (due > 0)
                          FilterChip(
                            avatar: Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                            label: Text(l10n.needsRenewalFilter(due)),
                            selected: _dueOnly,
                            onSelected: (v) => setState(() => _dueOnly = v),
                          ),
                        if (inactive > 0)
                          FilterChip(
                            label: Text('${l10n.showInactiveVehicles} ($inactive)'),
                            selected: _showInactive,
                            onSelected: (v) => setState(() => _showInactive = v),
                          ),
                      ],
                    ),
                  ),
                for (final v in shown) _VehicleCard(vehicle: v, users: users, mileage: mileage[v.id]!, today: today),
              ],
            ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.users, required this.mileage, required this.today});

  final Vehicle vehicle;
  final Map<String, AppUser> users;
  final VehicleMileage mileage;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final v = vehicle;
    final drivers = [for (final id in v.driverIds) users[id]?.name ?? '?'];
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vehicles/${v.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_car_outlined, color: v.active ? theme.colorScheme.primary : theme.disabledColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.plate, style: theme.textTheme.titleMedium),
                        Text(
                          [
                            if (v.title.isNotEmpty) v.title,
                            drivers.isEmpty ? l10n.noDriverAssigned : drivers.join(', '),
                            if (!v.active) l10n.inactive,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (mileage.estimate != null)
                    Text(l10n.odometerEstimate(formatKm(context, mileage.estimate!)), style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in Renewal.values) RenewalChip(vehicle: v, item: r, today: today),
                  if (v.oilIntervalKm != null) OilChip(vehicle: v, estimate: mileage.estimate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One vehicle: renewals (renew / change the date), mileage (estimate,
/// readings), drivers and renewal history.
class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  bool _refreshed = false;

  Future<String?> _pickDay(String? initial, {DateTime? last}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(initial ?? '') ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: last ?? DateTime(now.year + 10),
    );
    return picked == null ? null : vehicleDay(picked);
  }

  Future<void> _recordReading(Vehicle v, VehicleMileage m) async {
    final l10n = AppLocalizations.of(context);
    final r = await showKmDayDialog(context, title: l10n.recordReading, initialKm: m.estimate);
    if (r == null || !mounted) return;
    final (km: value, :day, note: text) = r;
    // A reading lower than one taken before it is probably a typo.
    final before = [for (final r in v.readings) if (r.day.compareTo(day) <= 0) r];
    if (before.isNotEmpty && value < before.last.km) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(l10n.readingLower(formatKm(context, before.last.km))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
          ],
        ),
      );
      if (sure != true) return;
    }
    await addOdometerReading(v.id, km: value, day: day, note: text);
  }

  Future<void> _changeDrivers(Vehicle v, List<AppUser> users, List<Vehicle> all) async {
    final l10n = AppLocalizations.of(context);
    final drivers = [
      for (final u in users)
        if (u.role == UserRole.driver && (u.active || v.driverIds.contains(u.id))) u,
    ];
    final vehicleOf = {
      for (final o in all)
        if (o.id != v.id)
          for (final id in o.driverIds) id: o.plate,
    };
    var picked = {...v.driverIds};
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => AlertDialog(
          title: Text(l10n.changeDrivers),
          content: drivers.isEmpty
              ? Text(l10n.noDriverUsers)
              : SizedBox(
                  width: 360,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final u in drivers)
                        CheckboxListTile(
                          value: picked.contains(u.id),
                          title: Text(u.name),
                          subtitle: vehicleOf[u.id] == null ? null : Text(l10n.driverOnOtherVehicle(vehicleOf[u.id]!)),
                          onChanged: (on) => setDialog(() => picked = on == true ? {...picked, u.id} : ({...picked}..remove(u.id))),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
            if (drivers.isNotEmpty) FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
          ],
        ),
      ),
    );
    if (ok == true) await setVehicleDrivers(v, picked, all);
  }

  Future<void> _delete(Vehicle v) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(l10n.deleteVehicleConfirm(v.plate)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    router.pop();
    await deleteVehicle(v.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final loaded = ref.watch(vehiclesProvider).hasValue;
    final v = ref.watch(vehicleProvider(widget.id));
    if (v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: loaded ? const SizedBox.shrink() : const Center(child: CircularProgressIndicator()),
      );
    }
    final all = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final userList = ref.watch(usersProvider).value ?? const <AppUser>[];
    final users = {for (final u in userList) u.id: u};
    final from = firstKmDay([v]);
    final km = from == null ? const <DriverDayKm>[] : ref.watch(driverKmProvider(from)).value ?? const <DriverDayKm>[];
    final mileage = vehicleMileage(v, km);
    if (!_refreshed) {
      _refreshed = true;
      refreshDriverKm(v.driverIds, from);
    }
    final today = DateTime.now();
    final last = v.lastReading;
    Widget section(String title, List<Widget> children, {Widget? action}) => Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                      ?action,
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(v.plate),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.editVehicle,
            onPressed: () => context.push('/vehicles/${v.id}/edit'),
          ),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: l10n.delete, onPressed: () => _delete(v)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (v.title.isNotEmpty || v.color.isNotEmpty || v.vin.isNotEmpty || v.notes.isNotEmpty || !v.active)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: ListTile(
                leading: Icon(Icons.directions_car_outlined, color: v.active ? theme.colorScheme.primary : theme.disabledColor),
                title: Text([if (v.title.isNotEmpty) v.title, if (v.color.isNotEmpty) v.color].join(' · ')),
                subtitle: Text(
                  [
                    if (v.vin.isNotEmpty) '${l10n.vehicleVin}: ${v.vin}',
                    if (v.notes.isNotEmpty) v.notes,
                    if (!v.active) l10n.inactive,
                  ].join('\n'),
                ),
              ),
            ),
          section(l10n.renewals, [
            for (final r in Renewal.values)
              ListTile(
                leading: Icon(renewalIcon(r), color: renewalColor(context, v.state(r, today))),
                title: Text(renewalLabel(l10n, r)),
                subtitle: Text(
                  [
                    // "Until <date>" already names the date.
                    if (v.expiries[r] != null && v.state(r, today) != RenewalState.ok) formatVehicleDay(context, v.expiries[r]!),
                    renewalStatusText(context, v.expiries[r], today),
                  ].join(' · '),
                  style: TextStyle(color: renewalColor(context, v.state(r, today))),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (v.expiries[r] != null)
                      FilledButton.tonal(onPressed: () => renewVehicle(context, v, r), child: Text(l10n.markRenewed)),
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'clear') {
                          await setRenewal(v, r, null, renewed: false);
                          return;
                        }
                        final picked = await _pickDay(v.expiries[r]);
                        if (picked != null) await setRenewal(v, r, picked, renewed: false);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'date', child: Text(v.expiries[r] == null ? l10n.setDate : l10n.changeDate)),
                        if (v.expiries[r] != null) PopupMenuItem(value: 'clear', child: Text(l10n.clear)),
                      ],
                    ),
                  ],
                ),
              ),
          ]),
          section(
            l10n.mileage,
            [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mileage.estimate != null)
                      Text(l10n.odometerEstimate(formatKm(context, mileage.estimate!)), style: theme.textTheme.headlineSmall),
                    if (last != null)
                      Text(l10n.lastReading(formatKm(context, last.km), formatVehicleDay(context, last.day)))
                    else
                      Text(l10n.noReadingYet, style: TextStyle(color: theme.colorScheme.error)),
                    if (v.driverLog.isNotEmpty)
                      Text(last == null
                          ? l10n.gpsKmNoReading(formatKm(context, mileage.gpsKm))
                          : l10n.gpsKmSince(formatKm(context, mileage.gpsKm))),
                    for (final e in mileage.byDriver.entries)
                      if (mileage.byDriver.length > 1 || !v.driverIds.contains(e.key))
                        Text('  • ${users[e.key]?.name ?? '?'}: ${l10n.kmValue(formatKm(context, e.value))}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(l10n.gpsKmHelp, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (v.readings.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(l10n.readings, style: theme.textTheme.titleSmall),
                ),
                for (final r in v.readings.reversed)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.speed),
                    title: Text(l10n.kmValue(formatKm(context, r.km))),
                    subtitle: Text([formatVehicleDay(context, r.day), users[r.byId]?.name ?? '', r.note].where((s) => s.isNotEmpty).join(' · ')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.delete,
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                            content: Text(l10n.deleteReadingConfirm(formatKm(context, r.km))),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
                              FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
                            ],
                          ),
                        );
                        if (ok == true) await deleteOdometerReading(v, r.id);
                      },
                    ),
                  ),
              ],
            ],
            action: FilledButton.tonalIcon(
              icon: const Icon(Icons.speed),
              label: Text(l10n.recordReading),
              onPressed: () => _recordReading(v, mileage),
            ),
          ),
          section(
            l10n.oilChange,
            [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v.oilIntervalKm == null)
                      Text(l10n.oilNotTracked, style: theme.textTheme.bodySmall)
                    else ...[
                      Text(
                        oilStatusText(context, v, mileage.estimate),
                        style: theme.textTheme.titleMedium?.copyWith(color: oilColor(context, v.oil(mileage.estimate))),
                      ),
                      Text([
                        l10n.oilEvery(formatKm(context, v.oilIntervalKm!)),
                        if (v.nextOilKm != null) l10n.oilNextAt(formatKm(context, v.nextOilKm!)),
                      ].join(' · ')),
                      if (v.lastOilChange case final c?)
                        Text(l10n.oilLastChange(formatKm(context, c.km), formatVehicleDay(context, c.day)), style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              for (final c in v.oilLog.reversed)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.oil_barrel_outlined),
                  title: Text(l10n.kmValue(formatKm(context, c.km))),
                  subtitle: Text([formatVehicleDay(context, c.day), users[c.byId]?.name ?? '', c.note].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.delete,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          content: Text(l10n.deleteOilChangeConfirm(formatKm(context, c.km))),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
                            FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.delete)),
                          ],
                        ),
                      );
                      if (ok == true) await deleteOilChange(v, c.id);
                    },
                  ),
                ),
            ],
            action: v.oilIntervalKm == null
                ? TextButton(onPressed: () => context.push('/vehicles/${v.id}/edit'), child: Text(l10n.setOilInterval))
                : FilledButton.tonalIcon(
                    icon: const Icon(Icons.oil_barrel_outlined),
                    label: Text(l10n.recordOilChange),
                    onPressed: () => recordOilChange(context, v, mileage.estimate),
                  ),
          ),
          section(
            l10n.drivers,
            [
              if (v.driverIds.isEmpty)
                ListTile(title: Text(l10n.noDriverAssigned))
              else
                for (final id in v.driverIds)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(users[id]?.name ?? '?'),
                    subtitle: users[id]?.active == false ? Text(l10n.inactive) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.route),
                      tooltip: l10n.routeHistory,
                      onPressed: () => context.push('/history?uid=$id'),
                    ),
                  ),
            ],
            action: TextButton.icon(
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(l10n.changeDrivers),
              onPressed: () => _changeDrivers(v, userList, all),
            ),
          ),
          if (v.renewalLog.isNotEmpty)
            section(l10n.renewalHistory, [
              for (final e in v.renewalLog)
                ListTile(
                  dense: true,
                  leading: Icon(renewalIcon(e.item)),
                  title: Text(l10n.renewalHistoryRow(renewalLabel(l10n, e.item), formatVehicleDay(context, e.expiry))),
                  subtitle: Text([
                    if (e.at != null) formatVehicleDay(context, vehicleDay(e.at!)),
                    users[e.byId]?.name ?? '',
                  ].where((s) => s.isNotEmpty).join(' · ')),
                ),
            ]),
        ],
      ),
    );
  }
}

/// Add / edit a vehicle's details; a new one also takes its renewal dates
/// and the odometer now.
class VehicleEditScreen extends ConsumerStatefulWidget {
  const VehicleEditScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends ConsumerState<VehicleEditScreen> {
  final _plate = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _vin = TextEditingController();
  final _notes = TextEditingController();
  final _km = TextEditingController();
  final _oilInterval = TextEditingController();
  final _lastOilKm = TextEditingController();
  String? _lastOilDay;
  bool _active = true;
  final Map<Renewal, String?> _expiries = {};
  bool _filled = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_plate, _make, _model, _year, _color, _vin, _notes, _km, _oilInterval, _lastOilKm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Vehicle v) {
    _filled = true;
    _plate.text = v.plate;
    _make.text = v.make;
    _model.text = v.model;
    _year.text = v.year?.toString() ?? '';
    _color.text = v.color;
    _vin.text = v.vin;
    _notes.text = v.notes;
    _oilInterval.text = v.oilIntervalKm?.toString() ?? '';
    _lastOilKm.text = v.lastOilChange?.km.toString() ?? '';
    _lastOilDay = v.lastOilChange?.day;
    _active = v.active;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (_plate.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.vehiclePlateRequired)));
      return;
    }
    setState(() => _busy = true);
    try {
      final km = int.tryParse(_km.text.trim());
      final id = await saveVehicle(
        id: widget.id,
        plate: _plate.text.trim(),
        make: _make.text.trim(),
        model: _model.text.trim(),
        year: int.tryParse(_year.text.trim()),
        color: _color.text.trim(),
        vin: _vin.text.trim(),
        notes: _notes.text.trim(),
        active: _active,
        expiries: widget.id == null ? _expiries : const {},
        firstKm: widget.id == null ? km : null,
        oilIntervalKm: switch (int.tryParse(_oilInterval.text.trim())) { final n? when n > 0 => n, _ => null },
      );
      // "Last oil change" (2026-10-26): a new or changed one is recorded
      // like "Oil changed" (also an odometer reading).
      final oilKm = int.tryParse(_lastOilKm.text.trim());
      final last = widget.id == null ? null : ref.read(vehicleProvider(widget.id!))?.lastOilChange;
      final oilDay = _lastOilDay ?? vehicleDay(DateTime.now());
      if (oilKm != null && (last == null || last.km != oilKm || last.day != oilDay)) {
        // Not a reading when a reading of that day or later shows more
        // (e.g. "Odometer now" above): it would replace the newer number.
        final readings = widget.id == null
            ? [if (km != null) OdometerReading(id: '', km: km, day: vehicleDay(DateTime.now()))]
            : ref.read(vehicleProvider(widget.id!))?.readings ?? const <OdometerReading>[];
        final newer = readings.any((r) => r.day.compareTo(oilDay) >= 0 && r.km > oilKm);
        await addOilChange(id, km: oilKm, day: oilDay, asReading: !newer);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.saved)));
      widget.id == null ? router.pushReplacement('/vehicles/$id') : router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorWithMessage('$e'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = widget.id == null ? null : ref.watch(vehicleProvider(widget.id!));
    if (widget.id != null && v == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (v != null && !_filled) _fill(v);
    Widget field(TextEditingController c, String label, {TextInputType? keyboard, int maxLines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: keyboard,
            maxLines: maxLines,
            inputFormatters: keyboard == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(labelText: label),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(widget.id == null ? l10n.addVehicle : l10n.editVehicle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(_plate, l10n.vehiclePlate),
          field(_make, l10n.vehicleMake),
          field(_model, l10n.vehicleModel),
          field(_year, l10n.vehicleYear, keyboard: TextInputType.number),
          field(_color, l10n.vehicleColor),
          field(_vin, l10n.vehicleVin),
          field(_notes, l10n.notes, maxLines: 3),
          field(_oilInterval, l10n.oilIntervalKm, keyboard: TextInputType.number),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field(_lastOilKm, l10n.lastOilChangeKm, keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(formatVehicleDay(context, _lastOilDay ?? vehicleDay(DateTime.now()))),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(_lastOilDay ?? '') ?? now,
                      firstDate: DateTime(now.year - 10),
                      lastDate: now,
                      helpText: l10n.lastOilChangeDay,
                    );
                    if (picked != null) setState(() => _lastOilDay = vehicleDay(picked));
                  },
                ),
              ),
            ],
          ),
          if (widget.id == null) ...[
            field(_km, l10n.vehicleFirstReading, keyboard: TextInputType.number),
            Text(l10n.renewals, style: Theme.of(context).textTheme.titleSmall),
            for (final r in Renewal.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(renewalIcon(r)),
                title: Text(renewalLabel(l10n, r)),
                subtitle: Text(_expiries[r] == null ? l10n.renewalNotSet : formatVehicleDay(context, _expiries[r]!)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_expiries[r] ?? '') ?? now,
                    firstDate: DateTime(now.year - 10),
                    lastDate: DateTime(now.year + 10),
                    helpText: l10n.renewalExpiry,
                  );
                  if (picked != null) setState(() => _expiries[r] = vehicleDay(picked));
                },
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.active),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: BusyLabel(busy: _busy, child: Text(l10n.save))),
        ],
      ),
    );
  }
}
