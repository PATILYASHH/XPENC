import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/dashboard/dashboard_screen.dart';

/// User feedback: the Spending donut alone didn't say how much went where,
/// and folded the small categories into "Other". The card now lists every
/// category with its exact total for the month — none folded away.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Spending lists every category, with no "Other" row', (
    tester,
  ) async {
    const names = ['Aa', 'Bb', 'Cc', 'Dd', 'Ee', 'Ff', 'Gg'];
    await tester.runAsync(() async {
      await db.setDashboardLayout('spending');
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final now = DateTime.now();
      for (final (i, name) in names.indexed) {
        final id = await db.addCategory(
          name: name,
          kind: CategoryKind.expense,
          colorValue: 0xFF16A34A,
          iconKey: 'other',
        );
        await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(100 * (i + 1)),
          accountId: cash,
          categoryId: id,
          date: DateTime(now.year, now.month, now.day),
        );
      }
    });
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DashboardScreen(),
        ),
      ),
    );
    await settle(tester);

    for (final name in names) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('Other'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
