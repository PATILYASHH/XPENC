import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/currency.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/share/pdf_kit.dart';
import 'package:xpenc/features/share/share_cards.dart';
import 'package:xpenc/features/share/share_models.dart';
import 'package:xpenc/features/share/share_pdfs.dart';
import 'package:xpenc/features/transactions/transaction_detail_screen.dart';

/// Share → PDF or image, for a transaction, a person and a group.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cash() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  /// A transaction with every optional part filled in.
  Future<TransactionShare> richExpense({String? note}) async {
    final id = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1250.5),
      accountId: await cash(),
      date: DateTime(2026, 10, 8, 19, 42),
      payee: 'Swiggy',
      note: note ?? 'Team dinner after the release, split later',
      foreignCurrencyCode: 'USD',
      foreignAmount: Money.fromRupees(15),
    );
    final t = (await db.transactionById(id))!;
    return TransactionShare(
      tx: t,
      headline: 'Swiggy',
      typeLabel: 'Expense',
      currency: kDefaultCurrency,
      account: 'Paid via Cash',
      category: 'Food › Dining out',
      categoryIconKey: 'food',
      categoryColor: 0xFFE11D48,
      payee: 'Swiggy',
      foreign: (Money.fromRupees(15), currencyForCode('USD')),
      note: t.note,
      rule: 'Friday dinners',
    );
  }

  group('PdfKit', () {
    test('keeps a currency symbol the font has, spells out one it '
        "doesn't", () async {
      final kit = await PdfKit.load();
      expect(kit.money(Money.fromRupees(1250), kDefaultCurrency), '₹1,250.00');
      expect(
        kit.money(Money.fromRupees(-40), currencyForCode('EUR'), signed: true),
        '−€40.00',
      );
      expect(
        kit.money(Money.fromRupees(5), kDefaultCurrency, signed: true),
        '+₹5.00',
      );
      // ৳ isn't in the bundled Inter subset.
      expect(
        kit.money(Money.fromRupees(99), currencyForCode('BDT')),
        '99.00 BDT',
      );
    });
  });

  test('buildTransactionPdf produces a PDF with every section', () async {
    final share = await richExpense();
    final bytes = await buildTransactionPdf(share);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    // Inter is embedded (the old statements used only Helvetica).
    expect(latin1.decode(bytes), contains('Inter'));
  });

  test('TransactionShare.resolve names everything a share shows', () async {
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final ram = await db.addPerson('Ram');
    final id = await db.addTransaction(
      type: TxType.personOut,
      amount: Money.fromRupees(300),
      accountId: await cash(),
      personId: ram,
      date: DateTime(2026, 10, 1),
    );
    // Let the stream-backed maps load.
    container.listen(allPersonsByIdProvider, (_, _) {});
    container.listen(accountMapProvider, (_, _) {});
    await container.read(personsProvider.future);
    await container.read(accountsProvider.future);

    final share = TransactionShare.resolve(
      container,
      (await db.transactionById(id))!,
    );
    expect(share.typeLabel, 'Gave to Ram');
    expect(share.headline, 'Gave to Ram');
    expect(share.account, startsWith('Given from '));
    expect(share.signedAmount, Money.fromRupees(-300));
    expect(share.hasTime, isFalse);
  });

  group('image cards lay out without overflow', () {
    Future<void> pumpCard(WidgetTester tester, Widget card) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(child: Center(child: card)),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    for (final tone in ShareCardTone.values) {
      testWidgets('transaction · ${tone.name}', (tester) async {
        final share = (await tester.runAsync(
          () => richExpense(note: 'A very long note that goes on and on ' * 6),
        ))!;
        await pumpCard(tester, TransactionShareCard(data: share, tone: tone));
        expect(find.text('+₹1,250.50'), findsNothing);
        expect(find.text('−₹1,250.50'), findsOneWidget);
        expect(find.text('Swiggy'), findsWidgets);
        expect(find.text('Food › Dining out'), findsOneWidget);
      });

      testWidgets('person · ${tone.name}', (tester) async {
        final share = (await tester.runAsync(() async {
          final id = await db.addPerson('Ramchandra Venkataraman Subramanian');
          for (var i = 0; i < 9; i++) {
            await db.addPersonEntry(
              personId: id,
              direction: i.isEven
                  ? PersonDirection.theyOwe
                  : PersonDirection.iOwe,
              amount: Money.fromRupees(100.0 * (i + 1)),
              date: DateTime(2026, 9, i + 1),
              note: i == 3 ? 'Concert tickets and the cab ride home' : null,
            );
          }
          return PersonShare(
            person: (await db.watchPersons().first).single,
            owner: const ShareOwner('Yash'),
            entries: await db.watchPersonEntries(id).first,
            balance: Money.fromRupees(12345678.9),
          );
        }))!;
        await pumpCard(
          tester,
          PersonShareCard(data: share, period: SharePeriod.allTime, tone: tone),
        );
        expect(
          find.text('RAMCHANDRA VENKATARAMAN SUBRAMANIAN OWES YASH'),
          findsOneWidget,
        );
        expect(find.text('+ 3 more entries'), findsOneWidget);
      });

      testWidgets('group · ${tone.name}', (tester) async {
        final share = (await tester.runAsync(() async {
          final sita = await db.addPerson('Sita');
          final ravi = await db.addPerson('Ravi');
          final groupId = await db.addGroup('Goa trip 2026');
          await db.setGroupMembers(groupId, {sita, ravi});
          for (var i = 0; i < 6; i++) {
            await db.addGroupExpense(
              groupId: groupId,
              amount: Money.fromRupees(900),
              splitMethod: GroupSplitMethod.equal,
              date: DateTime(2026, 9, i + 1),
              payerId: i.isEven ? sita : ravi,
              participantIds: {null, sita, ravi},
              note: 'Dinner $i',
            );
          }
          return GroupShare(
            group: (await db.watchGroups().first).single,
            owner: const ShareOwner(null),
            members: await db.watchGroupMembers(groupId).first,
            expenses: await db.watchGroupExpenses(groupId).first,
            myShares: const {},
            names: {sita: 'Sita', ravi: 'Ravi'},
            debts: [
              (from: null, to: sita, amount: Money.fromRupees(900)),
              (from: null, to: ravi, amount: Money.fromRupees(900)),
              (from: ravi, to: sita, amount: Money.fromRupees(300)),
            ],
            balance: Money.fromRupees(-1800),
          );
        }))!;
        await pumpCard(
          tester,
          GroupShareCard(data: share, period: SharePeriod.allTime, tone: tone),
        );
        expect(find.text('₹5,400.00'), findsOneWidget);
        expect(find.text('+ 2 more expenses'), findsOneWidget);
      });
    }
  });

  testWidgets('transaction detail: Share → Image opens a preview, Dark/Light '
      'switches the card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final id = (await tester.runAsync(() async {
      return db.addTransaction(
        type: TxType.income,
        amount: Money.fromRupees(52000),
        accountId: await cash(),
        date: DateTime(2026, 10, 1),
        note: 'October salary',
      );
    }))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: TransactionDetailScreen(transactionId: id),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();
    expect(find.text('PDF document'), findsOneWidget);
    await tester.tap(find.text('Image'));
    await tester.pumpAndSettle();

    expect(find.text('Share image'), findsOneWidget);
    expect(find.text('+₹52,000.00'), findsOneWidget);
    expect(find.text('October salary'), findsOneWidget);
    await tester.tap(find.byTooltip('Light card'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}
