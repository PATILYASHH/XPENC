import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/features/calculators/calculator_kind.dart';
import 'package:xpenc/features/calculators/calculator_screen.dart';
import 'package:xpenc/features/calculators/world_tax_bodies.dart';

void main() {
  for (final kind in CalculatorKind.values) {
    testWidgets('${kind.label} calculator renders and recomputes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: CalculatorScreen(kind: kind)));
      expect(tester.takeException(), isNull);
      expect(find.text('BETA'), findsOneWidget);

      // Clearing the first field must not throw (blank input reads as 0).
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Income Tax switches between every country', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: CalculatorScreen(kind: CalculatorKind.incomeTax)),
    );
    for (final c in TaxCountry.values) {
      await tester.tap(find.byType(DropdownButtonFormField<TaxCountry>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${c.flag}  ${c.label}').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final body = switch (c) {
        TaxCountry.india => find.textContaining('Old regime deductions'),
        TaxCountry.us => find.byType(UsTaxBody),
        TaxCountry.uk => find.byType(UkTaxBody),
        TaxCountry.germany => find.byType(GermanyTaxBody),
      };
      expect(body, findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.textContaining('More countries will be added'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('More countries will be added'), findsOneWidget);
  });
}
