import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/features/attendance/hours_bar.dart';

void main() {
  testWidgets('bar has width inside a ListTile subtitle', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          ListTile(
            title: const Text('A'),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              HoursBar(
                split: hoursSplit(workedMin: 645, overtimeMin: 95, scheduledMin: 550),
                normalColor: Colors.blue,
                overtimeColor: Colors.purple,
              ),
            ]),
            trailing: const Text('10 h'),
          ),
        ]),
      ),
    ));
    final size = t.getSize(find.byType(HoursBar));
    expect(size.width, greaterThan(100));
    expect(size.height, 8);
  });
}
