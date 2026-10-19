import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/tracking/device_health.dart';

void main() {
  test('a gap is 15 min or more without sending, on the same day', () {
    final at = DateTime(2026, 10, 19, 14, 3);
    expect(gapBefore(at, DateTime(2026, 10, 19, 16, 39)), (from: at, to: DateTime(2026, 10, 19, 16, 39)));
    expect(gapBefore(at, at.add(const Duration(minutes: 5))), isNull); // normal / short reconnect
    expect(gapBefore(DateTime(2026, 10, 18, 17), DateTime(2026, 10, 19, 8)), isNull); // overnight
    expect(gapBefore(null, at), isNull);
  });

  test('phone makers with their own battery managers', () {
    expect(phoneBrand('Xiaomi'), PhoneBrand.xiaomi);
    expect(phoneBrand('Redmi'), PhoneBrand.xiaomi);
    expect(phoneBrand('samsung'), PhoneBrand.samsung);
    expect(phoneBrand('HONOR'), PhoneBrand.huawei);
    expect(phoneBrand('realme'), PhoneBrand.oppo);
    expect(phoneBrand('Google'), PhoneBrand.other);
  });
}
