import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/page_access.dart';
import 'vehicle.dart';
import 'vehicles_repository.dart';

String renewalLabel(AppLocalizations l10n, Renewal r) => switch (r) {
      Renewal.registration => l10n.renewalRegistration,
      Renewal.insurance => l10n.renewalInsurance,
      Renewal.inspection => l10n.renewalInspection,
      Renewal.operatingCard => l10n.renewalOperatingCard,
    };

IconData renewalIcon(Renewal r) => switch (r) {
      Renewal.registration => Icons.badge_outlined,
      Renewal.insurance => Icons.verified_user_outlined,
      Renewal.inspection => Icons.fact_check_outlined,
      Renewal.operatingCard => Icons.work_outline,
    };

Color renewalColor(BuildContext context, RenewalState s) => switch (s) {
      RenewalState.ok => Colors.green.shade700,
      RenewalState.dueSoon => Colors.orange.shade800,
      RenewalState.expired => Theme.of(context).colorScheme.error,
      RenewalState.missing => Theme.of(context).disabledColor,
    };

/// "12 days left" / "Expired 4 days ago" / "Until Mar 3, 2027" / "Not set".
String renewalStatusText(BuildContext context, String? expiry, DateTime today) {
  final l10n = AppLocalizations.of(context);
  final state = renewalState(expiry, today);
  if (state == RenewalState.missing) return l10n.renewalNotSet;
  final days = daysUntil(expiry!, today);
  if (state == RenewalState.ok) return l10n.renewalUntil(formatVehicleDay(context, expiry));
  if (days > 0) return l10n.renewalDaysLeft(days);
  return days == 0 ? l10n.renewalExpiresToday : l10n.renewalExpiredAgo(-days);
}

String formatVehicleDay(BuildContext context, String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);
}

String formatKm(BuildContext context, num km) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).toString()).format(km.round());

Color oilColor(BuildContext context, OilState s) => switch (s) {
      OilState.ok => Colors.green.shade700,
      OilState.dueSoon => Colors.orange.shade800,
      OilState.due => Theme.of(context).colorScheme.error,
      OilState.missing => Theme.of(context).disabledColor,
    };

/// "1,200 km left" / "Due – 300 km over" / "Not set".
String oilStatusText(BuildContext context, Vehicle v, int? estimate) {
  final l10n = AppLocalizations.of(context);
  final left = v.oilKmLeft(estimate);
  if (left == null) return v.oilIntervalKm == null ? l10n.renewalNotSet : l10n.oilNoChangeYet;
  return left > 0 ? l10n.oilKmLeft(formatKm(context, left)) : l10n.oilOverdue(formatKm(context, -left));
}

/// Vehicles whose renewals or oil change need doing (expired / due soon).
bool vehicleNeedsAttention(Vehicle v, DateTime today, int? estimate) =>
    v.needsRenewal(today) || v.oil(estimate).index >= OilState.dueSoon.index;

/// A small coloured chip like [RenewalChip] for the oil change.
class OilChip extends StatelessWidget {
  const OilChip({super.key, required this.vehicle, required this.estimate});

  final Vehicle vehicle;
  final int? estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = oilColor(context, vehicle.oil(estimate));
    return _StateChip(icon: Icons.oil_barrel_outlined, color: color, text: '${l10n.oilChange} · ${oilStatusText(context, vehicle, estimate)}');
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color))),
          ],
        ),
      );
}

/// A small coloured chip: item + its state.
class RenewalChip extends StatelessWidget {
  const RenewalChip({super.key, required this.vehicle, required this.item, required this.today});

  final Vehicle vehicle;
  final Renewal item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = renewalColor(context, vehicle.state(item, today));
    return _StateChip(
      icon: renewalIcon(item),
      color: color,
      text: '${renewalLabel(l10n, item)} · ${renewalStatusText(context, vehicle.expiries[item], today)}',
    );
  }
}

/// Asks for the new expiry date of [r] (offered: a year after the old one)
/// and saves it as a renewal.
Future<void> renewVehicle(BuildContext context, Vehicle v, Renewal r) async {
  final l10n = AppLocalizations.of(context);
  var day = nextExpiry(v.expiries[r], DateTime.now());
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setDialog) => AlertDialog(
        title: Text(l10n.renewDialogTitle(renewalLabel(l10n, r))),
        content: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l10n.renewDialogHint),
          subtitle: Text(formatVehicleDay(context, day)),
          trailing: const Icon(Icons.edit_calendar),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: dialog,
              initialDate: DateTime.tryParse(day) ?? now,
              firstDate: DateTime(now.year - 10),
              lastDate: DateTime(now.year + 10),
              helpText: l10n.renewDialogHint,
            );
            if (picked != null) setDialog(() => day = vehicleDay(picked));
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
        ],
      ),
    ),
  );
  if (ok == true) await setRenewal(v, r, day, renewed: true);
}

