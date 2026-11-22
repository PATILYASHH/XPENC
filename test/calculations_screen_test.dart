import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/features/calculators/calculations_screen.dart';
import 'package:xpenc/features/calculators/calculator_kind.dart';
import 'package:xpenc/features/calculators/world_tax_bodies.dart';

/// More → Calculations: every calculator on one page; GST, PPF and India's
/// income tax only for someone in rupees.
void main() {
  test('₹ is India; anything else is not', () {
    expect(indiaToolsFor('INR'), isTrue);
    expect(indiaToolsFor('USD'), isFalse);
    expect(indiaToolsFor('EUR'), isFalse);
  });

  test('outside ₹, India drops off the calculator list', () {
    expect(CalculatorKind.shownFor(india: true), CalculatorKind.values);
    expect(CalculatorKind.shownFor(india: false), [
      CalculatorKind.deposit,
      CalculatorKind.loan,
      CalculatorKind.incomeTax,
      CalculatorKind.sip,
    ]);
    expect(
      CalculatorKind.incomeTax.subtitleFor(india: false),
      isNot(contains('India')),
    );
  });

  test('Income Tax offers India only in ₹, and opens on your country', () {
    expect(TaxCountry.offeredFor('INR'), TaxCountry.values);
    expect(TaxCountry.offeredFor('USD'), isNot(contains(TaxCountry.india)));
    expect(TaxCountry.forCurrency('INR'), TaxCountry.india);
    expect(TaxCountry.forCurrency('GBP'), TaxCountry.uk);
    // A currency with no tax table of its own isn't ₹: not India.
    expect(TaxCountry.forCurrency('AUD'), TaxCountry.us);
  });

  for (final india in [true, false]) {
    testWidgets('the page lists ${india ? 'every' : 'the non-Indian'} '
        'calculator, by section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [indiaToolsProvider.overrideWithValue(india)],
          child: const MaterialApp(home: CalculationsScreen()),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final kind in CalculatorKind.values) {
        expect(
          find.byKey(ValueKey('calculation:${kind.name}')),
          india || !kind.indiaOnly ? findsOneWidget : findsNothing,
          reason: kind.name,
        );
      }
      expect(find.text('SAVE & GROW'), findsOneWidget);
      expect(find.text('BORROW'), findsOneWidget);
      expect(find.text('TAX'), findsOneWidget);
      // Outside ₹ the page says where the Indian ones went.
      expect(
        find.text('Calculators for India'),
        india ? findsNothing : findsOneWidget,
      );
    });
  }
}
