import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/saving.dart';
import 'vehicle.dart';

CollectionReference<Map<String, dynamic>> get _vehicles => FirebaseFirestore.instance.collection('vehicles');

/// Every vehicle, by plate. Sales manager, GM and logistics manager only
/// (rules); nobody else listens.
final vehiclesProvider = StreamProvider<List<Vehicle>>((ref) {
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.active == true && u.value!.role.managesDrivers ? u.value!.id : null));
  if (uid == null) return Stream.value(const []);
  return _vehicles.snapshots().map(
        (s) => s.docs.map(Vehicle.fromDoc).toList()..sort((a, b) => a.plate.compareTo(b.plate)),
      );
});

final vehicleProvider = Provider.family<Vehicle?, String>((ref, id) {
  for (final v in ref.watch(vehiclesProvider).value ?? const <Vehicle>[]) {
    if (v.id == id) return v;
  }
  return null;
});

/// Drivers' GPS km per day from [from] ('yyyy-MM-dd') on, that day included. One range on
/// `day` (no composite index); filtered to the vehicles' drivers in the app.
final driverKmProvider = StreamProvider.family<List<DriverDayKm>, String>((ref, from) {
  return FirebaseFirestore.instance
      .collection('driver_km')
      .where('day', isGreaterThanOrEqualTo: from)
      .snapshots()
      .map((s) => s.docs.map(DriverDayKm.fromDoc).toList());
});

/// Has the server build today's km and any missing day of [uids] (the
/// nightly `driverKm` does the rest). Failures are ignored: the page shows
/// what is there.
Future<void> refreshDriverKm(List<String> uids, String? from) async {
  if (uids.isEmpty) return;
  try {
    await FirebaseFunctions.instance
        .httpsCallable('refreshDriverKm', options: HttpsCallableOptions(timeout: const Duration(minutes: 2)))
        .call({'uids': uids.take(30).toList(), 'from': from});
  } catch (_) {}
}

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

/// Adds ([id] null) or updates the vehicle's details; returns its id.
Future<String> saveVehicle({
  String? id,
  required String plate,
  required String make,
  required String model,
  required int? year,
  required String color,
  required String vin,
  required String notes,
  required bool active,
  Map<Renewal, String?> expiries = const {},
  int? firstKm,
  int? oilIntervalKm,
}) =>
    saving(() async {
      final ref = id == null ? _vehicles.doc() : _vehicles.doc(id);
      final details = {
        'plate': plate,
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'vin': vin,
        'notes': notes,
        'active': active,
        'oilIntervalKm': oilIntervalKm,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (id == null) {
        await ref.set({
          ...details,
          'expiries': {for (final e in expiries.entries) e.key.name: e.value},
          'driverIds': <String>[],
          'driverLog': <Object>[],
          'readings': [
            if (firstKm != null)
              OdometerReading(id: '${DateTime.now().millisecondsSinceEpoch}', km: firstKm, day: vehicleDay(DateTime.now()), at: DateTime.now(), byId: _uid)
                  .toMap(),
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _uid,
        });
      } else {
        await ref.update({...details, for (final e in expiries.entries) 'expiries.${e.key.name}': e.value});
      }
      return ref.id;
    });

Future<void> deleteVehicle(String id) => saving(() => _vehicles.doc(id).delete());

/// Sets [vehicle]'s drivers to [ids]; a driver taken from another vehicle
/// leaves it (one vehicle per driver, so their km count once).
Future<void> setVehicleDrivers(Vehicle vehicle, Set<String> ids, List<Vehicle> all) => saving(() async {
      final now = DateTime.now();
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_vehicles.doc(vehicle.id), {
        'driverIds': ids.toList(),
        'driverLog': [for (final s in updatedDriverLog(vehicle.driverLog, ids, now)) s.toMap()],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final other in all) {
        if (other.id == vehicle.id || !other.driverIds.any(ids.contains)) continue;
        final keep = {...other.driverIds}..removeAll(ids);
        batch.update(_vehicles.doc(other.id), {
          'driverIds': keep.toList(),
          'driverLog': [for (final s in updatedDriverLog(other.driverLog, keep, now)) s.toMap()],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    });

Future<void> addOdometerReading(String vehicleId, {required int km, required String day, String note = ''}) => saving(() {
      final r = OdometerReading(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        km: km,
        day: day,
        at: DateTime.now(),
        byId: _uid,
        note: note,
      );
      return _vehicles.doc(vehicleId).update({
        'readings': FieldValue.arrayUnion([r.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

Future<void> deleteOdometerReading(Vehicle vehicle, String readingId) => saving(() => _vehicles.doc(vehicle.id).update({
      'readings': [
        for (final r in vehicle.readings)
          if (r.id != readingId) r.toMap(),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    }));

/// Sets a new expiry for [item] ([renewed]: logged as a renewal; else a
/// correction of the date).
Future<void> setRenewal(Vehicle vehicle, Renewal item, String? expiry, {required bool renewed}) =>
    saving(() => _vehicles.doc(vehicle.id).update({
          'expiries.${item.name}': expiry,
          if (renewed && expiry != null)
            'renewalLog': FieldValue.arrayUnion([
              {'item': item.name, 'expiry': expiry, 'previous': vehicle.expiries[item], 'byId': _uid, 'at': Timestamp.now()},
            ]),
          'updatedAt': FieldValue.serverTimestamp(),
        }));

/// Records an oil change at [km] on [day]; it's also an odometer reading
/// (same id), so the mileage estimate starts from it.
Future<void> addOilChange(String vehicleId, {required int km, required String day, String note = ''}) => saving(() {
      final now = DateTime.now();
      final change = OilChange(id: '${now.millisecondsSinceEpoch}', km: km, day: day, at: now, byId: _uid, note: note);
      final reading = OdometerReading(id: change.id, km: km, day: day, at: now, byId: _uid, note: note);
      return _vehicles.doc(vehicleId).update({
        'oilLog': FieldValue.arrayUnion([change.toMap()]),
        'readings': FieldValue.arrayUnion([reading.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

/// Removes an oil change (its odometer reading stays).
Future<void> deleteOilChange(Vehicle vehicle, String id) => saving(() => _vehicles.doc(vehicle.id).update({
      'oilLog': [
        for (final c in vehicle.oilLog)
          if (c.id != id) c.toMap(),
      ],
      'updatedAt': FieldValue.serverTimestamp(),
    }));
