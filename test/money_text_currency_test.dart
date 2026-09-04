import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/widgets/money_text.dart';

void main() {
  tearDown(() => MoneyFormat.configure(
        currency: kDefaultCurrency,
        showSymbol: true,
      ));

  testWidgets('an explicit currency overrides the globally configured one',
      (tester) async {
    MoneyFormat.configure(currency: currencyForCode('INR'), showSymbol: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoneyText(
            const Money(125050),
            currency: currencyForCode('USD'),
          ),
        ),
      ),
    );

    expect(find.textContaining(r'$'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('omitting currency keeps using the global MoneyFormat, unchanged',
      (tester) async {
    MoneyFormat.configure(currency: currencyForCode('INR'), showSymbol: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MoneyText(Money(125050))),
      ),
    );

    expect(find.textContaining('₹'), findsOneWidget);
  });
}
