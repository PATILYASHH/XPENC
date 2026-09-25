import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Loan ↔ Auto integration: creating a loan with "Auto-pay EMI" produces a
/// real G&L Auto rule, and an EMI rule never pays a loan past zero — it
/// trims the final payment and pauses itself once the loan is cleared.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<Money> balanceOf(int id) async => (await (db.select(
    db.accounts,
  )..where((a) => a.id.equals(id))).getSingle()).currentBalance;

  Future<List<RecurringRuleRow>> rules() => db.watchRecurringRules().first;

  test(
    'addLoan with auto-pay creates a monthly G&L rule for the EMI',
    () async {
      final cash = await cashId();
      final loan = await db.addLoan(
        name: 'Car Loan',
        principal: Money.fromRupees(100000),
        colorValue: 0xFF2563EB,
        iconKey: 'card',
        emiAmount: Money.fromRupees(5000),
        autoPayFromAccountId: cash,
        autoPayStartsOn: DateTime(2026, 10, 5),
      );

      final all = await rules();
      expect(all, hasLength(1));
      final rule = all.single;
      expect(rule.name, 'Car Loan EMI');
      expect(rule.toAccountId, loan);
      expect(rule.accountId, cash);
      expect(rule.amount, Money.fromRupees(5000));
      expect(rule.frequency, RecurringFrequency.monthly);
      expect(rule.nextDueDate, DateTime(2026, 10, 5));
      expect(rule.dayOfMonth, 5);
    },
  );

  test('auto-pay uses the rate-derived EMI when none is typed', () async {
    final cash = await cashId();
    await db.addLoan(
      name: 'Home Loan',
      principal: Money.fromRupees(100000),
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      interestRatePct: 10,
      tenureMonths: 12,
      startDate: DateTime(2026, 9, 1),
      autoPayFromAccountId: cash,
      autoPayStartsOn: DateTime(2026, 10, 1),
    );
    expect((await rules()).single.amount.rupees, closeTo(8791.59, 1));
  });

  test('auto-pay without any EMI is rejected and creates nothing', () async {
    final cash = await cashId();
    expect(
      () => db.addLoan(
        name: 'Loan',
        principal: Money.fromRupees(1000),
        colorValue: 0xFF2563EB,
        iconKey: 'card',
        autoPayFromAccountId: cash,
      ),
      throwsArgumentError,
    );
    expect(await rules(), isEmpty);
  });

  test('a basic loan EMI rule trims the last payment and pauses', () async {
    final cash = await cashId();
    final loan = await db.addLoan(
      name: 'Phone',
      principal: Money.fromRupees(2500),
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      emiAmount: Money.fromRupees(1000),
      autoPayFromAccountId: cash,
      autoPayStartsOn: DateTime(2026, 1, 10),
    );

    // Six months due, but only 2.5 EMIs are owed.
    final posted = await db.runDueRecurringRules(now: DateTime(2026, 6, 20));

    expect(posted, 3);
    expect(await balanceOf(loan), const Money.zero());
    final transfers = await (db.select(
      db.transactions,
    )..where((t) => t.toAccountId.equals(loan))).get();
    expect(transfers.map((t) => t.amount).toList(), [
      Money.fromRupees(1000),
      Money.fromRupees(1000),
      Money.fromRupees(500),
    ]);
    expect((await rules()).single.isActive, isFalse);

    // Paused: nothing more ever posts.
    expect(await db.runDueRecurringRules(now: DateTime(2027, 1, 1)), 0);
  });

  test('a rated loan EMI rule never pushes the balance past zero', () async {
    final cash = await cashId();
    final loan = await db.addLoan(
      name: 'Personal',
      principal: Money.fromRupees(10000),
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      interestRatePct: 12,
      tenureMonths: 3,
      startDate: DateTime(2026, 1, 1),
      categoryId:
          (await db.watchCategories(CategoryKind.expense).first).first.id,
      autoPayFromAccountId: cash,
      autoPayStartsOn: DateTime(2026, 2, 1),
    );

    await db.runDueRecurringRules(now: DateTime(2026, 12, 31));

    expect(await balanceOf(loan), const Money.zero());
    expect((await rules()).single.isActive, isFalse);
  });
}
