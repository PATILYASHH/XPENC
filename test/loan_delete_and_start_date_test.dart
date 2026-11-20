import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/savings/loan_detail_screen.dart';

/// Reported on 1.6.4: a loan with no history couldn't be deleted (its
/// LoanDetails row tripped the foreign key, and the screen only caught
/// ArgumentError, so the tap did nothing), and a past repayment start date
/// came back as today after saving a loan without an interest rate.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> loan({DateTime? startDate}) => db.addLoan(
    name: 'Bike loan',
    principal: Money.fromRupees(50000),
    colorValue: 0xFFEF4444,
    iconKey: 'loan',
    startDate: startDate,
  );

  Future<int> bank() => db.addAccount(
    name: 'HDFC',
    type: AccountType.bank,
    colorValue: 0xFF2563EB,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(100000),
  );

  group('deleting', () {
    test('a loan nothing has touched', () async {
      final id = await loan();
      await db.deleteAccount(id);
      expect(await db.watchAccount(id).first, isNull);
      expect(await db.getLoanDetail(id), isNull);
    });

    test('a loan takes its never-posted Auto-pay EMI rule with it', () async {
      final from = await bank();
      final id = await db.addLoan(
        name: 'Car loan',
        principal: Money.fromRupees(50000),
        colorValue: 0xFFEF4444,
        iconKey: 'loan',
        emiAmount: Money.fromRupees(5000),
        autoPayFromAccountId: from,
        autoPayStartsOn: DateTime.now().add(const Duration(days: 20)),
      );
      final rule = (await db.watchRecurringRules().first).single;
      expect(rule.toAccountId, id);
      final tag = await db.addTag(name: 'emi', colorValue: 0xFF22C55E);
      await db.setRecurringRuleTags(rule.id, {tag});

      await db.deleteAccount(id);
      expect(await db.watchAccount(id).first, isNull);
      expect(await db.watchRecurringRules().first, isEmpty);
      expect(await db.watchAccount(from).first, isNotNull);
    });

    test('a goal takes the Auto rule that saves into it', () async {
      final from = await bank();
      final goal = await db.addGoal(
        name: 'Laptop',
        targetAmount: Money.fromRupees(80000),
        colorValue: 0xFFA855F7,
        iconKey: 'savings',
      );
      await db.addRecurringRule(
        name: 'Laptop SIP',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(2000),
        accountId: from,
        toAccountId: goal,
        frequency: RecurringFrequency.monthly,
        startsOn: DateTime.now().add(const Duration(days: 5)),
      );
      await db.deleteAccount(goal);
      expect(await db.watchAccount(goal).first, isNull);
      expect(await db.watchRecurringRules().first, isEmpty);
    });

    test('a loan with a payment still refuses — archive it instead', () async {
      final from = await bank();
      final id = await loan();
      await db.addLoanPayment(
        sourceAccountId: from,
        loanAccountId: id,
        amount: Money.fromRupees(1000),
        date: DateTime.now(),
      );
      await expectLater(db.deleteAccount(id), throwsArgumentError);
      expect(await db.watchAccount(id).first, isNotNull);
    });

    test(
      'a bank account an Auto rule pays into refuses with a message',
      () async {
        final from = await bank();
        final to = await bank();
        await db.addRecurringRule(
          name: 'Rent pot',
          kind: CategoryKind.expense,
          amount: Money.fromRupees(2000),
          accountId: from,
          toAccountId: to,
          frequency: RecurringFrequency.monthly,
          startsOn: DateTime.now().add(const Duration(days: 5)),
        );
        await expectLater(db.deleteAccount(to), throwsArgumentError);
        expect(await db.watchRecurringRules().first, hasLength(1));
      },
    );

    test('two reminders on one account refuse with a message, not a '
        'StateError', () async {
      final id = await bank();
      for (final title in ['Rent', 'Gym']) {
        await db.addReminder(
          title: title,
          direction: ReminderDirection.pay,
          dueDate: DateTime.now().add(const Duration(days: 3)),
          accountId: id,
        );
      }
      await expectLater(db.deleteAccount(id), throwsArgumentError);
    });

    testWidgets('from the loan page, the loan goes and the page closes', (
      tester,
    ) async {
      late int id;
      await tester.runAsync(() async => id = await loan());
      await _pump(tester, db, LoanDetailScreen(accountId: id));

      await tester.tap(find.byTooltip('More'));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settle(tester);
      expect(find.text('Loan deleted'), findsWidgets);
      // Let the page's exit transition finish.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoanDetailScreen), findsNothing);
      final gone = await tester.runAsync(() => db.watchAccount(id).first);
      expect(gone, isNull);
      await _unmount(tester);
    });
  });

  testWidgets('a rate-less loan keeps its past repayment start date', (
    tester,
  ) async {
    late int id;
    await tester.runAsync(
      () async => id = await loan(startDate: DateTime(2024, 3, 5)),
    );
    await _pump(tester, db, LoanDetailScreen(accountId: id));

    await tester.tap(find.byTooltip('Edit'));
    await _settle(tester);
    expect(find.text('Tue, 5 Mar 2024'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);

    final detail = await tester.runAsync(() => db.getLoanDetail(id));
    expect(detail!.startDate, DateTime(2024, 3, 5));
    expect(detail.interestRatePct, isNull);
    await _unmount(tester);
  });
}

Future<void> _pump(WidgetTester tester, AppDatabase db, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dbProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('home')),
          ),
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('home')),
            ),
            MaterialPageRoute<void>(builder: (_) => screen),
          ],
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}
