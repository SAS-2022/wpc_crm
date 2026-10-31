import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/tracking/activity_sense.dart';

void main() {
  final now = DateTime(2026, 10, 31, 10);

  test('activityCode maps the detected activity', () {
    expect(activityCode(ActivityType.IN_VEHICLE, 80, now, now), 'v');
    expect(activityCode(ActivityType.WALKING, 80, now, now), 'f');
    expect(activityCode(ActivityType.ON_FOOT, 80, now, now), 'f');
    expect(activityCode(ActivityType.RUNNING, 80, now, now), 'f');
    expect(activityCode(ActivityType.STILL, 80, now, now), 's');
    expect(activityCode(ActivityType.ON_BICYCLE, 80, now, now), 'b');
    expect(activityCode(ActivityType.TILTING, 80, now, now), isNull);
    expect(activityCode(ActivityType.UNKNOWN, 80, now, now), isNull);
  });

  test('activityCode drops unsure and old detections', () {
    expect(activityCode(ActivityType.IN_VEHICLE, 49, now, now), isNull);
    expect(activityCode(ActivityType.IN_VEHICLE, 50, now, now), 'v');
    expect(activityCode(ActivityType.IN_VEHICLE, 90, now.subtract(const Duration(minutes: 5)), now), 'v');
    expect(activityCode(ActivityType.IN_VEHICLE, 90, now.subtract(const Duration(minutes: 6)), now), isNull);
  });
}
