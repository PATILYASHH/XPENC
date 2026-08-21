import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #55: a cash expense where part of the change received lands in a
/// different account (e.g. coins) instead of back in the paying one. The
/// expense leg carries the real cost and the category; the change leg is an
/// ordinary transfer, linked via `paymentGroupId` the same way a hybrid
/// payment's legs are — see `AppDatabase.addExpenseWithChange`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> coinsId() => db.addAccount(
    name: 'Coins',
    type: AccountType.cash,
    colorValue: 0xFFF59E0B,
    iconKey: 'cash',
    openingBalance: const Money.zero(),
  );

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

  Future<List<TransactionRow>> allOfType(TxType type) =>
      (db.select(db.transactions)..where((t) => t.type.equalsValue(type)))
          .get();

  test(
    'debits the real cost from cash and credits the change elsewhere',
    () async {
      final cash = await cashId();
      final coins = await coinsId();
      final food = await foodCategory();
      final cashBefore = await balanceOf(cash);
      final coinsBefore = await balanceOf(coins);

      final ids = await db.addExpenseWithChange(
        amount: Money.fromRupees(40.60),
        accountId: cash,
        categoryId: food,
        changeAccountId: coins,
        changeAmount: Money.fromRupees(4.40),
        date: DateTime(2026, 8, 20),
        note: 'Supermarket',
      );

      expect(ids, hasLength(2));
      expect(
        await balanceOf(cash),
        cashBefore - Money.fromRupees(40.60) - Money.fromRupees(4.40),
      );
      expect(await balanceOf(coins), coinsBefore + Money.fromRupees(4.40));

      final rows = await db.paymentGroupLegs(ids.first);
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.id), containsAll(ids));
      expect(rows.every((r) => r.paymentGroupId == ids.first), isTrue);

      final expenseLeg = rows.firstWhere((r) => r.id == ids.first);
      expect(expenseLeg.type, TxType.expense);
      expect(expenseLeg.amount, Money.fromRupees(40.60));
      expect(expenseLeg.categoryId, food);
      expect(expenseLeg.note, 'Supermarket');

      final changeLeg = rows.firstWhere((r) => r.id == ids.last);
      expect(changeLeg.type, TxType.transfer);
      expect(changeLeg.amount, Money.fromRupees(4.40));
      expect(changeLeg.accountId, cash);
      expect(changeLeg.toAccountId, coins);
      expect(changeLeg.categoryId, isNull);
    },
  );

  test('refuses change routed back into the same account', () async {
    final cash = await cashId();
    final food = await foodCategory();
    expect(
      () => db.addExpenseWithChange(
        amount: Money.fromRupees(40.60),
        accountId: cash,
        categoryId: food,
        changeAccountId: cash,
        changeAmount: Money.fromRupees(4.40),
        date: DateTime(2026, 8, 20),
      ),
      throwsArgumentError,
    );
  });

  test('a bad change leg (e.g. zero amount) rolls back the expense too', () async {
    final cash = await cashId();
    final coins = await coinsId();
    final food = await foodCategory();
    final cashBefore = await balanceOf(cash);

    await expectLater(
      db.addExpenseWithChange(
        amount: Money.fromRupees(40.60),
        accountId: cash,
        categoryId: food,
        changeAccountId: coins,
        changeAmount: const Money.zero(),
        date: DateTime(2026, 8, 20),
      ),
      throwsArgumentError,
    );

    expect(await balanceOf(cash), cashBefore);
  });

  test(
    'deleting the expense leg ungroups the change leg instead of orphaning it',
    () async {
      final cash = await cashId();
      final coins = await coinsId();
      final food = await foodCategory();

      final ids = await db.addExpenseWithChange(
        amount: Money.fromRupees(40.60),
        accountId: cash,
        categoryId: food,
        changeAccountId: coins,
        changeAmount: Money.fromRupees(4.40),
        date: DateTime(2026, 8, 20),
      );

      await db.deleteTransaction(ids.first);

      final survivor = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(ids.last))).getSingle();
      expect(survivor.paymentGroupId, isNull);
      expect(survivor.type, TxType.transfer);
      expect(await db.paymentGroupLegs(ids.last), isEmpty);
    },
  );

  test('the change leg never carries a payee (transfers cannot)', () async {
    final cash = await cashId();
    final coins = await coinsId();
    final food = await foodCategory();

    final ids = await db.addExpenseWithChange(
      amount: Money.fromRupees(40.60),
      accountId: cash,
      categoryId: food,
      changeAccountId: coins,
      changeAmount: Money.fromRupees(4.40),
      payee: 'Supermarket',
      date: DateTime(2026, 8, 20),
    );

    final changeLeg = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(ids.last))).getSingle();
    expect(changeLeg.payee, isNull);
  });

  test(
    'the anchor leg alone still counts toward reports; the transfer never does',
    () async {
      final cash = await cashId();
      final bank = await bankId();
      final coins = await coinsId();
      final food = await foodCategory();

      await db.addExpenseWithChange(
        amount: Money.fromRupees(40.60),
        accountId: cash,
        categoryId: food,
        changeAccountId: coins,
        changeAmount: Money.fromRupees(4.40),
        date: DateTime(2026, 8, 20),
      );

      final expenses = await allOfType(TxType.expense);
      expect(expenses, hasLength(1));
      expect(expenses.single.amount, Money.fromRupees(40.60));

      final transfers = await allOfType(TxType.transfer);
      expect(transfers, hasLength(1));
      expect(transfers.single.amount, Money.fromRupees(4.40));

      // Sanity: bank account untouched by any of this.
      expect(
        (await db.watchAccounts().first)
            .firstWhere((a) => a.id == bank)
            .currentBalance,
        Money.fromRupees(10000),
      );
    },
  );
}
