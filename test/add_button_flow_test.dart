import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// The ➕ in the real shell: a tap opens Add Transaction — or, once a
/// template exists, the "blank or template" sheet, whose either choice must
/// still land on Add Transaction.
void main() {
  Future<AppDatabase> seed({required bool withTemplate}) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.setShowBottomNavLabels(false);
    if (withTemplate) {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final txId = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(99),
        accountId: cash,
        date: DateTime.now(),
      );
      await db.createTemplateFromTransaction(
        transactionId: txId,
        name: 'Snacks',
      );
    }
    return db;
  }

  for (final glass in [true, false]) {
    final style = glass ? 'Glass' : 'Classic';

    Future<void> pumpShell(WidgetTester tester, AppDatabase db) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 120);
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
      appRouter.go('/dashboard');
      await settle(tester);
    }

    Finder addButton() => glass
        ? find.byWidgetPredicate(
            (w) => w is GlassButton && w.semanticLabel == 'Add',
          )
        : find.byIcon(Icons.add_rounded);

    testWidgets('$style: ➕ with no templates opens Add Transaction', (
      tester,
    ) async {
      final db = (await tester.runAsync(() => seed(withTemplate: false)))!;
      addTearDown(db.close);
      await pumpShell(tester, db);

      await tester.tap(addButton());
      await settle(tester);
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: ➕ → Start from scratch opens Add Transaction', (
      tester,
    ) async {
      final db = (await tester.runAsync(() => seed(withTemplate: true)))!;
      addTearDown(db.close);
      await pumpShell(tester, db);

      await tester.tap(addButton());
      await settle(tester);
      expect(find.text('Start from scratch'), findsOneWidget);
      await tester.tap(find.text('Start from scratch'));
      await settle(tester);
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$style: ➕ → a template opens Add Transaction prefilled', (
      tester,
    ) async {
      final db = (await tester.runAsync(() => seed(withTemplate: true)))!;
      addTearDown(db.close);
      await pumpShell(tester, db);

      await tester.tap(addButton());
      await settle(tester);
      expect(find.text('Snacks'), findsOneWidget);
      await tester.tap(find.text('Snacks'));
      await settle(tester);
      final screen = tester.widget<AddTransactionScreen>(
        find.byType(AddTransactionScreen),
      );
      expect(screen.templateId, isNotNull);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
