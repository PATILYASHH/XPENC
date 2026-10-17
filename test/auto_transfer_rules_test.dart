import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/auto/auto_screen.dart';
import 'package:xpenc/features/auto/recurring_rule_sheet.dart';

/// Auto rules that move money between the person's own accounts — bank to
/// cash, onto a credit card, into a goal or towards a loan.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<Money> balanceOf(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

  Future<int> addBank({String? currencyCode}) => db.addAccount(
    name: currencyCode == null ? 'HDFC' : 'Wise USD',
    type: AccountType.bank,
    colorValue: 0,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(10000),
    currencyCode: currencyCode,
  );

  Future<int> addRule(int from, int to, {int? categoryId}) =>
      db.addRecurringRule(
        name: 'Rule',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(2000),
        accountId: from,
        toAccountId: to,
        categoryId: categoryId,
        frequency: RecurringFrequency.monthly,
        startsOn: DateTime(2026, 7, 1),
      );

  test('bank to cash: posts a transfer and moves both balances', () async {
    final bank = await addBank();
    final cash = await cashId();
    final rule = await addRule(bank, cash);

    expect(await db.runDueRecurringRules(now: DateTime(2026, 7, 1)), 1);

    expect(await balanceOf(bank), Money.fromRupees(8000));
    expect(await balanceOf(cash), Money.fromRupees(2000));
    final tx = (await db.watchTransactions().first).single;
    expect(tx.type, TxType.transfer);
    expect(tx.accountId, bank);
    expect(tx.toAccountId, cash);
    expect(tx.categoryId, isNull);
    expect(tx.recurringRuleId, rule);
  });

  test('paying a credit card bill brings its balance back up', () async {
    final bank = await addBank();
    final card = await db.addAccount(
      name: 'Amex',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0,
      iconKey: 'card',
      openingBalance: Money.fromRupees(-5000),
    );
    await addRule(bank, card);

    await db.runDueRecurringRules(now: DateTime(2026, 7, 1));

    expect(await balanceOf(card), Money.fromRupees(-3000));
    expect(await balanceOf(bank), Money.fromRupees(8000));
  });

  group('refused up front', () {
    test('the same account on both ends', () async {
      final cash = await cashId();
      await expectLater(addRule(cash, cash), throwsArgumentError);
    });

    test('a category on a transfer between everyday accounts', () async {
      final bank = await addBank();
      final food =
          (await db.watchCategories(CategoryKind.expense).first).first.id;
      await expectLater(
        addRule(bank, await cashId(), categoryId: food),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no category'),
          ),
        ),
      );
    });

    test('an archived destination', () async {
      final bank = await addBank();
      await db.archiveAccount(bank);
      await expectLater(addRule(await cashId(), bank), throwsArgumentError);
    });

    test('a foreign-currency account with no exchange rate yet', () async {
      final usd = await addBank(currencyCode: 'USD');
      await expectLater(
        addRule(await cashId(), usd),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('exchange rate'),
          ),
        ),
      );

      await db.addCurrencyRate(
        currencyCode: 'USD',
        rateToBaseMicros: 84000000,
        effectiveAt: DateTime(2026, 6, 1),
      );
      expect(await addRule(await cashId(), usd), isPositive);
    });
  });

  group('screens', () {
    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: home,
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('the rule sheet offers Transfer, to any account', (
      tester,
    ) async {
      await tester.runAsync(addBank);
      await pump(tester, const Scaffold(body: RecurringRuleSheet()));
      expect(find.text('G&L'), findsNothing);

      await tester.tap(find.text('Transfer'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('To account'), findsOneWidget);
      // Everyday accounts have no category to pick.
      expect(find.text('Category (optional)'), findsNothing);
      expect(find.text('Category'), findsNothing);
      await unmount(tester);
    });

    testWidgets('the Auto screen lists them under Transfers', (tester) async {
      await tester.runAsync(() async {
        await addRule(await addBank(), await cashId());
      });
      await pump(tester, const AutoScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('TRANSFERS'), findsOneWidget);
      expect(find.textContaining('HDFC → Cash'), findsOneWidget);
      await unmount(tester);
    });
  });
}
