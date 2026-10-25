import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'attendance_repository.dart';
import 'attendance_rules.dart';
import 'geofences.dart';
import 'work_sites.dart';

// Site checks (2026-10-25, after Worker Number Two's phone went silent at
// 08:04 on 24 Oct and the day closed at 17:00 without overtime): while
// someone with overtime is still checked in after the end of their work day,
// the `attendanceUpdated` / `closeAttendance` Cloud Functions send a silent
// push ({type: 'siteCheck'}) every 30 minutes, up to their overtime cap. The
// phone takes one GPS fix and records `seen` (still at a site) or `out` with
// `check: true` (gone; the server checks them out at the last time seen).
// A rough fix or no fix records nothing.

/// Answers a site check (push handler, also with the app closed).
Future<void> answerSiteCheck() async {
  try {
    final user = FirebaseAuth.instance.currentUser ?? await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return;
    final db = FirebaseFirestore.instance;
    final ids = ((await db.doc('users/${user.uid}').get()).data()?['workSiteIds'] as List?)?.whereType<String>().toList();
    if (ids == null || ids.isEmpty) return;
    final sites = [
      for (final d in (await db.collection('work_sites').where(FieldPath.documentId, whereIn: ids.take(30).toList()).get()).docs)
        WorkSite.fromDoc(d),
    ].where((s) => s.active).toList();
    if (sites.isEmpty) return;
    final fix = await freshAttendanceFix();
    if (fix == null) return;
    // The nearest site decides.
    double distanceTo(WorkSite s) => Geolocator.distanceBetween(fix.latitude, fix.longitude, s.lat, s.lng);
    sites.sort((a, b) => distanceTo(a).compareTo(distanceTo(b)));
    final site = sites.first;
    final distance = distanceTo(site);
    final result = siteCheckResult(distance: distance, accuracy: fix.accuracy, radius: site.radius);
    debugPrint('site check: ${result.name}, ${distance.round()} m from ${site.id} (±${fix.accuracy.round()} m)');
    if (result == SiteCheckResult.unknown) return;
    await recordAttendance(
      user.uid,
      result == SiteCheckResult.seen ? AttendanceEventType.seen : AttendanceEventType.out,
      siteId: site.id,
      extra: {'check': true, 'dist': distance.round(), 'acc': fix.accuracy.round()},
    ).timeout(const Duration(seconds: 20), onTimeout: () {});
  } catch (e) {
    debugPrint('site check: $e');
  }
}