/// Asks for the km and day of an oil change (km offered: the estimate) and
/// records it. The km typed is the odometer: it's saved as a reading too,
/// so when it differs from the estimate it replaces it (user request
/// 2026-10-26); the difference is shown after saving.
Future<void> recordOilChange(BuildContext context, Vehicle v, int? estimate) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final km = TextEditingController(text: estimate == null ? '' : '$estimate');
  final note = TextEditingController();
  var day = vehicleDay(DateTime.now());
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setDialog) => AlertDialog(
        title: Text(l10n.recordOilChangeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estimate == null ? l10n.oilOdometerHelpNoEstimate : l10n.oilOdometerHelp(formatKm(context, estimate)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextField(
              controller: km,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: l10n.odometerKm),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatVehicleDay(context, day)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: dialog,
                  initialDate: DateTime.tryParse(day) ?? now,
                  firstDate: DateTime(now.year - 10),
                  lastDate: now,
                );
                if (picked != null) setDialog(() => day = vehicleDay(picked));
              },
            ),
            TextField(controller: note, decoration: InputDecoration(labelText: l10n.readingNote)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.save)),
        ],
      ),
    ),
  );
  final value = int.tryParse(km.text.trim());
  final text = note.text.trim();
  km.dispose();
  note.dispose();
  if (ok != true || value == null || !context.mounted) return;
  final estimateText = estimate == null ? '' : formatKm(context, estimate);
  final valueText = formatKm(context, value);
  await addOilChange(v.id, km: value, day: day, note: text);
  // Only today's change corrects "now"; a backdated one is history.
  if (estimate != null && day == vehicleDay(DateTime.now()) && (value - estimate).abs() >= 1) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.oilMileageCorrected(valueText, estimateText))));
  }
}

/// Home card for the GM, sales manager and logistics manager (user
/// decisions 2026-10-24): every renewal expired or due within 14 days, shown until a
/// new expiry date is entered ("Renewed"), and every oil change due or
/// within 500 km (2026-10-26), until one is recorded. Hidden when there are none.
class VehicleRenewalsCard extends ConsumerWidget {
  const VehicleRenewalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null || !me.role.managesDrivers) return const SizedBox.shrink();
    if (!(ref.watch(pageAccessProvider).value ?? PageAccess.defaults).allowsUser(me, AppPage.vehicles)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final today = DateTime.now();
    final vehicles = ref.watch(vehiclesProvider).value ?? const <Vehicle>[];
    final due = [
      for (final v in vehicles)
        if (v.needsRenewal(today))
          for (final r in Renewal.values)
            if (v.state(r, today).index >= RenewalState.dueSoon.index) (v, r),
    ]..sort((a, b) => daysUntil(a.$1.expiries[a.$2]!, today).compareTo(daysUntil(b.$1.expiries[b.$2]!, today)));
    // Oil: estimate from the drivers' GPS km, only for vehicles tracking it.
    final oilCars = [for (final v in vehicles) if (v.active && v.nextOilKm != null) v];
    final from = firstKmDay(oilCars);
    final km = from == null ? const <DriverDayKm>[] : ref.watch(driverKmProvider(from)).value ?? const <DriverDayKm>[];
    final oil = [
      for (final v in oilCars)
        if (vehicleMileage(v, km).estimate case final e when v.oil(e).index >= OilState.dueSoon.index) (v, e),
    ]..sort((a, b) => a.$1.oilKmLeft(a.$2)!.compareTo(b.$1.oilKmLeft(b.$2)!));
    final count = due.length + oil.length;
    if (count == 0) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(l10n.vehicleRenewalsDue(count), style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final (v, e) in oil)
              ListTile(
                dense: true,
                leading: Icon(Icons.oil_barrel_outlined, color: oilColor(context, v.oil(e))),
                title: Text('${v.plate} · ${l10n.oilChange}'),
                subtitle: Text(oilStatusText(context, v, e), style: TextStyle(color: oilColor(context, v.oil(e)))),
                trailing: TextButton(onPressed: () => recordOilChange(context, v, e), child: Text(l10n.recordOilChange)),
                onTap: () => context.push('/vehicles/${v.id}'),
              ),
            for (final (v, r) in due.take(8))
              ListTile(
                dense: true,
                leading: Icon(renewalIcon(r), color: renewalColor(context, v.state(r, today))),
                title: Text('${v.plate} · ${renewalLabel(l10n, r)}'),
                subtitle: Text(
                  renewalStatusText(context, v.expiries[r], today),
                  style: TextStyle(color: renewalColor(context, v.state(r, today))),
                ),
                trailing: TextButton(onPressed: () => renewVehicle(context, v, r), child: Text(l10n.markRenewed)),
                onTap: () => context.push('/vehicles/${v.id}'),
              ),
            if (due.length > 8)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: () => context.push('/vehicles'), child: Text(l10n.viewAll)),
              ),
          ],
        ),
      ),
    );
  }
}
