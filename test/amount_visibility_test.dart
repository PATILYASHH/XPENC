import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/widgets/money_text.dart';
import 'package:xpenc/data/database.dart';

/// The eye icon in the top bar flips this, and every amount on screen must
/// mask or reveal instantly — not just the next screen the user opens. Mirrors
/// currency_reactivity_test.dart's harness for the same reason: a live rebuild
/// of an already-mounted [MoneyText], not a fresh one.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AmountVisibilityScope(
        hidden: _hidden,
        child: Scaffold(
          body: Column(
            children: [
              const MoneyText(Money(125050)),
              ElevatedButton(
                onPressed: () => setState(() => _hidden = true),
                child: const Text('hide'),
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

  testWidgets('a live amount masks the instant amounts are hidden',
      (tester) async {
    await tester.pumpWidget(const _Harness());

    expect(find.textContaining('₹1,250.50'), findsOneWidget);
    expect(find.textContaining('•'), findsNothing);

    await tester.tap(find.text('hide'));
    await tester.pump();

    expect(find.textContaining('₹1,250.50'), findsNothing);
    expect(find.textContaining('•'), findsOneWidget);
  });

  testWidgets('the mask never reveals the amount\'s digit count', (tester) async {
    // Two very differently-sized amounts must render an identical mask —
    // otherwise the width alone leaks the order of magnitude.
    Future<String> maskedTextFor(Money amount) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AmountVisibilityScope(
            hidden: true,
            child: Scaffold(body: MoneyText(amount)),
          ),
        ),
      );
      return tester.widget<Text>(find.byType(Text)).data!;
    }

    final small = await maskedTextFor(const Money(500));
    final large = await maskedTextFor(Money.fromRupees(99999999));
    expect(small, large);
  });

  testWidgets('MoneyText defaults to visible with no scope present',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoneyText(Money(125050)))),
    );
    expect(find.textContaining('₹1,250.50'), findsOneWidget);
  });

  group('Settings.hideAmounts persistence', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('defaults to visible', () async {
      expect((await db.getSettings()).hideAmounts, isFalse);
    });

    test('the eye icon toggle persists', () async {
      await db.setHideAmounts(true);
      expect((await db.getSettings()).hideAmounts, isTrue);

      await db.setHideAmounts(false);
      expect((await db.getSettings()).hideAmounts, isFalse);
    });
  });
}
