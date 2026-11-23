import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/money_text.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/dashboard/pinned_total.dart';

/// Once Total money scrolls up under the top bar, the bar shows its figure
/// in place of the "Dashboard" title — paise smaller — and gives the title
/// back when it scrolls into view again.
void main() {
  testWidgets('MoneyText draws the paise smaller with fractionScale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MoneyText(
          Money.fromRupees(1234.5),
          style: const TextStyle(fontSize: 20),
          fractionScale: 0.5,
        ),
      ),
    );
    final rich = tester.widget<RichText>(find.byType(RichText).last);
    final span = (rich.text as TextSpan).children!.single as TextSpan;
    final fraction = span.children!.single as TextSpan;
    expect(fraction.text, startsWith('.'));
    expect(fraction.style!.fontSize, 10);
    expect('${span.text}${fraction.text}', contains('1,234.50'));
  });

  testWidgets('the Dashboard title becomes Total money once the card has '
      'scrolled away, and comes back with it', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      await db.setShowBottomNavLabels(false);
      final cat = (await db.watchCategories(CategoryKind.expense).first).first;
      for (var i = 0; i < 20; i++) {
        await db.addTransaction(
          type: TxType.expense,
          amount: Money.fromRupees(100 + i),
          accountId: cash,
          categoryId: cat.id,
          date: DateTime.now().subtract(Duration(hours: i)),
        );
      }
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 120);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.of(
            GlassBackdrop.black.palette,
            ThemeStyle.glass.shape,
            backdrop: GlassBackdrop.black,
          ),
          routerConfig: appRouter,
        ),
      ),
    );
    appRouter.go('/dashboard');
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    await settle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(PinnedTotalTitle), findsNothing);
    expect(dashboardPinnedTotal.value, isNull);

    final list = find.byType(CustomScrollView).first;
    await tester.drag(list, const Offset(0, -600));
    await settle();
    expect(dashboardPinnedTotal.value, isNotNull);
    expect(find.byType(PinnedTotalTitle), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);

    await tester.drag(list, const Offset(0, 1200));
    await settle();
    expect(dashboardPinnedTotal.value, isNull);
    expect(find.byType(PinnedTotalTitle), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
