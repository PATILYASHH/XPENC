import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/persons/group_detail_screen.dart';
import 'package:xpenc/features/persons/person_detail_screen.dart';
import 'package:xpenc/features/share/share_models.dart';
import 'package:xpenc/features/share/share_pdfs.dart';

/// GitHub #128 — "Share Data with Person or Generate PDF": a person's ledger
/// and a group's expense history are each shareable — as a structured PDF
/// for a period, or as an image card.
void main() {
  // The PDFs embed Inter from the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

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
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<PersonRow> personNamed(int id) async =>
      (await db.watchPersons().first).firstWhere((p) => p.id == id);

  group('person ledger', () {
    test('a period opens on everything before it and runs a balance', () async {
      final id = await db.addPerson('Ram');
      // Before the period: Ram owes 1000.
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(1000),
        date: DateTime(2026, 7, 20),
      );
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 8, 1),
        note: 'Lunch money',
      );
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(200),
        date: DateTime(2026, 8, 15),
      );
      // After the period — never part of it.
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(300),
        date: DateTime(2026, 9, 2),
      );

      final share = PersonShare(
        person: await personNamed(id),
        owner: const ShareOwner(null),
        entries: await db.watchPersonEntries(id).first,
        balance: Money.fromRupees(1000),
      );
      final ledger = share.ledger(
        SharePeriod(
          'August',
          DateTimeRange(
            start: DateTime(2026, 8, 1),
            end: DateTime(2026, 8, 31),
          ),
        ),
      );

      expect(ledger.opening, Money.fromRupees(1000));
      expect(ledger.ownerGave, Money.fromRupees(500));
      expect(ledger.theyGave, Money.fromRupees(200));
      expect(ledger.closing, Money.fromRupees(1300));
      expect(ledger.lines.map((l) => l.balance), [
        Money.fromRupees(1500),
        Money.fromRupees(1300),
      ]);
      expect(share.titleOf(ledger.lines.first.entry), 'Lunch money');
      expect(share.titleOf(ledger.lines.last.entry), 'Ram gave');

      final all = share.ledger(SharePeriod.allTime);
      expect(all.opening, const Money.zero());
      expect(all.lines, hasLength(4));
      expect(all.closing, Money.fromRupees(1000));
    });

    test('balances read the right way round for the person receiving '
        'it', () {
      const you = ShareOwner(null);
      const yash = ShareOwner('Yash');
      expect(you.balanceLine(Money.fromRupees(5), 'Ram'), 'Ram owes you');
      expect(you.balanceLine(Money.fromRupees(-5), 'Ram'), 'You owe Ram');
      expect(yash.balanceLine(Money.fromRupees(5), 'Ram'), 'Ram owes Yash');
      expect(yash.balanceLine(Money.fromRupees(-5), 'Ram'), 'Yash owes Ram');
      expect(yash.balanceLine(const Money.zero(), 'Ram'), 'All settled');
      expect(yash.gave, 'Yash gave');
    });
  });

  group('PDF builders render real ledger data', () {
    test('buildPersonStatementPdf, for a period and for all time', () async {
      final id = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 8, 1),
        note: 'Lunch money',
      );
      await db.addPersonEntry(
        personId: id,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(200),
        date: DateTime(2026, 8, 15),
      );
      final share = PersonShare(
        person: await personNamed(id),
        owner: const ShareOwner('Yash'),
        entries: await db.watchPersonEntries(id).first,
        balance: Money.fromRupees(300),
      );

      for (final period in [
        SharePeriod.allTime,
        SharePeriod(
          '',
          DateTimeRange(
            start: DateTime(2026, 8, 1),
            end: DateTime(2026, 8, 31),
          ),
        ),
      ]) {
        final bytes = await buildPersonStatementPdf(share, period);
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      }
    });

    test('buildGroupStatementPdf, with shares and who-owes-whom', () async {
      final sita = await db.addPerson('Sita');
      final groupId = await db.addGroup('Trip');
      await db.setGroupMembers(groupId, {sita});
      await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(1000),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 8, 10),
        payerId: sita,
        participantIds: {null, sita},
        note: 'Cab fare',
      );
      final group = (await db.watchGroups().first).firstWhere(
        (g) => g.id == groupId,
      );
      final shares = await db.watchGroupExpenseShares(groupId).first;
      final share = GroupShare(
        group: group,
        owner: const ShareOwner(null),
        members: await db.watchGroupMembers(groupId).first,
        expenses: await db.watchGroupExpenses(groupId).first,
        myShares: {
          for (final s in shares)
            if (s.personId == null) s.groupExpenseId: s.amount,
        },
        names: {sita: 'Sita'},
        debts: [(from: null, to: sita, amount: Money.fromRupees(500))],
        balance: Money.fromRupees(-500),
      );

      final slice = share.slice(SharePeriod.allTime);
      expect(slice.total, Money.fromRupees(1000));
      expect(slice.myShare, Money.fromRupees(500));
      expect(share.nameOf(null), 'You');
      expect(share.nameOf(sita), 'Sita');

      final bytes = await buildGroupStatementPdf(share, SharePeriod.allTime);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });
  });

  group('share action is wired up on screen', () {
    testWidgets('Person detail: Share offers PDF or image, and PDF asks for '
        'a period', (tester) async {
      late int personId;
      await tester.runAsync(() async {
        personId = await db.addPerson('Ram');
        await db.addPersonEntry(
          personId: personId,
          direction: PersonDirection.theyOwe,
          amount: Money.fromRupees(500),
          date: DateTime.now(),
        );
      });

      await pump(tester, PersonDetailScreen(personId: personId));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      expect(find.text('PDF document'), findsOneWidget);
      expect(find.text('Image'), findsOneWidget);

      await tester.tap(find.text('PDF document'));
      // Loading the ledger is real async work against the database.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Statement period'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Custom range'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Group detail: Share → Image opens the card preview', (
      tester,
    ) async {
      late int groupId;
      await tester.runAsync(() async {
        final personId = await db.addPerson('Sita');
        groupId = await db.addGroup('Trip');
        await db.setGroupMembers(groupId, {personId});
      });

      await pump(tester, GroupDetailScreen(groupId: groupId));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Share'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Image'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Share image'), findsOneWidget);
      expect(find.text('TOTAL SPENT'), findsOneWidget);
      expect(find.text('Everyone is settled up.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switching the period re-renders the card in place.
      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
