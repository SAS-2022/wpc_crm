import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/attendance_rules.dart';
import 'package:wpc_crm/features/attendance/site_now.dart';
import 'package:wpc_crm/features/attendance/work_sites.dart';

void main() {
  const service = WorkSite(id: 'service', name: 'Service Center', lat: 24.572284, lng: 46.515594, radius: 100);
  const riyadh = WorkSite(id: 'riyadh', name: 'Riyadh', lat: 24.554654, lng: 46.479520, radius: 100);
  final now = DateTime(2026, 11, 7, 12);

  test('fresh position decides: at a site, or elsewhere = none', () {
    expect(siteNow(sites: [service, riyadh], lat: 24.55470, lng: 46.47955, accuracy: 20, at: now, now: now), 'riyadh');
    expect(siteNow(sites: [service, riyadh], lat: 24.60, lng: 46.60, accuracy: 10, at: now, now: now), isNull);
    // Elsewhere beats a check-in still marked inside.
    expect(
      siteNow(sites: [service, riyadh], lat: 24.60, lng: 46.60, at: now, now: now, inside: true,
          events: [AttendanceEvent(AttendanceEventType.in_, DateTime(2026, 11, 7, 8), siteId: 'service')]),
      isNull,
    );
  });

  test('no fresh position: the latest arrival while inside', () {
    final events = [
      AttendanceEvent(AttendanceEventType.in_, DateTime(2026, 11, 7, 7, 55), siteId: 'service'),
      AttendanceEvent(AttendanceEventType.out, DateTime(2026, 11, 7, 7, 59), siteId: 'service'),
      AttendanceEvent(AttendanceEventType.in_, DateTime(2026, 11, 7, 8, 6), siteId: 'riyadh'),
    ];
    final old = now.subtract(const Duration(hours: 2));
    expect(siteNow(sites: [service, riyadh], lat: 24.60, lng: 46.60, at: old, now: now, inside: true, events: events), 'riyadh');
    expect(siteNow(sites: [service, riyadh], now: now, inside: false, events: events), isNull);
  });

  test('shown under a site: there now, or at no site and assigned to it', () {
    expect(showsUnderSite('service', now: 'service', assigned: const ['riyadh']), isTrue);
    expect(showsUnderSite('service', now: 'riyadh', assigned: const ['service', 'riyadh']), isFalse);
    expect(showsUnderSite('service', now: null, assigned: const ['service', 'riyadh']), isTrue);
    expect(showsUnderSite('service', now: null, assigned: const ['riyadh']), isFalse);
  });
}
