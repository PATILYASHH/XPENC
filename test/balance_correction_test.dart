import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// "Cash says ₹100, my wallet has ₹75": [AppDatabase.correctAccountBalance]
/// posts the difference as one Correction instead of a fake expense.
void main() {
  late AppDatabase db;
  late int cash;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    cash = (await db.watchAccounts().first)
        .firstWhere((a) => a.type == AccountType.cash)
        .id;
  });
  tearDown(() => db.close());

  Future<AccountRow> account(int id) =>
      (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

  Future<void> seedCash(int rupees) async {
    final salary = (await db.watchCategories(CategoryKind.income).first).first;
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(rupees),
      accountId: cash,
      categoryId: salary.id,
      date: DateTime.now().subtract(const Duration(days: 3)),
    );
  }

  test('correcting down posts a correctionOut for the difference', () async {
    await seedCash(100);
    final id = await db.correctAccountBalance(
      accountId: cash,
      actualBalance: Money.fromRupees(75),
      note: 'forgot chai',
    );

    expect((await account(cash)).currentBalance, Money.fromRupees(75));
    final tx = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id!))).getSingle();
    expect(tx.type, TxType.correctionOut);
    expect(tx.amount, Money.fromRupees(25));
    expect(tx.categoryId, isNull);
    expect(tx.note, 'forgot chai');
  });

  test('correcting up posts a correctionIn', () async {
    await seedCash(100);
    await db.correctAccountBalance(
      accountId: cash,
      actualBalance: Money.fromRupees(130),
    );
    final txs = await db.select(db.transactions).get();
    expect(txs.last.type, TxType.correctionIn);
    expect(txs.last.amount, Money.fromRupees(30));
    expect((await account(cash)).currentBalance, Money.fromRupees(130));
  });

  test('a correction is never income or expense', () async {
    await seedCash(100);
    await db.correctAccountBalance(
      accountId: cash,
      actualBalance: Money.fromRupees(60),
    );
    final now = DateTime.now();
    final totals = await db
        .watchMonthTotals(DateTime(now.year, now.month), 1)
        .first;
    expect(totals.expense, const Money.zero());
    expect(totals.income, Money.fromRupees(100));
  });

  test('nothing is posted when the balance already matches', () async {
    await seedCash(100);
    final id = await db.correctAccountBalance(
      accountId: cash,
      actualBalance: Money.fromRupees(100),
    );
    expect(id, isNull);
    expect(await db.select(db.transactions).get(), hasLength(1));
  });

  test('deleting the correction puts the old balance back', () async {
    await seedCash(100);
    final id = await db.correctAccountBalance(
      accountId: cash,
      actualBalance: Money.fromRupees(75),
    );
    await db.deleteTransaction(id!);
    expect((await account(cash)).currentBalance, Money.fromRupees(100));
  });

  test('a full balance recompute keeps the corrected balance', () async {
    await seedCash(100);
    await db.correctAccountBalance(
      accountId: cash,
      actualBalance: Money.fromRupees(75),
    );
    await db.recalculateBalances();
    expect((await account(cash)).currentBalance, Money.fromRupees(75));
  });

  test('a credit card is corrected on what is owed', () async {
    final card = await db.addAccount(
      name: 'Amex',
      type: AccountType.card,
      cardKind: CardKind.credit,
      colorValue: 0xFF16A34A,
      iconKey: 'card',
      openingBalance: Money.fromRupees(-500),
    );
    // Statement says only ₹300 is outstanding.
    await db.correctAccountBalance(
      accountId: card,
      actualBalance: Money.fromRupees(-300),
    );
    expect((await account(card)).currentBalance, Money.fromRupees(-300));
    final tx = (await db.select(db.transactions).get()).single;
    expect(tx.type, TxType.correctionIn);
    expect(tx.amount, Money.fromRupees(200));
  });

  test('a loan can be corrected, a debit card cannot', () async {
    final loan = await db.addLoan(
      name: 'Car',
      principal: Money.fromRupees(100000),
      colorValue: 0xFF2563EB,
      iconKey: 'card',
    );
    await db.correctAccountBalance(
      accountId: loan,
      actualBalance: Money.fromRupees(-98000),
    );
    expect((await account(loan)).currentBalance, Money.fromRupees(-98000));

    final bank = await db.addAccount(
      name: 'HDFC',
      type: AccountType.bank,
      colorValue: 0xFF2563EB,
      iconKey: 'bank',
      openingBalance: Money.fromRupees(1000),
    );
    final debit = await db.addAccount(
      name: 'HDFC Debit',
      type: AccountType.card,
      cardKind: CardKind.debit,
      linkedAccountId: bank,
      colorValue: 0xFF2563EB,
      iconKey: 'card',
      openingBalance: const Money.zero(),
    );
    expect(
      () => db.correctAccountBalance(
        accountId: debit,
        actualBalance: Money.fromRupees(10),
      ),
      throwsArgumentError,
    );
  });

  test('a correction cannot carry a category', () async {
    final food = (await db.watchCategories(CategoryKind.expense).first).first;
    expect(
      () => db.addTransaction(
        type: TxType.correctionOut,
        amount: Money.fromRupees(10),
        accountId: cash,
        categoryId: food.id,
        date: DateTime.now(),
      ),
      throwsArgumentError,
    );
  });
}
