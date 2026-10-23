import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/early_checkout.dart';
import 'package:wpc_crm/features/tracking/work_hours.dart';

void main() {
  // Saudi time = UTC+3; 2026-10-22 is a Thursday, 2026-10-23 a Friday.
  DateTime saudi(int day, int h, int m) => DateTime.utc(2026, 10, day, h - 3, m);

  test('approval needed only before the end of a work day', () {
    const hours = WorkHours.defaults; // Sat–Thu, 08:00–17:00
    expect(needsEarlyCheckoutApproval(saudi(22, 9, 0), hours), isTrue);
    expect(needsEarlyCheckoutApproval(saudi(22, 16, 59), hours), isTrue);
    expect(needsEarlyCheckoutApproval(saudi(22, 17, 0), hours), isFalse);
    expect(needsEarlyCheckoutApproval(saudi(22, 20, 0), hours), isFalse);
    // Friday is a day off.
    expect(needsEarlyCheckoutApproval(saudi(23, 10, 0), hours), isFalse);
  });

  test("the person's own schedule", () {
    const own = WorkHours(days: {DateTime.friday}, startMinute: 7 * 60, endMinute: 13 * 60);
    expect(needsEarlyCheckoutApproval(saudi(23, 12, 0), own), isTrue);
    expect(needsEarlyCheckoutApproval(saudi(23, 13, 30), own), isFalse);
  });
}
