import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client_widgets.dart';

/// How a salesperson is shown next to their clients: initials on a colour.
typedef PersonStyle = ({String initials, Color color});

/// Colours for salespeople, distinct from the visit status colours
/// (green / yellow / red / blue).
const personPalette = [
  Color(0xFF00897B), // teal
  Color(0xFF7B1FA2), // purple
  Color(0xFFE65100), // dark orange
  Color(0xFF3949AB), // indigo
  Color(0xFFC2185B), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF0097A7), // cyan
  Color(0xFF827717), // olive
  Color(0xFF455A64), // blue grey
  Color(0xFF5E35B1), // deep purple
  Color(0xFFAD1457), // raspberry
  Color(0xFF2E7D32), // forest
];

/// Clients without a salesperson.
const unassignedStyle = (initials: '–', color: Color(0xFF9E9E9E));

/// Up to two initials, or "?".
String initialsOf(String name) {
  final letters = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w.characters.first.toUpperCase())
      .join();
  return letters.isEmpty ? '?' : letters;
}

/// Gives each id a palette slot: its hash picks the slot, taken slots move to
/// the next free one (ids in sorted order), so a person keeps their colour
/// when others are added. Repeats only past [personPalette]'s length.
Map<String, int> paletteSlots(Iterable<String> ids) {
  final sorted = ids.toSet().toList()..sort();
  final taken = <int>{};
  final slots = <String, int>{};
  for (final id in sorted) {
    var slot = id.codeUnits.fold<int>(0, (h, c) => (h * 31 + c) & 0x7fffffff) % personPalette.length;
    if (taken.length < personPalette.length) {
      while (taken.contains(slot)) {
        slot = (slot + 1) % personPalette.length;
      }
    }
    taken.add(slot);
    slots[id] = slot;
  }
  return slots;
}

/// Style per salesperson uid, for everyone the client filter lists.
final personStylesProvider = Provider<Map<String, PersonStyle>>((ref) {
  final people = ref.watch(clientOwnersProvider);
  final slots = paletteSlots(people.map((u) => u.id));
  return {
    for (final u in people) u.id: (initials: initialsOf(u.name), color: personPalette[slots[u.id]!]),
  };
});

/// Small round badge with the salesperson's initials (grey "–" when unassigned).
class PersonBadge extends ConsumerWidget {
  const PersonBadge({super.key, required this.userId, required this.name, this.size = 28});

  final String? userId;

  /// Shown as the tooltip.
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(personStylesProvider)[userId] ?? unassignedStyle;
    return Tooltip(
      message: name,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
        child: Text(
          style.initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4),
        ),
      ),
    );
  }
}
