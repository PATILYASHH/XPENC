import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/dashboard/month_picker_sheet.dart';

/// The Dashboard hero card's Loan tab used to sum pay-later accounts only,
/// so a real loan from the Loans module (and anything owed to a person)
/// never showed up. [debtTrendProvider] sums all three.
void main() {
  group('debtTrendProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [dbProvider.overrideWithValue(db)],
      );
    });

    tearDown(() {
      container.dispose();
      return db.close();
    });

    Future<void> warmUp() async {
      const timeout = Duration(seconds: 5);
      await container.read(allTransactionsProvider.future).timeout(timeout);
      await container.read(balanceAccountsProvider.future).timeout(timeout);
      await container.read(allPersonEntriesProvider.future).timeout(timeout);
    }

    test('counts loans, pay later and what you owe people — not what '
        'people owe you', () async {
      final food = (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;
      await db.addLoan(
        name: 'Home Loan',
        principal: Money.fromRupees(100000),
        colorValue: 0,
        iconKey: 'loan',
      );
      final simpl = await db.addAccount(
        name: 'Simpl',
        type: AccountType.payLater,
        colorValue: 0,
        iconKey: 'card',
        openingBalance: const Money.zero(),
      );
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(800),
        accountId: simpl,
        categoryId: food,
        date: DateTime.now(),
      );
      final ravi = await db.addPerson('Ravi');
      final sita = await db.addPerson('Sita');
      await db.addPersonEntry(
        personId: ravi,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(2000),
        date: DateTime.now(),
      );
      // Sita owes me — must not reduce what I owe Ravi.
      await db.addPersonEntry(
        personId: sita,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(5000),
        date: DateTime.now(),
      );
      await warmUp();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final now = container.read(debtTrendProvider(6)).last;
      expect(now.loans, Money.fromRupees(100000));
      expect(now.payLater, Money.fromRupees(800));
      expect(now.people, Money.fromRupees(2000));
      expect(now.total, Money.fromRupees(102800));
    });
  });

  group('MonthPickerSheet', () {
    Future<DateTime?> pickFrom(
      WidgetTester tester, {
      required DateTime selected,
      required DateTime current,
      required String tap,
    }) async {
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showMonthPickerSheet(
                  context,
                  selected: selected,
                  current: current,
                  startDay: 1,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('picking a month returns that month', (tester) async {
      final picked = await pickFrom(
        tester,
        selected: DateTime(2026, 9),
        current: DateTime(2026, 9),
        tap: 'Mar',
      );
      expect(picked, DateTime(2026, 3));
    });

    testWidgets('months after the current one cannot be picked', (
      tester,
    ) async {
      final picked = await pickFrom(
        tester,
        selected: DateTime(2026, 9),
        current: DateTime(2026, 9),
        tap: 'Nov',
      );
      expect(picked, isNull);
      expect(find.text('Nov'), findsOneWidget, reason: 'sheet stays open');
    });

    testWidgets('"This month" jumps back to the current month', (tester) async {
      final picked = await pickFrom(
        tester,
        selected: DateTime(2025, 4),
        current: DateTime(2026, 9),
        tap: 'This month',
      );
      expect(picked, DateTime(2026, 9));
    });
  });
}
