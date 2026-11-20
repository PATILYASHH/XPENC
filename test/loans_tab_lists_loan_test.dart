import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// A loan listed on the Dashboard must be listed on Goals & Loans → Loans
/// too. Backups from before 1.6.5 had no `loanDetails`, so restoring one
/// brought each loan's account back without the row the Loans tab lists
/// loans by. The app now gives such a loan a basic row back.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId(AppDatabase db) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  /// A loan with an EMI Auto rule, then a backup of it as 1.6.4 wrote it:
  /// no `loanDetails` key at all.
  Future<Map<String, dynamic>> oldBackupWithLoan() async {
    await db.addLoan(
      name: 'Education Loan',
      principal: Money.fromRupees(135000),
      colorValue: 0xFF2563EB,
      iconKey: 'education',
      interestRatePct: 9,
      tenureMonths: 60,
      startDate: DateTime(2026, 9, 25),
      autoPayFromAccountId: await cashId(db),
      autoPayStartsOn: DateTime(2026, 12, 25),
    );
    final backup = await db.exportAll();
    return backup..remove('loanDetails');
  }

  test(
    'restoring a pre-1.6.5 backup keeps its loans on the Loans tab',
    () async {
      final backup = await oldBackupWithLoan();
      final restored = AppDatabase(NativeDatabase.memory());
      addTearDown(restored.close);
      await restored.importAll(backup);

      final details = await restored.watchLoanDetails().first;
      final loan = (await restored.watchAccounts().first).singleWhere(
        (a) => a.type == AccountType.loan,
      );
      expect(details.map((d) => d.accountId), [loan.id]);
      // The EMI is taken from the Auto rule that pays the loan.
      final rule =
          (await restored.select(restored.recurringRules).get()).single;
      expect(details.single.emiAmount, rule.amount);
      expect(details.single.categoryId, rule.categoryId);
      // The rate is gone with the backup; the loan is a basic one until edited.
      expect(details.single.interestRatePct, isNull);
    },
  );

  test('a loan without its row is repaired when the app opens', () async {
    final dir = await Directory.systemTemp.createTemp('xpenc_loans_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    var opened = AppDatabase(NativeDatabase(file));
    await opened
        .into(opened.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'Home Loan',
            type: AccountType.loan,
            colorValue: 0xFF2563EB,
            iconKey: 'home',
            openingBalance: Money.fromRupees(-20000),
            currentBalance: Money.fromRupees(-20000),
            isArchived: const Value(false),
          ),
        );
    // A loan account with no loan row, as an old restore left it.
    expect(await opened.watchLoanDetails().first, isEmpty);
    await opened.close();

    opened = AppDatabase(NativeDatabase(file));
    addTearDown(opened.close);
    final details = await opened.watchLoanDetails().first;
    expect(details, hasLength(1));
    expect(details.single.emiAmount, isNull);
  });

  test('the repair leaves loans that have their row alone', () async {
    await oldBackupWithLoan();
    final before = await db.watchLoanDetails().first;
    expect(await db.repairLoansWithoutDetails(), 0);
    expect(await db.watchLoanDetails().first, before);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  for (final glass in [false, true]) {
    testWidgets('a restored loan is listed on the Loans tab (glass: $glass)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final backup = await oldBackupWithLoan();
        await db.importAll(backup);
      });
      tester.view.physicalSize = const Size(360, 780) * 3;
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 120, bottom: 60);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: glass
                ? AppTheme.of(
                    GlassBackdrop.black.palette,
                    ThemeStyle.glass.shape,
                    backdrop: GlassBackdrop.black,
                  )
                : AppTheme.light,
            routerConfig: appRouter,
          ),
        ),
      );
      appRouter.go('/more/goals');
      await settle(tester);
      await tester.tap(find.text('Loans').last);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Education Loan').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
