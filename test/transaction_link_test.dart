import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// GitHub #64: a manual, bidirectional link between two transactions (e.g.
/// an old charge and its refund) — see the doc on `TransactionLinks` and
/// `AppDatabase.addTransactionLink`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> foodCategory() async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Food')
          .id;

  Future<int> addExpense({required String note}) async {
    final cash = await cashId();
    final food = await foodCategory();
    return db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(100),
      accountId: cash,
      categoryId: food,
      date: DateTime(2026, 7, 9),
      note: note,
    );
  }

  test('linking two transactions makes each reach the other', () async {
    final a = await addExpense(note: 'Charge');
    final b = await addExpense(note: 'Refund');

    await db.addTransactionLink(a, b);

    final fromA = await db.linkedTransactions(a);
    expect(fromA.map((t) => t.id), [b]);
    final fromB = await db.linkedTransactions(b);
    expect(fromB.map((t) => t.id), [a]);
  });

  test('linking is order-independent (B, A stores the same pair as A, B)', () async {
    final a = await addExpense(note: 'Charge');
    final b = await addExpense(note: 'Refund');

    await db.addTransactionLink(b, a);

    expect((await db.linkedTransactions(a)).map((t) => t.id), [b]);
    expect((await db.linkedTransactions(b)).map((t) => t.id), [a]);
  });

  test('a transaction can be linked to more than one other', () async {
    final a = await addExpense(note: 'Charge');
    final b = await addExpense(note: 'Part refund 1');
    final c = await addExpense(note: 'Part refund 2');

    await db.addTransactionLink(a, b);
    await db.addTransactionLink(a, c);

    final links = await db.linkedTransactions(a);
    expect(links.map((t) => t.id).toSet(), {b, c});
  });

  test('linking the same pair twice does not duplicate the link', () async {
    final a = await addExpense(note: 'Charge');
    final b = await addExpense(note: 'Refund');

    await db.addTransactionLink(a, b);
    await db.addTransactionLink(a, b);
    await db.addTransactionLink(b, a);

    expect(await db.linkedTransactions(a), hasLength(1));
  });

  test('refuses to link a transaction to itself', () async {
    final a = await addExpense(note: 'Charge');
    expect(() => db.addTransactionLink(a, a), throwsArgumentError);
  });

  test('an unlinked transaction has no links', () async {
    final a = await addExpense(note: 'Solo');
    expect(await db.linkedTransactions(a), isEmpty);
  });

  test('removeTransactionLink un-links both directions', () async {
    final a = await addExpense(note: 'Charge');
    final b = await addExpense(note: 'Refund');
    await db.addTransactionLink(a, b);

    await db.removeTransactionLink(b, a);

    expect(await db.linkedTransactions(a), isEmpty);
    expect(await db.linkedTransactions(b), isEmpty);
  });

  test('deleting a transaction drops its links instead of orphaning them', () async {
    final a = await addExpense(note: 'Charge');
    final b = await addExpense(note: 'Refund');
    final c = await addExpense(note: 'Unrelated');
    await db.addTransactionLink(a, b);
    await db.addTransactionLink(a, c);

    await db.deleteTransaction(a);

    expect(await db.linkedTransactions(b), isEmpty);
    expect(await db.linkedTransactions(c), isEmpty);
    final links = await (db.select(db.transactionLinks)).get();
    expect(links, isEmpty);
  });
}
