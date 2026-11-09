import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wpc_crm/core/city_areas.dart';
import 'package:wpc_crm/l10n/app_localizations.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets('region chips fill a 320 px phone row ($lang)', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RegionChips(fill: true, selected: SaudiRegion.central, onSelected: (_) {}),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final chips = tester.widgetList(find.byType(ChoiceChip)).length;
      expect(chips, 3);
      final w = tester.getSize(find.byType(ChoiceChip).first).width;
      expect(w, greaterThan(80));
    });
  }
}
