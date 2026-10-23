import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/skeleton.dart';

void main() {
  testWidgets('placeholders build and sweep without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Skeleton(child: Column(children: [SkeletonCard(lines: 3), SkeletonCard(height: 120)])),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(SkeletonBox), findsNWidgets(2 + 3 + 1));
    expect(tester.takeException(), isNull);
  });
}
