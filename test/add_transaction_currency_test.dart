import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/widgets/amount_keypad_field.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {TxType? initialType}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AddTransactionScreen(initialType: initialType),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  /// Opens the "Paid via"/account picker and taps the account named [name].
  Future<void> pickAccount(WidgetTester tester, String name) async {
    await tester.tap(find.text('Select account').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(name));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'the hero amount renders in the selected account\'s own currency',
    (tester) async {
      await db.addAccount(
        name: 'Travel',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
        currencyCode: 'USD',
      );

      await pump(tester, initialType: TxType.expense);
      await pickAccount(tester, 'Travel');

      final amountText = tester.widget<Text>(
        find.byKey(const Key('amountDisplay')),
      );
      expect(amountText.data, contains(r'$'));
      expect(amountText.data, isNot(contains('₹')));

      await unmount(tester);
    },
  );

  testWidgets(
    "the #85 'Foreign currency' toggle is hidden once the account has its "
    'own currency',
    (tester) async {
      await db.addAccount(
        name: 'Home wallet',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );
      await db.addAccount(
        name: 'Travel',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
        currencyCode: 'USD',
      );

      await pump(tester, initialType: TxType.expense);

      await pickAccount(tester, 'Home wallet');
      expect(find.text('Foreign currency'), findsOneWidget);

      await tester.tap(find.text('Home wallet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Travel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Foreign currency'), findsNothing);

      await unmount(tester);
    },
  );

  group('#195 a saved rate fills in the amount from the foreign amount', () {
    Future<void> openForeignMyr(WidgetTester tester) async {
      await db.addAccount(
        name: 'Home wallet',
        type: AccountType.cash,
        colorValue: 0xFF000000,
        iconKey: 'cash',
        openingBalance: const Money.zero(),
      );
      await pump(tester, initialType: TxType.expense);
      await pickAccount(tester, 'Home wallet');

      await tester.ensureVisible(find.text('Foreign currency'));
      await tester.tap(find.text('Foreign currency'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The editor's currency chip starts on the parent currency.
      await tester.ensureVisible(find.text('INR').last);
      await tester.tap(find.text('INR').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField).last, 'MYR');
      await tester.pump();
      await tester.tap(find.text('Malaysian Ringgit').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Make the foreign amount the keypad's target.
      await tester.ensureVisible(find.byType(AmountKeypadDisplayBox).last);
      await tester.tap(find.byType(AmountKeypadDisplayBox).last);
      await tester.pump();
    }

    Future<void> typeKeys(WidgetTester tester, String keys) async {
      for (final k in keys.split('')) {
        await tester.tap(
          find.descendant(
            of: find.byType(AmountKeypadGrid),
            matching: find.text(k),
          ),
        );
        await tester.pump();
      }
    }

    String heroAmount(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('amountDisplay'))).data!;

    testWidgets('typing 100 MYR at 0.30 fills in ₹30', (tester) async {
      await tester.runAsync(
        () => db.addCurrencyRate(
          currencyCode: 'MYR',
          rateToBaseMicros: 300000,
          effectiveAt: DateTime(2026, 1, 1),
        ),
      );
      await openForeignMyr(tester);

      await typeKeys(tester, '100');
      expect(heroAmount(tester), contains('30'));
      expect(find.textContaining('At your saved rate'), findsOneWidget);

      // Clearing the foreign amount clears what the rate wrote.
      await tester.tap(find.byType(AmountKeypadDisplayBox).last);
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.descendant(
            of: find.byType(AmountKeypadGrid),
            matching: find.byIcon(Icons.backspace_outlined),
          ),
        );
        await tester.pump();
      }
      expect(heroAmount(tester), isNot(contains('30')));

      await unmount(tester);
    });

    testWidgets('an amount typed over the converted one is kept', (
      tester,
    ) async {
      await tester.runAsync(
        () => db.addCurrencyRate(
          currencyCode: 'MYR',
          rateToBaseMicros: 300000,
          effectiveAt: DateTime(2026, 1, 1),
        ),
      );
      await openForeignMyr(tester);
      await typeKeys(tester, '100');

      await tester.tap(find.byKey(const Key('amountDisplay')));
      await tester.pump();
      await typeKeys(tester, '28');
      expect(heroAmount(tester), contains('28'));
      expect(find.textContaining('works out to'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('with no saved rate, nothing is filled in and it says why', (
      tester,
    ) async {
      await openForeignMyr(tester);
      await typeKeys(tester, '100');

      expect(heroAmount(tester), isNot(contains('100')));
      expect(find.textContaining('No MYR rate saved yet'), findsOneWidget);

      await unmount(tester);
    });
  });
}
