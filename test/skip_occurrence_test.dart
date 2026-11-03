import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/routing/app_router.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/providers.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/reports/cash_flow_projection.dart';

/// #184: skip one occurrence of an Auto rule without stopping it — nothing
/// posts, the rule steps over one date and carries on.
void main() {
  late AppDatabase db;
  late int cash;
  late int food;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    cash = (await db.watchAccounts().first).single.id;
    food = (await db.watchCategories(CategoryKind.expense).first).first.id;
  });
  tearDown(() => db.close());

  Future<int> gym({
    DateTime? startsOn,
    RecurringFrequency frequency = RecurringFrequency.monthly,
    int? promoRupees,
    int? promoOccurrences,
  }) => db.addRecurringRule(
    name: 'Gym',
    kind: CategoryKind.expense,
    amount: Money.fromRupees(1500),
    accountId: cash,
    categoryId: food,
    frequency: frequency,
    startsOn: startsOn ?? DateTime(2026, 11, 5),
    promoAmount: promoRupees == null ? null : Money.fromRupees(promoRupees),
    promoOccurrences: promoOccurrences,
  );

  Future<RecurringRuleRow> ruleOf(int id) =>
      (db.select(db.recurringRules)..where((r) => r.id.equals(id))).getSingle();

  Future<int> postedBy(int ruleId) async => (await (db.select(
    db.transactions,
  )..where((t) => t.recurringRuleId.equals(ruleId))).get()).length;

  test(
    'skipping steps over one date, posts nothing, keeps the rule on',
    () async {
      final id = await gym();
      final skip = await db.skipRecurringRuleOccurrence(id);

      expect(skip.skipped, DateTime(2026, 11, 5));
      expect(skip.next, DateTime(2026, 12, 5));
      final rule = await ruleOf(id);
      expect(rule.nextDueDate, DateTime(2026, 12, 5));
      expect(rule.isActive, isTrue);
      expect(await postedBy(id), 0);

      // The skipped date passes quietly; the next one posts as usual.
      expect(await db.runDueRecurringRules(now: DateTime(2026, 11, 20)), 0);
      expect(await db.runDueRecurringRules(now: DateTime(2026, 12, 5)), 1);
      expect((await ruleOf(id)).nextDueDate, DateTime(2027, 1, 5));
    },
  );

  test('a monthly rule on the 31st keeps its day across a skip', () async {
    final id = await gym(startsOn: DateTime(2027, 1, 31));
    await db.skipRecurringRuleOccurrence(id);
    expect((await ruleOf(id)).nextDueDate, DateTime(2027, 2, 28));
    await db.skipRecurringRuleOccurrence(id);
    expect((await ruleOf(id)).nextDueDate, DateTime(2027, 3, 31));
  });

  test('a skip doesn\'t spend a promo occurrence', () async {
    final id = await gym(promoRupees: 99, promoOccurrences: 2);
    await db.skipRecurringRuleOccurrence(id);
    final rule = await ruleOf(id);
    expect(rule.promoOccurrencesLeft, 2);
    expect(rule.promoAmount, Money.fromRupees(99));
  });

  test('undo puts the skipped date back', () async {
    final id = await gym();
    final skip = await db.skipRecurringRuleOccurrence(id);
    final undone = await db.unskipRecurringRuleOccurrence(
      id,
      skipped: skip.skipped,
      next: skip.next,
    );
    expect(undone, isTrue);
    expect((await ruleOf(id)).nextDueDate, DateTime(2026, 11, 5));
  });

  test('undo does nothing once the rule has moved on', () async {
    final id = await gym();
    final skip = await db.skipRecurringRuleOccurrence(id);
    // The next one was paid early, moving the rule past the skip.
    await db.payRecurringRuleNow(id, now: DateTime(2026, 11, 6));
    final undone = await db.unskipRecurringRuleOccurrence(
      id,
      skipped: skip.skipped,
      next: skip.next,
    );
    expect(undone, isFalse);
    expect((await ruleOf(id)).nextDueDate, DateTime(2027, 1, 5));
  });

  testWidgets('hold a rule → Skip next, then Undo', (tester) async {
    final now = DateTime.now();
    final due = DateTime(now.year, now.month, now.day + 10);
    final id = await tester.runAsync(() => gym(startsOn: due));
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    appRouter.go('/more/auto');
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    await settle();
    await tester.longPress(find.text('Gym'));
    await settle();
    await tester.tap(find.text('Skip next'));
    await settle();

    expect(find.textContaining('next on'), findsOneWidget);
    var rule = await tester.runAsync(() => ruleOf(id!));
    expect(rule!.nextDueDate, isNot(due));
    expect(await tester.runAsync(() => postedBy(id!)), 0);

    await tester.tap(find.text('Undo'));
    await settle();
    rule = await tester.runAsync(() => ruleOf(id!));
    expect(rule!.nextDueDate, due);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  test('the cash flow projection leaves the skipped date out', () async {
    final id = await gym(frequency: RecurringFrequency.weekly);
    Future<int> rulesOverAMonth() async {
      final p = projectCashFlow(
        today: DateTime(2026, 11, 1),
        months: 1,
        accounts: await db.select(db.accounts).get(),
        rules: await db.select(db.recurringRules).get(),
        transactions: await db.select(db.transactions).get(),
        loans: const {},
        rates: const {},
      );
      return p.steps.last.rules.paise ~/ 100;
    }

    // 5, 12, 19, 26 Nov.
    expect(await rulesOverAMonth(), -6000);
    await db.skipRecurringRuleOccurrence(id);
    expect(await rulesOverAMonth(), -4500);
  });
}
