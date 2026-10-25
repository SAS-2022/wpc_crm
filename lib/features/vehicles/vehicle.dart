import 'package:cloud_firestore/cloud_firestore.dart';

// Vehicles (user request 2026-10-24): the company cars, each with its
// drivers, the yearly renewals required in Saudi Arabia (registration /
// Istimara, insurance, periodic inspection / Fahas) and the mileage: readings
// entered by hand plus the GPS kilometres its drivers drove since the last
// one (`driver_km/{uid}_{day}`, Cloud Functions `driverKm` /
// `refreshDriverKm`). Firestore `vehicles/{id}`: plate, make, model, year,
// color, vin, notes, active, driverIds, driverLog [{driverId, from, to?}],
// expiries {registration|insurance|inspection: 'yyyy-MM-dd'}, readings [{id,
// km, day, at, byId, note}], renewalLog [{item, expiry, previous, byId, at}],
// renewalNotified (keys sent by `vehicleRenewals`). Same renewal rules as
// functions/vehicles.js.

enum Renewal { registration, insurance, inspection }

enum RenewalState { missing, ok, dueSoon, expired }

/// Shown as "due soon" (reminded, and on Home until renewed) this many days
/// before the expiry: App settings → Vehicles (`AppSetting.vehicleRenewalDays`,
/// default 14), set by `AppSettings.apply`.
var renewalDueSoonDays = 14;

/// 'yyyy-MM-dd' of a date.
String vehicleDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Whole days from [today] to [expiry]; negative once past.
int daysUntil(String expiry, DateTime today) {
  final e = DateTime.tryParse(expiry);
  if (e == null) return 0;
  return DateTime.utc(e.year, e.month, e.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
}

RenewalState renewalState(String? expiry, DateTime today) {
  if (expiry == null || DateTime.tryParse(expiry) == null) return RenewalState.missing;
  final days = daysUntil(expiry, today);
  if (days <= 0) return RenewalState.expired;
  if (days <= renewalDueSoonDays) return RenewalState.dueSoon;
  return RenewalState.ok;
}

/// The new expiry offered when renewing: a year after the old one (renewed
/// early or on time), or a year from today when it had run out long ago
/// or wasn't set.
String nextExpiry(String? expiry, DateTime today) {
  final e = expiry == null ? null : DateTime.tryParse(expiry);
  final base = e == null || daysUntil(expiry!, today) < -30 ? today : e;
  // 29 Feb → 28 Feb.
  final next = DateTime(base.year + 1, base.month, base.day);
  return vehicleDay(next.month == base.month ? next : DateTime(base.year + 1, base.month + 1, 0));
}

class OdometerReading {
  const OdometerReading({required this.id, required this.km, required this.day, this.at, this.byId = '', this.note = ''});

  final String id;
  final int km;

  /// The day the odometer showed [km] ('yyyy-MM-dd', may be backdated).
  final String day;

  /// When it was entered.
  final DateTime? at;
  final String byId;
  final String note;

  static OdometerReading? fromMap(Object? m) {
    if (m is! Map) return null;
    final km = (m['km'] as num?)?.toInt();
    final day = m['day'] as String?;
    if (km == null || day == null) return null;
    return OdometerReading(
      id: m['id'] as String? ?? '$day-$km',
      km: km,
      day: day,
      at: (m['at'] as Timestamp?)?.toDate(),
      byId: m['byId'] as String? ?? '',
      note: m['note'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() => {'id': id, 'km': km, 'day': day, 'at': at, 'byId': byId, 'note': note};
}

/// A driver on the vehicle from [from] to [to] (null = still), days 'yyyy-MM-dd'.
class DriverSpell {
  const DriverSpell({required this.driverId, required this.from, this.to});

  final String driverId;
  final String from;
  final String? to;

  bool covers(String day) => from.compareTo(day) <= 0 && (to == null || day.compareTo(to!) <= 0);

  static DriverSpell? fromMap(Object? m) {
    if (m is! Map || m['driverId'] is! String || m['from'] is! String) return null;
    return DriverSpell(driverId: m['driverId'] as String, from: m['from'] as String, to: m['to'] as String?);
  }

  Map<String, Object?> toMap() => {'driverId': driverId, 'from': from, 'to': to};
}

class RenewalEntry {
  const RenewalEntry({required this.item, required this.expiry, this.previous, this.byId = '', this.at});

  final Renewal item;
  final String expiry;
  final String? previous;
  final String byId;
  final DateTime? at;

  static RenewalEntry? fromMap(Object? m) {
    if (m is! Map) return null;
    final item = Renewal.values.asNameMap()[m['item']];
    if (item == null || m['expiry'] is! String) return null;
    return RenewalEntry(
      item: item,
      expiry: m['expiry'] as String,
      previous: m['previous'] as String?,
      byId: m['byId'] as String? ?? '',
      at: (m['at'] as Timestamp?)?.toDate(),
    );
  }
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    this.make = '',
    this.model = '',
    this.year,
    this.color = '',
    this.vin = '',
    this.notes = '',
    this.active = true,
    this.driverIds = const [],
    this.driverLog = const [],
    this.expiries = const {},
    this.readings = const [],
    this.renewalLog = const [],
  });

  final String id;
  final String plate;
  final String make;
  final String model;
  final int? year;
  final String color;

  /// Chassis number.
  final String vin;
  final String notes;
  final bool active;
  final List<String> driverIds;
  final List<DriverSpell> driverLog;
  final Map<Renewal, String> expiries;

  /// Oldest first.
  final List<OdometerReading> readings;
  final List<RenewalEntry> renewalLog;

  /// "Toyota Hilux 2022".
  String get title => [make, model, if (year != null) '$year'].where((s) => s.isNotEmpty).join(' ');

  /// The latest reading by the day it was taken.
  OdometerReading? get lastReading => readings.isEmpty ? null : readings.last;

  RenewalState state(Renewal r, DateTime today) => renewalState(expiries[r], today);

  /// The worst state of the three (expired first), for sorting and the list.
  RenewalState worstState(DateTime today) {
    var worst = RenewalState.ok;
    for (final r in Renewal.values) {
      final s = state(r, today);
      if (_rank(s) > _rank(worst)) worst = s;
    }
    return worst;
  }

  /// Expired or due soon (missing dates aren't counted).
  bool needsRenewal(DateTime today) => active && Renewal.values.any((r) => state(r, today).index >= RenewalState.dueSoon.index);

  static int _rank(RenewalState s) => switch (s) {
        RenewalState.ok => 0,
        RenewalState.missing => 1,
        RenewalState.dueSoon => 2,
        RenewalState.expired => 3,
      };

  factory Vehicle.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => Vehicle.fromMap(doc.id, doc.data() ?? const {});

  factory Vehicle.fromMap(String id, Map<String, dynamic> d) {
    final exp = d['expiries'];
    final readings = [
      for (final m in d['readings'] as List? ?? const []) ?OdometerReading.fromMap(m),
    ]..sort((a, b) {
        final byDay = a.day.compareTo(b.day);
        return byDay != 0 ? byDay : (a.at ?? DateTime(0)).compareTo(b.at ?? DateTime(0));
      });
    return Vehicle(
      id: id,
      plate: d['plate'] as String? ?? '',
      make: d['make'] as String? ?? '',
      model: d['model'] as String? ?? '',
      year: (d['year'] as num?)?.toInt(),
      color: d['color'] as String? ?? '',
      vin: d['vin'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      active: d['active'] != false,
      driverIds: [for (final v in d['driverIds'] as List? ?? const []) if (v is String) v],
      driverLog: [
        for (final m in d['driverLog'] as List? ?? const []) ?DriverSpell.fromMap(m),
      ],
      expiries: {
        if (exp is Map)
          for (final r in Renewal.values)
            if (exp[r.name] case final String day when DateTime.tryParse(day) != null) r: day,
      },
      readings: readings,
      renewalLog: [
        for (final m in d['renewalLog'] as List? ?? const []) ?RenewalEntry.fromMap(m),
      ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0))),
    );
  }
}

/// One driver's GPS kilometres on one day (`driver_km`).
class DriverDayKm {
  const DriverDayKm({required this.uid, required this.day, required this.km});

  final String uid;
  final String day;
  final double km;

  factory DriverDayKm.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return DriverDayKm(uid: d['uid'] as String? ?? '', day: d['day'] as String? ?? '', km: (d['km'] as num?)?.toDouble() ?? 0);
  }
}

