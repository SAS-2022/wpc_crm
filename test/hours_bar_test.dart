import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/hours_bar.dart';

void main() {
  test('10 h 45 with 1 h 35 overtime on a 9 h 10 day', () {
    final s = hoursSplit(workedMin: 645, overtimeMin: 95, scheduledMin: 550);
    expect(s.normalMin, 550);
    expect(s.overtimeMin, 95);
    expect(s.totalMin, 645);
    expect(s.normalShare + s.overtimeShare, closeTo(1, 1e-9));
  });

  test('short day: bar against the schedule, no overtime', () {
    final s = hoursSplit(workedMin: 270, overtimeMin: 0, scheduledMin: 540);
    expect(s.normalShare, 0.5);
    expect(s.overtimeShare, 0);
  });

  test('overtime never above the worked time; day off', () {
    expect(hoursSplit(workedMin: 60, overtimeMin: 90, scheduledMin: 0).overtimeMin, 60);
    expect(hoursSplit(workedMin: 0, overtimeMin: 0, scheduledMin: 0).totalMin, 0);
  });
}
