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
import 'package:xpenc/features/data_export/statement_pdf.dart';
import 'package:xpenc/features/persons/group_detail_screen.dart';
import 'package:xpenc/features/persons/person_detail_screen.dart';

/// GitHub #128 — "Share Data with Person or Generate PDF": a person's ledger
/// and a group's expense history should each be exportable as a PDF, same
/// "pick a period, generate, share" flow the account statement already has.
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
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('PDF builders render real ledger data', () {
    test('buildPersonStatementPdf produces a valid PDF for a mixed ledger', () async {
      late PersonRow person;
      late List<PersonEntryRow> entries;

      final personId = await db.addPerson('Ram');
      await db.addPersonEntry(
        personId: personId,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 8, 1),
        note: 'Lunch money',
      );
      await db.addPersonEntry(
        personId: personId,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(200),
        date: DateTime(2026, 8, 15),
      );
      person = (await db.watchPersons().first).firstWhere(
        (p) => p.id == personId,
      );
      entries = await db.watchPersonEntries(personId).first;
      expect(entries, hasLength(2));

      final bytes = await buildPersonStatementPdf(
        person: person,
        entries: entries,
        currentBalance: Money.fromRupees(300),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('buildGroupStatementPdf produces a valid PDF for a shared expense', () async {
      final personId = await db.addPerson('Sita');
      final groupId = await db.addGroup('Trip');
      await db.setGroupMembers(groupId, {personId});
      await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(1000),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 8, 10),
        payerId: personId,
        participantIds: {null, personId},
        note: 'Cab fare',
      );
      final group = (await db.watchGroups().first).firstWhere(
        (g) => g.id == groupId,
      );
      final expenses = await db.watchGroupExpenses(groupId).first;
      expect(expenses, hasLength(1));

      final bytes = await buildGroupStatementPdf(
        group: group,
        expenses: expenses,
        payerNames: {personId: 'Sita'},
        currentBalance: Money.fromRupees(-500),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });
  });

  group('share action is wired up on screen', () {
    testWidgets('Person detail: "Share statement" opens the period picker', (
      tester,
    ) async {
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

      await tester.tap(find.byTooltip('Share statement'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Statement period'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Custom range'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Group detail: "Share statement" opens the period picker', (
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

      await tester.tap(find.byTooltip('Share statement'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Statement period'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
