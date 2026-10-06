import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
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
            GlassBackdrop.aurora.palette,
            ThemeStyle.glass.shape,
            backdrop: GlassBackdrop.aurora,
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

    // Both titles exist: the large one under the bar, the small one in it.
    double opacityOf(Finder text) => tester
        .widget<Opacity>(
          find.ancestor(of: text, matching: find.byType(Opacity)).first,
        )
        .opacity;
    final titles = find.text('Transactions');
    // The tab bar's label is a third 'Transactions'; the bar's two come
    // first in paint order (large, then small).
    expect(titles, findsAtLeastNWidgets(2));
    final large = titles.at(0);
    final small = titles.at(1);
    expect(opacityOf(large), closeTo(1, 0.01));
    expect(opacityOf(small), closeTo(0, 0.01));

    // The tab reaches the top of the screen under the bar.
    expect(find.byType(TopBarInsetSliver), findsOneWidget);
    expect(tester.getTopLeft(find.byType(CustomScrollView).first).dy, 0);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -400),
    );
    await settle();
    expect(opacityOf(large), closeTo(0, 0.01));
    expect(opacityOf(small), closeTo(1, 0.01));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
