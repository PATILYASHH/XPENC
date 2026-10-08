import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/security/nct.dart';
import 'package:xpenc/core/security/screen_security.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/transactions/transaction_detail_screen.dart';

/// GitHub #143 — NCT, "non-capturable transactions": frosted wherever
/// they're listed until held, and captures blocked while one shows.
void main() {
  const channel = MethodChannel('xpenc/screen_security');

  /// Every `setSecure` the app sent, in order.
  late List<bool> sent;

  void mockChannel(WidgetTester? tester) {
    sent = [];
    final messenger =
        tester?.binding.defaultBinaryMessenger ??
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setSecure') sent.add(call.arguments as bool);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  group('ScreenSecurity', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockChannel(null);
      // Back to a known state: setting off, no holds.
      while (ScreenSecurity.holds > 0) {
        await ScreenSecurity.release();
      }
      await ScreenSecurity.apply(true);
      await ScreenSecurity.apply(false);
      sent.clear();
    });

    test('a hold secures the window until its release', () async {
      await ScreenSecurity.hold();
      await ScreenSecurity.release();
      expect(sent, [true, false]);
    });

    test('the setting and a hold share the flag without undoing each '
        'other', () async {
      await ScreenSecurity.apply(true);
      await ScreenSecurity.hold();
      await ScreenSecurity.release();
      expect(sent, [true], reason: 'still on for the setting');
      await ScreenSecurity.hold();
      await ScreenSecurity.apply(false);
      expect(sent, [true], reason: 'still on for the hold');
      await ScreenSecurity.release();
      expect(sent, [true, false]);
    });

    test('a release sent before its hold landed still turns it off', () async {
      final holding = ScreenSecurity.hold();
      final releasing = ScreenSecurity.release();
      await Future.wait([holding, releasing]);
      expect(sent.last, isFalse);
      expect(ScreenSecurity.holds, 0);
    });
  });

  group('NctVeil', () {
    Future<void> pumpRow(
      WidgetTester tester, {
      required bool active,
      VoidCallback? onTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: NctVeil(
              active: active,
              child: ListTile(
                onTap: onTap,
                title: const Text('Secret payee'),
                trailing: const Text('-₹2,000.00'),
              ),
            ),
          ),
        ),
      );
    }

    bool shown(WidgetTester tester) =>
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.text('Secret payee'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity ==
        1;

    testWidgets('an ordinary transaction is left alone', (tester) async {
      await pumpRow(tester, active: false);
      expect(find.text('Hidden · hold to view'), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('an NCT row is frosted, still opens on a tap, and shows '
        'only while held — with captures blocked meanwhile', (tester) async {
      mockChannel(tester);
      var taps = 0;
      await pumpRow(tester, active: true, onTap: () => taps++);
      expect(find.text('Hidden · hold to view'), findsOneWidget);
      expect(shown(tester), isFalse);

      await tester.tap(find.byType(NctVeil));
      await tester.pump();
      expect(taps, 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(NctVeil)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      expect(sent, [true]);
      expect(shown(tester), isTrue);
      expect(find.text('Hidden · hold to view'), findsNothing);

      await gesture.up();
      await tester.pump();
      await tester.pump();
      expect(shown(tester), isFalse);
      expect(sent, [true, false]);
      expect(taps, 1, reason: 'a hold is not a tap');
    });
  });

  group('the ledger', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> cash() async => (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;

    test('NCT is set with the insert, kept by an edit that leaves it out, '
        'and flips from the detail page', () async {
      final id = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(2000),
        accountId: await cash(),
        date: DateTime(2026, 10, 1),
        isNct: true,
      );
      Future<bool> nct() async =>
          (await db.watchTransactions().first).single.isNct;
      expect(await nct(), isTrue);

      await db.updateTransaction(
        id: id,
        type: TxType.expense,
        amount: Money.fromRupees(2100),
        accountId: await cash(),
        date: DateTime(2026, 10, 1),
      );
      expect(await nct(), isTrue);

      await db.setTransactionNct(id, false);
      expect(await nct(), isFalse);
    });

    test('a split payment marks every leg', () async {
      final bank = await db.addAccount(
        name: 'Bank',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(5000),
      );
      await db.addHybridPaymentTransaction(
        legs: [
          (accountId: await cash(), amount: Money.fromRupees(100)),
          (accountId: bank, amount: Money.fromRupees(400)),
        ],
        date: DateTime(2026, 10, 1),
        isNct: true,
      );
      final rows = await db.watchTransactions().first;
      expect(rows, hasLength(2));
      expect(rows.every((t) => t.isNct), isTrue);
    });

    test('a backup keeps it; one made before NCT restores as off', () async {
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(50),
        accountId: await cash(),
        date: DateTime(2026, 10, 1),
        isNct: true,
      );
      final backup = await db.exportAll();
      await db.importAll(backup);
      expect((await db.watchTransactions().first).single.isNct, isTrue);

      for (final row in backup['transactions'] as List) {
        (row as Map).remove('is_nct');
      }
      await db.importAll(backup);
      expect((await db.watchTransactions().first).single.isNct, isFalse);
    });
  });

  testWidgets('the detail page blocks captures for an NCT transaction and '
      'flips it from its switch', (tester) async {
    mockChannel(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = (await tester.runAsync(() async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      return db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(2000),
        accountId: cash,
        date: DateTime(2026, 10, 1),
        isNct: true,
      );
    }))!;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: TransactionDetailScreen(transactionId: id),
        ),
      ),
    );
    await settle();
    expect(sent, [true]);
    expect(ScreenSecurity.holds, 1);

    final toggle = find.text('Hide from screenshots');
    await tester.dragUntilVisible(
      toggle,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(toggle);
    await settle();
    final row = (await tester.runAsync(() => db.watchTransactions().first))!;
    expect(row.single.isNct, isFalse);
    expect(sent.last, isFalse);
    expect(ScreenSecurity.holds, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
