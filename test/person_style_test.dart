import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/clients/person_style.dart';

void main() {
  test('initials: first letters of the first two words, upper case', () {
    expect(initialsOf('Sami Mansour'), 'SM');
    expect(initialsOf('  majed   arnous el x '), 'MA');
    expect(initialsOf('Bob'), 'B');
    expect(initialsOf(''), '?');
  });

  test('every person gets their own colour while the palette lasts', () {
    final ids = [for (var i = 0; i < personPalette.length; i++) 'uid$i'];
    expect(paletteSlots(ids).values.toSet(), hasLength(personPalette.length));
  });

  test('colours do not depend on the order people are listed in', () {
    expect(paletteSlots(['b', 'a', 'c']), paletteSlots(['c', 'b', 'a']));
  });
}
