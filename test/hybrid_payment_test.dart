import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #43: one purchase paid from several accounts at once (part bank,
/// part cash, ...). Each leg posts as an ordinary transaction; what makes
/// them a "hybrid payment" is only `paymentGroupId` tying them together —
/// see the doc on `Transactions.paymentGroupId` and
/// `AppDatabase.addHybridPaymentTransaction`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> bankId() => db.addAccount(
    name: 'Bank',
    type: AccountType.bank,
    colorValue: 0xFF2563EB,
    iconKey: 'bank',
    openingBalance: Money.fromRupees(10000),
  );

  Future<int> foodCategory() async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;

  Future<Money> balanceOf(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

  test(
    'splits one purchase across two accounts, each debited its share',
    () async {
      final cash = await cashId();
      final bank = await bankId();
      final food = await foodCategory();
      final cashBefore = await balanceOf(cash);
      final bankBefore = await balanceOf(bank);

      final ids = await db.addHybridPaymentTransaction(
        legs: [
          (accountId: bank, amount: Money.fromRupees(2500)),
          (accountId: cash, amount: Money.fromRupees(500)),
        ],
        categoryId: food,
        date: DateTime(2026, 7, 9),
        note: 'Dinner',
      );

      expect(ids, hasLength(2));
      expect(await balanceOf(bank), bankBefore - Money.fromRupees(2500));
      expect(await balanceOf(cash), cashBefore - Money.fromRupees(500));

      final rows = await db.paymentGroupLegs(ids.first);
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.id), containsAll(ids));
      expect(rows.every((r) => r.paymentGroupId == ids.first), isTrue);
      expect(rows.every((r) => r.categoryId == food), isTrue);
      expect(rows.every((r) => r.note == 'Dinner'), isTrue);
    },
  );

  test('an ordinary transaction has no group legs', () async {
    final cash = await cashId();
    final food = await foodCategory();
    final id = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(100),
      accountId: cash,
      categoryId: food,
      date: DateTime(2026, 7, 9),
    );
    expect(await db.paymentGroupLegs(id), isEmpty);
  });

  test('refuses fewer than two legs', () async {
    final cash = await cashId();
    expect(
      () => db.addHybridPaymentTransaction(
        legs: [(accountId: cash, amount: Money.fromRupees(100))],
        date: DateTime(2026, 7, 9),
      ),
      throwsArgumentError,
    );
  });

  test('one bad leg (e.g. into a goal account) rolls back every leg', () async {
    final cash = await cashId();
    final bank = await bankId();
    final goalId = await db.addGoal(
      name: 'Trip',
      targetAmount: Money.fromRupees(20000),
      colorValue: 0xFF2563EB,
      iconKey: 'savings',
    );
    final cashBefore = await balanceOf(cash);

    await expectLater(
      db.addHybridPaymentTransaction(
        legs: [
          (accountId: cash, amount: Money.fromRupees(100)),
          (accountId: goalId, amount: Money.fromRupees(50)),
        ],
        date: DateTime(2026, 7, 9),
      ),
      throwsArgumentError,
    );

    expect(await balanceOf(cash), cashBefore);
    final bankRow = (await db.watchAccounts().first).firstWhere(
      (a) => a.id == bank,
    );
    expect(bankRow.currentBalance, Money.fromRupees(10000));
  });

  test(
    'deleting the anchor leg ungroups the survivors instead of orphaning them',
    () async {
      final cash = await cashId();
      final bank = await bankId();

      final ids = await db.addHybridPaymentTransaction(
        legs: [
          (accountId: bank, amount: Money.fromRupees(2500)),
          (accountId: cash, amount: Money.fromRupees(500)),
        ],
        date: DateTime(2026, 7, 9),
      );

      await db.deleteTransaction(ids.first);

      final survivor = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(ids.last))).getSingle();
      expect(survivor.paymentGroupId, isNull);
      expect(await db.paymentGroupLegs(ids.last), isEmpty);
    },
  );
}
