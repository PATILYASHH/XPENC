import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/core/theme/bar_page_transition.dart';
import 'package:xpenc/core/theme/glass.dart';
import 'package:xpenc/core/theme/theme_preset.dart';
import 'package:xpenc/core/theme/zoom_origin.dart';
import 'package:xpenc/core/widgets/app_surfaces.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/transactions/transaction_detail_screen.dart';

/// Detail pages zoom out of the card or row that was tapped, and shrink
/// back into it on Back (`pushZoom`).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.setShowBottomNavLabels(false);
    ZoomOrigin.debugReset();
  });
  tearDown(() => db.close());

  final glass = AppTheme.of(
    GlassBackdrop.black.palette,
    ThemeStyle.glass.shape,
    backdrop: GlassBackdrop.black,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('a row in a grouped card is its own zoom source', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: glass,
        home: Scaffold(
          body: Center(
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppListTile(title: const Text('First'), onTap: () {}),
                  AppListTile(title: const Text('Second'), onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Second'));
    final from = ZoomOrigin.lastTouched();
    expect(from, isNotNull);
    expect(from!.rect, tester.getRect(find.byType(ListTile).last));
    expect(from.radius, 0);
  });

  testWidgets('a transaction zooms out of its card and back into it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(165),
        accountId: cash,
        date: DateTime.now(),
        payee: 'Blue Tokai',
      );
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 120, bottom: 60);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(theme: glass, routerConfig: appRouter),
      ),
    );
    appRouter.go('/transactions');
    await settle(tester);

    final row = find.text('Blue Tokai').first;
    final card = tester.getRect(
      find.ancestor(of: row, matching: find.byType(ZoomSource)).first,
    );

    await tester.tap(row);
    final transition = find.byType(BarPageTransition);
    for (var f = 0; f < 6 && transition.evaluate().isEmpty; f++) {
      await tester.pump();
    }
    expect(transition, findsOneWidget);
    // The window starts as the card itself.
    final window = find
        .descendant(of: transition, matching: find.byType(GlassPane))
        .first;
    expect(tester.getRect(window).top, closeTo(card.top, 2));
    expect(tester.getRect(window).height, closeTo(card.height, 2));

    await tester.pump(const Duration(milliseconds: 120));
    final growing = tester.getRect(window);
    expect(growing.height, greaterThan(card.height + 40));

    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
    expect(find.byType(TransactionDetailScreen), findsOneWidget);
    expect(tester.getRect(find.byType(TransactionDetailScreen)).width, 360);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(find.byType(TransactionDetailScreen), findsNothing);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
