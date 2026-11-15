import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/smart_tags.dart';
import 'package:xpenc/core/theme/app_theme.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/tags/tags_screen.dart';

/// GitHub #189: smart tags. A tag whose name holds a date part lands on a
/// transaction as the plain tag that part reads on the transaction's date,
/// so a template or Auto rule carrying it never needs editing.
void main() {
  group('SmartTags', () {
    final dec = DateTime(2026, 12, 5);

    test('fills each date part in from the date', () {
      expect(SmartTags.resolve('{month}', dec), 'December');
      expect(SmartTags.resolve('{mon}', dec), 'Dec');
      expect(SmartTags.resolve('{year}', dec), '2026');
      expect(SmartTags.resolve('{quarter}', DateTime(2026, 4, 1)), 'Q2');
      expect(SmartTags.resolve('Coffee {mon} {year}', dec), 'Coffee Dec 2026');
    });

    test('parts are case-insensitive; other braces stay plain text', () {
      expect(SmartTags.isSmart('{Month}'), isTrue);
      expect(SmartTags.resolve('{YEAR}', dec), '2026');
      expect(SmartTags.isSmart('{work}'), isFalse);
      expect(SmartTags.isSmart('December'), isFalse);
      expect(SmartTags.resolve('{work} {year}', dec), '{work} 2026');
    });

    test('never longer than a tag name may be', () {
      final pattern = 'A long label here {month} {month}';
      final out = SmartTags.resolve(pattern, DateTime(2026, 9, 1));
      expect(out.length, lessThanOrEqualTo(SmartTags.maxLength));
    });

    test('label shows a smart tag as it will read, any other as is', () {
      expect(SmartTags.label('{month}', dec), 'December');
      expect(SmartTags.label('Work', dec), 'Work');
    });
  });

  group('database', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> cashId() async => (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
    Future<int> foodId() async =>
        (await db.watchCategories(CategoryKind.expense).first)
            .firstWhere((c) => c.name == 'Food')
            .id;
    Future<int> coffee(DateTime date) async => db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(150),
      accountId: await cashId(),
      categoryId: await foodId(),
      date: date,
    );
    Future<List<String>> tagNames(int txId) async {
      final ids = await db.tagIdsForTransaction(txId);
      final all = await db.select(db.tags).get();
      return [
        for (final t in all)
          if (ids.contains(t.id)) t.name,
      ]..sort();
    }

    test('a smart tag lands as the plain tag for the transaction date, '
        'made in its colour', () async {
      final smart = await db.addTag(name: '{month}', colorValue: 0xFFA855F7);
      final fixed = await db.addTag(name: 'Coffee', colorValue: 0xFF16A34A);

      final dec = await coffee(DateTime(2026, 12, 3));
      await db.setTransactionTags(dec, {smart, fixed});
      expect(await tagNames(dec), ['Coffee', 'December']);

      final jan = await coffee(DateTime(2027, 1, 3));
      await db.setTransactionTags(jan, {smart, fixed});
      expect(await tagNames(jan), ['Coffee', 'January']);

      final made = (await db.select(db.tags).get()).firstWhere(
        (t) => t.name == 'December',
      );
      expect(made.colorValue, 0xFFA855F7);
      // The smart tag itself is never on a transaction.
      expect(await db.tagIdsForTransaction(dec), isNot(contains(smart)));
    });

    test('reuses an existing tag of that name whatever its case', () async {
      final smart = await db.addTag(name: '{month}', colorValue: 0xFFA855F7);
      final mine = await db.addTag(name: 'december', colorValue: 0xFF0EA5E9);

      final tx = await coffee(DateTime(2026, 12, 3));
      await db.setTransactionTags(tx, {smart});

      expect(await db.tagIdsForTransaction(tx), [mine]);
      expect(
        (await db.select(db.tags).get()).where(
          (t) => t.name.toLowerCase() == 'december',
        ),
        hasLength(1),
      );
    });

    test('an Auto rule stamps each posting with its own month', () async {
      final smart = await db.addTag(
        name: '{mon} {year}',
        colorValue: 0xFFA855F7,
      );
      await db.addRecurringRule(
        name: 'Gym',
        kind: CategoryKind.expense,
        amount: Money.fromRupees(999),
        accountId: await cashId(),
        categoryId: await foodId(),
        frequency: RecurringFrequency.monthly,
        startsOn: DateTime(2026, 11, 1),
        tagIds: {smart},
      );

      expect(await db.runDueRecurringRules(now: DateTime(2026, 12, 2)), 2);

      final txs = (await db.watchTransactions().first)
        ..sort((a, b) => a.date.compareTo(b.date));
      expect(await tagNames(txs[0].id), ['Nov 2026']);
      expect(await tagNames(txs[1].id), ['Dec 2026']);
    });

    test('a person entry resolves against its own date, and so does its '
        'ledger row', () async {
      final smart = await db.addTag(name: '{month}', colorValue: 0xFFA855F7);
      final asha = await db.addPerson('Asha');
      final id = await db.addPersonEntry(
        personId: asha,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 10, 1),
        accountId: await cashId(),
        tagIds: {smart},
      );

      final entry = (await db.select(db.personEntries).get()).firstWhere(
        (e) => e.id == id,
      );
      final october = (await db.select(db.tags).get())
          .firstWhere((t) => t.name == 'October')
          .id;
      expect(await db.tagIdsForPersonEntry(id), {october});
      expect(await db.tagIdsForTransaction(entry.transactionId!), [october]);
    });

    test(
      'saving as a template turns the date tag back into the smart tag',
      () async {
        final smart = await db.addTag(name: '{month}', colorValue: 0xFFA855F7);
        final fixed = await db.addTag(name: 'Coffee', colorValue: 0xFF16A34A);
        final tx = await coffee(DateTime(2026, 12, 3));
        await db.setTransactionTags(tx, {smart, fixed});

        final template = await db.createTemplateFromTransaction(
          transactionId: tx,
          name: 'Coffee',
        );

        expect((await db.tagIdsForTemplate(template)).toSet(), {smart, fixed});
      },
    );

    test('a template keeps a plain tag no smart tag reads as', () async {
      await db.addTag(name: '{month}', colorValue: 0xFFA855F7);
      final christmas = await db.addTag(
        name: 'Christmas',
        colorValue: 0xFFDC2626,
      );
      final tx = await coffee(DateTime(2026, 12, 3));
      await db.setTransactionTags(tx, {christmas});

      final template = await db.createTemplateFromTransaction(
        transactionId: tx,
        name: 'Gift',
      );

      expect(await db.tagIdsForTemplate(template), [christmas]);
    });
  });

  group('Tags screen', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTheme.light, home: const TagsScreen()),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('lists a smart tag with what it reads today', (tester) async {
      await tester.runAsync(
        () => db.addTag(name: '{month} {year}', colorValue: 0xFFA855F7),
      );
      await pump(tester);

      final today = SmartTags.resolve('{month} {year}', DateTime.now());
      expect(tester.takeException(), isNull);
      expect(find.text('{month} {year}'), findsOneWidget);
      expect(find.text('Smart · today "$today"'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('the editor drops a date part in and previews it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byTooltip('New tag'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Add a date part'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Coffee');
      await tester.tap(find.widgetWithText(ActionChip, 'Short month'));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Coffee {mon}');
      final today = SmartTags.resolve('Coffee {mon}', DateTime.now());
      expect(find.textContaining('today it reads "$today"'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
