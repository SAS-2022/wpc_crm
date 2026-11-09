import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/short_name.dart';

void main() {
  test('abbreviate', () {
    expect(abbreviate('Wood Panels Co'), 'WPC');
    expect(abbreviate('Wood Panels Service Center'), 'WPSC');
    expect(abbreviate('wood panel service center'), 'WPSC');
    expect(abbreviate('Showroom'), 'Showroom');
    expect(abbreviate('HQ 2'), 'HQ 2');
    expect(abbreviate('Riyadh Site 2'), 'RS2');
    expect(abbreviate('Sales and Marketing Office'), 'SMO');
    expect(abbreviate('Wood-Panels Co.'), 'WPC');
    expect(abbreviate('مستودع الرياض'), 'مستودع الرياض');
  });

  test('clashing short forms keep the full name', () {
    expect(shortLabels({'a': 'Riyadh Site', 'b': 'Riyadh Showroom', 'c': 'Wood Panels Co'}), {
      'a': 'Riyadh Site',
      'b': 'Riyadh Showroom',
      'c': 'WPC',
    });
  });
}
