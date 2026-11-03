import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';

/// #190: arrange accounts — the order the Dashboard and Accounts show them
/// in is the user's, set by dragging, and a new account joins the end.
void main() {
  late AppDatabase db;
  late int cash;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    cash = (await db.watchAccounts().first).single.id;
  });
  tearDown(() => db.close());

  Future<int> bank(String name) => db.addAccount(
    name: name,
    type: AccountType.bank,
    colorValue: 0xFF1E88E5,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(1000),
  );

  Future<List<String>> names() async => [
    for (final a in await db.watchAccounts().first) a.name,
  ];

  test('a new account joins the end of the order', () async {
    await bank('HDFC');
    await bank('SBI');
    expect(await names(), ['Cash', 'HDFC', 'SBI']);
  });

  test('reordering sets the order everywhere it is shown', () async {
    final hdfc = await bank('HDFC');
    final sbi = await bank('SBI');
    await db.reorderAccounts([sbi, cash, hdfc]);
    expect(await names(), ['SBI', 'Cash', 'HDFC']);
    expect(
      [for (final a in await db.watchBalanceHoldingAccounts().first) a.name],
      ['SBI', 'Cash', 'HDFC'],
    );
    // And it holds once another account arrives.
    await bank('ICICI');
    expect(await names(), ['SBI', 'Cash', 'HDFC', 'ICICI']);
  });

  test('accounts left out of a reorder keep their places', () async {
    final hdfc = await bank('HDFC');
    // A debit card mirrors HDFC and isn't on the Dashboard's list.
    await db.addAccount(
      name: 'HDFC Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: hdfc,
      colorValue: 0xFF1E88E5,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    final sbi = await bank('SBI');
    expect(await names(), ['Cash', 'HDFC', 'HDFC Debit', 'SBI']);

    await db.reorderAccounts([sbi, hdfc, cash]);
    expect(await names(), ['SBI', 'HDFC', 'HDFC Debit', 'Cash']);
  });

  testWidgets('hold an account on the Dashboard to arrange them', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await bank('HDFC');
      await bank('SBI');
    });
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    appRouter.go('/dashboard');
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    await settle();
    // The accounts strip sits below the fold.
    await tester.scrollUntilVisible(
      find.text('HDFC').hitTestable(),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(find.text('HDFC').hitTestable().first);
    await settle();
    expect(find.text('Arrange accounts'), findsOneWidget);

    // Drag SBI (last) by its handle to the top of the list.
    final sheet = find.ancestor(
      of: find.text('Arrange accounts'),
      matching: find.byType(Column),
    );
    final sbi = find.descendant(of: sheet.last, matching: find.text('SBI'));
    final handle = find.descendant(
      of: find.ancestor(of: sbi, matching: find.byType(ListTile)),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle();

    expect(await tester.runAsync(names), ['SBI', 'Cash', 'HDFC']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
