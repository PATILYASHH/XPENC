import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/widgets/money_text.dart';

/// A change of currency must reformat amounts already on screen — not just the
/// next screen the user opens. This mirrors how `app.dart` reconfigures
/// [MoneyFormat] and rebuilds the [CurrencyScope] that [MoneyText] depends on.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _usd = false;

  @override
  Widget build(BuildContext context) {
    final currency = _usd ? currencyForCode('USD') : kDefaultCurrency;
    MoneyFormat.configure(currency: currency, showSymbol: true);

    return MaterialApp(
      home: CurrencyScope(
        currency: currency,
        showSymbol: true,
        child: Scaffold(
          body: Column(
            children: [
              const MoneyText(Money(125050)),
              ElevatedButton(
                onPressed: () => setState(() => _usd = true),
                child: const Text('switch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  tearDown(() => MoneyFormat.configure(
        currency: kDefaultCurrency,
        showSymbol: true,
      ));

  testWidgets('a live amount reformats when the currency changes',
      (tester) async {
    await tester.pumpWidget(const _Harness());

    expect(find.textContaining('₹'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);

    await tester.tap(find.text('switch'));
    await tester.pump();

    expect(find.textContaining(r'$'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });
}