/// The vehicle's GPS kilometres since its last reading.
class VehicleMileage {
  const VehicleMileage({required this.since, required this.gpsKm, required this.byDriver, required this.estimate});

  /// Counted from the day after this ('yyyy-MM-dd'); null = since its drivers were assigned.
  final String? since;
  final double gpsKm;
  final Map<String, double> byDriver;

  /// Last reading + [gpsKm]; null without a reading.
  final int? estimate;
}

/// Adds the [km] days of the vehicle's drivers that fall after its last
/// reading's day (the reading may have been taken any time that day, so its
/// day's driving is left out) and while each driver was on the vehicle.
VehicleMileage vehicleMileage(Vehicle v, Iterable<DriverDayKm> km) {
  final last = v.lastReading;
  final since = last?.day;
  final byDriver = <String, double>{};
  for (final d in km) {
    if (since != null && d.day.compareTo(since) <= 0) continue;
    if (!v.driverLog.any((s) => s.driverId == d.uid && s.covers(d.day))) continue;
    byDriver[d.uid] = (byDriver[d.uid] ?? 0) + d.km;
  }
  final total = byDriver.values.fold(0.0, (a, b) => a + b);
  return VehicleMileage(
    since: since,
    gpsKm: total,
    byDriver: byDriver,
    estimate: last == null ? null : last.km + total.round(),
  );
}

/// The first day whose km [vehicles] need: the oldest last reading, else the
/// oldest driver assignment.
String? firstKmDay(Iterable<Vehicle> vehicles) {
  String? first;
  for (final v in vehicles) {
    final day = v.lastReading?.day ?? (v.driverLog.isEmpty ? null : v.driverLog.map((s) => s.from).reduce((a, b) => a.compareTo(b) <= 0 ? a : b));
    if (day != null && (first == null || day.compareTo(first) < 0)) first = day;
  }
  return first;
}

/// The driver log after setting the vehicle's drivers to [ids] on [today]:
/// removed drivers end yesterday (today's driving goes to their new
/// vehicle), new ones start today. A driver added and removed the same day
/// leaves an empty spell, which is dropped.
List<DriverSpell> updatedDriverLog(List<DriverSpell> log, Set<String> ids, DateTime today) {
  final day = vehicleDay(today);
  final yesterday = vehicleDay(DateTime(today.year, today.month, today.day - 1));
  final open = {for (final s in log) if (s.to == null) s.driverId};
  return [
    for (final s in log)
      if (s.to != null || ids.contains(s.driverId))
        s
      else if (s.from.compareTo(yesterday) <= 0)
        DriverSpell(driverId: s.driverId, from: s.from, to: yesterday),
    for (final id in ids)
      if (!open.contains(id)) DriverSpell(driverId: id, from: day),
  ];
}
