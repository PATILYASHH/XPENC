import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #203 — an Auto rule paid twice ("double spending"). The engine
/// read the rules that were due, then posted from that snapshot: a second
/// run (app start and a resume overlapping), or a Pay now landing in
/// between, posted the same occurrence again.
void main() {
  late AppDatabase db;
  late int bank;
  late int food;
  final due = DateTime(2026, 11, 18);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    bank = await db.addAccount(
      name: 'Bank',
      type: AccountType.bank,
      colorValue: 0,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(100000),
    );
    food = (await db.watchCategories(CategoryKind.expense).first).first.id;
  });
  tearDown(() => db.close());

  Future<int> gym() => db.addRecurringRule(
    name: 'Gym',
    kind: CategoryKind.expense,
    amount: Money.fromRupees(500),
    accountId: bank,
    categoryId: food,
    frequency: RecurringFrequency.monthly,
    startsOn: due,
  );

  Future<int> postings(int ruleId) async => (await db.watchTransactions().first)
      .where((t) => t.recurringRuleId == ruleId)
      .length;

  Future<DateTime> nextOf(int ruleId) async =>
      (await db.watchRecurringRules().first)
          .firstWhere((r) => r.id == ruleId)
          .nextDueDate;

  test('two overlapping runs post a due occurrence once', () async {
    final id = await gym();
    final counts = await Future.wait([
      db.runDueRecurringRules(now: due),
      db.runDueRecurringRules(now: due),
    ]);
    expect(await postings(id), 1);
    expect(counts.reduce((a, b) => a + b), 1);
    expect(await nextOf(id), DateTime(2026, 12, 18));
  });

  test('Pay now during a run is not paid twice', () async {
    final id = await gym();
    await Future.wait([
      db.runDueRecurringRules(now: due),
      db.payRecurringRuleNowResult(id, now: due, expectedDueDate: due),
    ]);
    expect(await postings(id), 1);
    expect(await nextOf(id), DateTime(2026, 12, 18));
  });

  test('Pay now 3 days early, then the due date: one payment', () async {
    final id = await gym();
    final paidOn = due.subtract(const Duration(days: 3));
    expect(
      await db.payRecurringRuleNowResult(id, now: paidOn, expectedDueDate: due),
      PayNowResult.posted,
    );
    for (var d = 0; d <= 7; d++) {
      await db.runDueRecurringRules(now: paidOn.add(Duration(days: d)));
    }
    expect(await postings(id), 1);
    expect(await nextOf(id), DateTime(2026, 12, 18));
  });

  test(
    'a confirm dialog left open while the app posted pays nothing',
    () async {
      final id = await gym();
      // The dialog showed 18 Nov; meanwhile the app caught it up.
      await db.runDueRecurringRules(now: due);
      expect(
        await db.payRecurringRuleNowResult(id, now: due, expectedDueDate: due),
        PayNowResult.alreadyPosted,
      );
      expect(await postings(id), 1);
      expect(await nextOf(id), DateTime(2026, 12, 18));
    },
  );

  test('a paused rule is not posted by a run that listed it', () async {
    final id = await gym();
    final run = db.runDueRecurringRules(now: due);
    await db.setRecurringActive(id, false);
    await run;
    await db.runDueRecurringRules(now: due);
    expect(await postings(id), lessThanOrEqualTo(1));
  });
}
