import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/widgets/nav_bar_inset.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// Glass's top bar: tabs scroll under it to the top of the screen, and the
/// large title hands over to the bar's small one as the tab scrolls.
void main() {
  testWidgets('the large title collapses into the glass bar on scroll', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      // As picking Glass does: the tab bar shows icons only.
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
    appRouter.go('/transactions');
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    await settle();

    // One title, which travels: under the bar at rest, inside the capsule
    // once the tab has scrolled. (Glass's tab bar is icons only, so the
    // bar's title is the only 'Transactions'.)
    final title = find.text('Transactions');
    expect(title, findsOneWidget);
    // The top capsule: the glass around the bar's search button.
    final capsule = find
        .ancestor(
          of: find.byIcon(CupertinoIcons.search),
          matching: find.byType(LiquidGlass),
        )
        .first;
    final restTitle = tester.getRect(title);
    final restCapsule = tester.getRect(capsule);
    expect(restTitle.top, greaterThan(restCapsule.bottom));

    // The tab reaches the top of the screen under the bar.
    expect(find.byType(TopBarInsetSliver), findsOneWidget);
    expect(tester.getTopLeft(find.byType(CustomScrollView).first).dy, 0);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -400),
    );
    await settle();
    final landed = tester.getRect(title);
    final wideCapsule = tester.getRect(capsule);
    expect(landed.center.dy, closeTo(wideCapsule.center.dy, 4));
    expect(landed.left, greaterThan(wideCapsule.left));
    expect(landed.height, lessThan(restTitle.height * 0.6));
    // The capsule stretched across to take it.
    expect(wideCapsule.width, greaterThan(restCapsule.width + 80));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the month button turns the tab bar into the month picker, '
      'and picking a month folds it back', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => db.setShowBottomNavLabels(false));
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
    final now = DateTime.now();
    await tester.tap(find.text(DateFormat('MMM yyyy').format(now)).first);
    await settle();
    // The tab bar is now the picker: the year, and the months.
    expect(find.text('${now.year}'), findsOneWidget);
    expect(find.text('Jan'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.text('Jan')),
    );
    final pick = DateTime(now.year, 1);
    await tester.tap(find.text('Jan'));
    await settle();
    // January may be after the budget cycle's current month only in a
    // pathological clock; otherwise it is selected and the bar folds back.
    if (!pick.isAfter(now)) {
      expect(container.read(selectedMonthProvider), pick);
    }
    expect(find.text('Jan'), findsNothing);

    // Open again, then switch tab: the bar comes back without error.
    await tester.tap(find.text(DateFormat('MMM yyyy').format(pick)).first);
    await settle();
    appRouter.go('/transactions');
    await settle();
    expect(find.text('Jan'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
