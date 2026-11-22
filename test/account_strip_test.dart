import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/add_transaction/account_strip.dart';

/// Add Transaction's account strip: cards that swipe sideways, tap to pick;
/// hold one for a second to arrange them — ‹ › move a card, ✕ takes it off
/// the row, ＋ puts it back.
void main() {
  late AppDatabase db;
  late List<int> ids;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpStrip(WidgetTester tester, {int? selected}) async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    ids = (await tester.runAsync(() async {
      return [
        for (final name in ['Wallet', 'Bank', 'Card'])
          await db.addAccount(
            name: name,
            type: name == 'Wallet' ? AccountType.cash : AccountType.bank,
            colorValue: 0xFF336699,
            iconKey: 'wallet',
            openingBalance: Money.fromRupees(100),
          ),
      ];
    }))!;
    var picked = selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: Padding(
                          padding: const EdgeInsets.all(20),
                          child: StatefulBuilder(
                            builder: (context, setState) => AccountStrip(
                              label: 'Paid via',
                              selectedId: picked,
                              onSelected: (id) => setState(() => picked = id),
                              onMore: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<List<String>> order(WidgetTester tester) async {
    final rows = (await tester.runAsync(() => db.watchAccounts().first))!;
    return [for (final a in rows) a.name];
  }

  Future<bool> shown(WidgetTester tester, int id) async {
    final rows = (await tester.runAsync(() => db.watchAccounts().first))!;
    return rows.firstWhere((a) => a.id == id).showOnAddPage;
  }

  Future<void> holdToEdit(WidgetTester tester, String name) async {
    final g = await tester.startGesture(tester.getCenter(find.text(name)));
    await tester.pump(const Duration(milliseconds: 1100));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('every account is a card; a tap picks it', (tester) async {
    await pumpStrip(tester);
    for (final name in ['Wallet', 'Bank', 'Card']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Select account'), findsOneWidget);

    await tester.tap(find.text('Bank'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(ValueKey('accountPicked:${ids[1]}')), findsOneWidget);
    expect(find.text('Select account'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a short press picks; only a one-second hold edits', (
    tester,
  ) async {
    await pumpStrip(tester);
    final g = await tester.startGesture(tester.getCenter(find.text('Card')));
    await tester.pump(const Duration(milliseconds: 400));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Arrange accounts'), findsNothing);
    expect(find.byKey(ValueKey('accountPicked:${ids[2]}')), findsOneWidget);

    await holdToEdit(tester, 'Card');
    expect(find.text('Arrange accounts'), findsOneWidget);
    expect(find.byKey(ValueKey('accountForward:${ids[0]}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('‹ › move a card and the order is saved', (tester) async {
    await pumpStrip(tester);
    await holdToEdit(tester, 'Wallet');
    await tester.tap(find.byKey(ValueKey('accountForward:${ids[0]}')));
    await settle(tester);
    // A new database starts with its own Cash account, first.
    expect(await order(tester), ['Cash', 'Bank', 'Wallet', 'Card']);

    await tester.tap(find.byKey(ValueKey('accountBack:${ids[2]}')));
    await settle(tester);
    expect(await order(tester), ['Cash', 'Bank', 'Card', 'Wallet']);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('✕ takes a card off the row; it waits at "more", and ＋ puts '
      'it back', (tester) async {
    await pumpStrip(tester);
    await holdToEdit(tester, 'Bank');
    await tester.tap(find.byKey(ValueKey('accountRemove:${ids[1]}')));
    await settle(tester);
    expect(await shown(tester, ids[1]), isFalse);
    // Still there while editing — dimmed, to be put back.
    expect(find.byKey(ValueKey('accountAddBack:${ids[1]}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountStripDone')));
    await settle(tester);
    expect(find.text('Bank'), findsNothing);
    expect(find.text('1 more'), findsOneWidget);

    await holdToEdit(tester, 'Wallet');
    await tester.ensureVisible(
      find.byKey(ValueKey('accountAddBack:${ids[1]}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('accountAddBack:${ids[1]}')));
    await settle(tester);
    expect(await shown(tester, ids[1]), isTrue);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the picked account keeps its card even when taken off', (
    tester,
  ) async {
    await pumpStrip(tester, selected: null);
    await tester.tap(find.text('Card'));
    await tester.pump(const Duration(milliseconds: 300));
    await holdToEdit(tester, 'Wallet');
    await tester.tap(find.byKey(ValueKey('accountRemove:${ids[2]}')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('accountStripDone')));
    await settle(tester);
    expect(find.text('Card'), findsOneWidget);
    expect(find.byKey(ValueKey('accountPicked:${ids[2]}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Back leaves edit mode, not the page', (tester) async {
    await pumpStrip(tester);
    await holdToEdit(tester, 'Wallet');
    expect(find.text('Arrange accounts'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Arrange accounts'), findsNothing);
    expect(find.byType(AccountStrip), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  test('a new account is on the strip; a backup keeps the flag', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.addAccount(
      name: 'Wallet',
      type: AccountType.cash,
      colorValue: 0xFF000000,
      iconKey: 'wallet',
      openingBalance: const Money.zero(),
    );
    Future<AccountRow> wallet() async =>
        (await db.watchAccounts().first).firstWhere((a) => a.id == id);
    expect((await wallet()).showOnAddPage, isTrue);
    await db.setAccountShownOnAddPage(id, false);
    expect((await wallet()).showOnAddPage, isFalse);
    // A backup carries it.
    final backup = await db.exportAll();
    final row = (backup['accounts'] as List).cast<Map>().firstWhere(
      (r) => r['id'] == id,
    );
    expect(row['show_on_add_page'], isFalse);
  });
}
