import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/vehicles/vehicle.dart';

void main() {
  final today = DateTime(2026, 10, 24);

  group('renewalState', () {
    test('missing, ok, due soon, expired', () {
      expect(renewalState(null, today), RenewalState.missing);
      expect(renewalState('2026-11-08', today), RenewalState.ok);
      expect(renewalState('2026-11-07', today), RenewalState.dueSoon);
      expect(renewalState('2026-10-25', today), RenewalState.dueSoon);
      expect(renewalState('2026-10-24', today), RenewalState.expired);
      expect(renewalState('2026-01-01', today), RenewalState.expired);
    });

    test('daysUntil', () {
      expect(daysUntil('2026-11-23', today), 30);
      expect(daysUntil('2026-10-20', today), -4);
    });
  });

  group('nextExpiry', () {
    test('a year after the old date when renewed early or on time', () {
      expect(nextExpiry('2026-11-10', today), '2027-11-10');
      expect(nextExpiry('2026-10-01', today), '2027-10-01');
    });

    test('a year from today when long expired or not set', () {
      expect(nextExpiry('2026-03-01', today), '2027-10-24');
      expect(nextExpiry(null, today), '2027-10-24');
    });

    test('29 February', () {
      expect(nextExpiry('2028-02-29', DateTime(2028, 2, 1)), '2029-02-28');
    });
  });

  Vehicle car({List<OdometerReading> readings = const [], List<DriverSpell> log = const [], Map<Renewal, String> expiries = const {}}) =>
      Vehicle(id: 'v', plate: 'ABC', readings: readings, driverLog: log, driverIds: [for (final s in log) if (s.to == null) s.driverId], expiries: expiries);

  group('vehicleMileage', () {
    const km = [
      DriverDayKm(uid: 'a', day: '2026-10-20', km: 50),
      DriverDayKm(uid: 'a', day: '2026-10-21', km: 60),
      DriverDayKm(uid: 'a', day: '2026-10-22', km: 70),
      DriverDayKm(uid: 'b', day: '2026-10-22', km: 30),
      DriverDayKm(uid: 'c', day: '2026-10-22', km: 999),
    ];

    test('the last reading plus its drivers\' km from the day after it', () {
      final v = car(
        readings: const [OdometerReading(id: '1', km: 10000, day: '2026-10-20')],
        log: const [DriverSpell(driverId: 'a', from: '2026-10-01'), DriverSpell(driverId: 'b', from: '2026-10-01')],
      );
      final m = vehicleMileage(v, km);
      expect(m.gpsKm, 160);
      expect(m.byDriver, {'a': 130.0, 'b': 30.0});
      expect(m.estimate, 10160);
      expect(m.since, '2026-10-20');
    });

    test('only while each driver was on the vehicle', () {
      final v = car(
        readings: const [OdometerReading(id: '1', km: 100, day: '2026-10-01')],
        log: const [DriverSpell(driverId: 'a', from: '2026-10-01', to: '2026-10-20'), DriverSpell(driverId: 'b', from: '2026-10-21')],
      );
      expect(vehicleMileage(v, km).byDriver, {'a': 50.0, 'b': 30.0});
    });

    test('readings sort by day; no reading = no estimate', () {
      final v = Vehicle.fromMap('v', {
        'plate': 'ABC',
        'readings': [
          {'id': '2', 'km': 12000, 'day': '2026-10-21'},
          {'id': '1', 'km': 10000, 'day': '2026-09-01'},
        ],
        'driverLog': [
          {'driverId': 'a', 'from': '2026-10-01'},
        ],
      });
      expect(v.lastReading!.km, 12000);
      expect(vehicleMileage(v, km).estimate, 12070);
      final none = car(log: const [DriverSpell(driverId: 'a', from: '2026-10-21')]);
      expect(vehicleMileage(none, km).estimate, isNull);
      expect(vehicleMileage(none, km).gpsKm, 130);
    });
  });

  test('firstKmDay: oldest last reading, else oldest assignment', () {
    expect(firstKmDay([]), isNull);
    expect(
      firstKmDay([
        car(readings: const [OdometerReading(id: '1', km: 1, day: '2026-10-10')]),
        car(log: const [DriverSpell(driverId: 'a', from: '2026-09-15')]),
      ]),
      '2026-09-15',
    );
  });

  group('updatedDriverLog', () {
    test('removed drivers end yesterday, new ones start today', () {
      final log = updatedDriverLog(const [DriverSpell(driverId: 'a', from: '2026-10-01')], {'b'}, today);
      expect([for (final s in log) s.toMap()], [
        {'driverId': 'a', 'from': '2026-10-01', 'to': '2026-10-23'},
        {'driverId': 'b', 'from': '2026-10-24', 'to': null},
      ]);
    });

    test('kept drivers stay as they are; a spell started today and removed today is dropped', () {
      final log = updatedDriverLog(
        const [DriverSpell(driverId: 'a', from: '2026-10-01'), DriverSpell(driverId: 'b', from: '2026-10-24')],
        {'a'},
        today,
      );
      expect([for (final s in log) s.toMap()], [
        {'driverId': 'a', 'from': '2026-10-01', 'to': null},
      ]);
    });

    test('old spells are kept', () {
      final log = updatedDriverLog(const [DriverSpell(driverId: 'a', from: '2026-01-01', to: '2026-02-01')], {'a'}, today);
      expect(log.length, 2);
      expect(log.last.from, '2026-10-24');
    });
  });

  test('needsRenewal and worstState', () {
    final v = car(expiries: {Renewal.insurance: '2026-11-05', Renewal.registration: '2027-06-01'});
    expect(v.needsRenewal(today), isTrue);
    expect(v.worstState(today), RenewalState.dueSoon);
    expect(car(expiries: {Renewal.registration: '2027-06-01'}).needsRenewal(today), isFalse);
    expect(car(expiries: {Renewal.insurance: '2026-11-20'}).needsRenewal(today), isFalse);
    expect(car(expiries: {Renewal.inspection: '2026-10-01'}).worstState(today), RenewalState.expired);
  });
}
