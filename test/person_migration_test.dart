import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Before v3, a person entry adjusted the account balance directly and created
/// no ledger row. `recalculateBalances` now reads only `transactions`, so such
/// an entry would silently stop counting.
///
/// `backfillPersonTransactions()` repairs them. It runs in the v2→v3 migration
/// AND on every open, so a half-finished migration cannot lose money.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<Money> balance(int id) async =>
      (await db.watchAccounts().first).firstWhere((a) => a.id == id).currentBalance;

  /// Exactly what the v2 code produced: an entry with an account, no linked
  /// transaction, and a balance already adjusted by hand.
  Future<int> insertLegacyEntry({
    required int personId,
    required int accountId,
    required PersonDirection direction,
    required Money amount,
  }) async {
    final id = await db.into(db.personEntries).insert(
          PersonEntriesCompanion.insert(
            personId: personId,
            direction: direction,
            amount: amount,
            date: DateTime(2026, 7, 5),
            accountId: Value(accountId),
          ),
        );
    // The old code's direct balance poke.
    final delta = direction == PersonDirection.theyOwe ? -amount : amount;
    await db.customUpdate(
      'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
      variables: [Variable.withInt(delta.paise), Variable.withInt(accountId)],
      updates: {db.accounts},
    );
    return id;
  }

  test('a legacy loan gets a ledger row and the balance is unchanged', () async {
    final cash = await cashId();
    await db.addTransaction(
      type: TxType.income,
      amount: Money.fromRupees(5000),
      accountId: cash,
      categoryId: (await db.watchCategories(CategoryKind.income).first)
          .firstWhere((c) => c.name == 'Salary')
          .id,
      date: DateTime(2026, 7, 1),
    );

    final ram = await db.addPerson('Ram');
    await insertLegacyEntry(
      personId: ram,
      accountId: cash,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
    );

    // The v2 world: balance already reduced, but no ledger row exists.
    expect(await balance(cash), Money.fromRupees(4500));
    expect(await db.watchTransactions().first, hasLength(1));

    final repaired = await db.backfillPersonTransactions();

    expect(repaired, 1);
    final txs = await db.watchTransactions().first;
    expect(txs, hasLength(2));
    final loan = txs.firstWhere((t) => t.type == TxType.personOut);
    expect(loan.personId, ram);
    expect(loan.amount, Money.fromRupees(500));

    // The balance must be exactly what it was — not double-counted.
    expect(await balance(cash), Money.fromRupees(4500));
    expect(await db.watchNetWorth().first, Money.fromRupees(4500));

    final entry = (await db.watchPersonEntries(ram).first).single;
    expect(entry.transactionId, loan.id);
  });

  test('a legacy borrow is repaired the other way', () async {
    final cash = await cashId();
    final ram = await db.addPerson('Ram');
    await insertLegacyEntry(
      personId: ram,
      accountId: cash,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(2000),
    );

    expect(await balance(cash), Money.fromRupees(2000));
    await db.backfillPersonTransactions();

    final loan = (await db.watchTransactions().first).single;
    expect(loan.type, TxType.personIn);
    expect(await balance(cash), Money.fromRupees(2000));
  });

  test('repair is idempotent — running it twice changes nothing', () async {
    final cash = await cashId();
    final ram = await db.addPerson('Ram');
    await insertLegacyEntry(
      personId: ram,
      accountId: cash,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
    );

    expect(await db.backfillPersonTransactions(), 1);
    expect(await db.backfillPersonTransactions(), 0);
    expect(await db.watchTransactions().first, hasLength(1));
    expect(await balance(cash), Money.fromRupees(-500));
  });

  test('an entry with no account is left alone (no money ever moved)', () async {
    final ram = await db.addPerson('Ram');
    await db.addPersonEntry(
      personId: ram,
      direction: PersonDirection.theyOwe,
      amount: Money.fromRupees(500),
      date: DateTime(2026, 7, 5),
    );

    expect(await db.backfillPersonTransactions(), 0);
    expect(await db.watchTransactions().first, isEmpty);
    expect(await db.watchPersonBalance(ram).first, Money.fromRupees(500));
  });
}
