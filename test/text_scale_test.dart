import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/text_scale.dart';

void main() {
  double scale(double system, double width) => appTextScaler(TextScaler.linear(system), width).scale(1);

  test('narrow screens get slightly smaller text, wide ones the default', () {
    expect(scale(1, 340), closeTo(0.90, 1e-9));
    expect(scale(1, 393), closeTo(0.94, 1e-9));
    expect(scale(1, 1200), 1);
  });

  test("the phone's setting counts, within the limits", () {
    expect(scale(1.1, 393), closeTo(1.034, 1e-9));
    expect(scale(2, 393), maxTextScale);
    expect(scale(0.8, 340), minTextScale);
  });
}
