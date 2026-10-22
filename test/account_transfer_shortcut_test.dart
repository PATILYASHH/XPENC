import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/accounts/account_detail_screen.dart';
import 'package:xpenc/features/accounts/add_account_sheet.dart';
import 'package:xpenc/features/add_transaction/add_transaction_screen.dart';

/// Cash at home works like an ATM you withdraw from into the wallet
/// (GitHub #171): an account page's Transfer in / Transfer out opens a
/// transfer with that account already on the right side.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<int> cashAtHome() => db.addAccount(
    name: 'Cash at home',
    type: AccountType.cash,
    colorValue: 0,
    iconKey: 'house',
    openingBalance: Money.fromRupees(600),
  );

  Future<int> wallet() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  testWidgets('Transfer out starts a transfer from this account', (
    tester,
  ) async {
    late int home;
    await tester.runAsync(() async => home = await cashAtHome());
    await pump(
      tester,
      AddTransactionScreen(
        initialType: TxType.transfer,
        initialAccountId: home,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('From account'), findsOneWidget);
    expect(find.text('Cash at home'), findsOneWidget);
    // "To" is the person's pick.
    expect(find.text('Select account'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Transfer in starts a transfer into this account, never from '
      'it', (tester) async {
    late int home;
    late int walletId;
    await tester.runAsync(() async {
      home = await cashAtHome();
      walletId = await wallet();
      // The last-used account is the wallet itself — it must not become
      // the "From" of a transfer into the wallet.
      await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(50),
        accountId: walletId,
        date: DateTime.now(),
      );
    });
    await pump(
      tester,
      AddTransactionScreen(
        initialType: TxType.transfer,
        initialToAccountId: walletId,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('To account'), findsOneWidget);
    expect(find.text('Select account'), findsOneWidget); // From, still open
    expect(home, isNot(walletId));
    await unmount(tester);
  });

  testWidgets('an account page offers Transfer in / out; a debit card does '
      'not', (tester) async {
    late int home;
    late int debit;
    await tester.runAsync(() async {
      home = await cashAtHome();
      final bank = await db.addAccount(
        name: 'IPPB',
        type: AccountType.bank,
        colorValue: 0,
        iconKey: 'bank',
        openingBalance: Money.fromRupees(1000),
      );
      debit = await db.addAccount(
        name: 'IPPB Debit',
        type: AccountType.card,
        cardKind: CardKind.debit,
        linkedAccountId: bank,
        colorValue: 0,
        iconKey: 'card',
        openingBalance: const Money.zero(),
      );
    });

    await pump(tester, AccountDetailScreen(accountId: home));
    expect(tester.takeException(), isNull);
    expect(find.text('Transfer in'), findsOneWidget);
    expect(find.text('Transfer out'), findsOneWidget);
    await unmount(tester);

    await pump(tester, AccountDetailScreen(accountId: debit));
    expect(tester.takeException(), isNull);
    expect(find.text('Transfer out'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Add account: the Cash at home suggestion fills in the name', (
    tester,
  ) async {
    await pump(tester, const Scaffold(body: AddAccountSheet()));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Suggestions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Cash at home (V-ATM)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Cash at home',
    );
    await unmount(tester);
  });
}
