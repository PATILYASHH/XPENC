import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// A person picked as an expense/income payee: shown on their page, never
/// counted in owe/due.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<TransactionRow> tx(int id) async => (await db.transactionById(id))!;

  test(
    'an expense can name a person as payee without touching owe/due',
    () async {
      final father = await db.addPerson('Father');
      final id = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(1000),
        accountId: await cashId(),
        date: DateTime(2026, 9, 29),
        payee: 'Father',
        personId: father,
      );
      expect((await tx(id)).personId, father);
      expect(await db.watchPersonBalance(father).first, const Money.zero());
    },
  );

  test('a transfer still cannot name a person', () async {
    final p = await db.addPerson('A');
    final bank = await db.addAccount(
      name: 'Bank',
      type: AccountType.bank,
      openingBalance: Money.fromRupees(100),
      colorValue: 0,
      iconKey: 'bank',
    );
    final cash = await cashId();
    expect(
      () => db.addTransaction(
        type: TxType.transfer,
        amount: Money.fromRupees(10),
        accountId: cash,
        toAccountId: bank,
        personId: p,
        date: DateTime(2026, 9, 29),
      ),
      throwsArgumentError,
    );
  });

  test(
    'connect links every row of a payee and takes the person name',
    () async {
      final cash = await cashId();
      final p = await db.addPerson('Rahul Kumar');
      final id = await db.addTransaction(
        type: TxType.expense,
        amount: Money.fromRupees(50),
        accountId: cash,
        date: DateTime(2026, 9, 1),
        payee: 'Rahul',
      );
      await db.connectPayeeToPerson(payee: 'Rahul', personId: p);
      final row = await tx(id);
      expect(row.personId, p);
      expect(row.payee, 'Rahul Kumar');

      await db.disconnectPersonPayee(p);
      final after = await tx(id);
      expect(after.personId, isNull);
      expect(after.payee, 'Rahul Kumar');
    },
  );

  test('renaming the person renames their payee rows', () async {
    final p = await db.addPerson('Dad');
    final id = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(20),
      accountId: await cashId(),
      date: DateTime(2026, 9, 1),
      payee: 'Dad',
      personId: p,
    );
    await db.updatePerson(id: p, name: 'Father');
    expect((await tx(id)).payee, 'Father');
  });

  test('deleting the person keeps their payee spending, unlinked', () async {
    final cash = await cashId();
    final p = await db.addPerson('Father');
    final id = await db.addTransaction(
      type: TxType.expense,
      amount: Money.fromRupees(1000),
      accountId: cash,
      date: DateTime(2026, 9, 29),
      payee: 'Father',
      personId: p,
    );
    await db.deletePerson(p);
    final row = await tx(id);
    expect(row.personId, isNull);
    expect(row.payee, 'Father');
  });

  test('a repayment counted as income can be recorded', () async {
    final cash = await cashId();
    final p = await db.addPerson('Friend');
    final salary = (await db.watchCategories(CategoryKind.income).first)
        .firstWhere((c) => c.name == 'Salary')
        .id;
    await db.addPersonEntry(
      personId: p,
      direction: PersonDirection.iOwe,
      amount: Money.fromRupees(300),
      date: DateTime(2026, 9, 29),
      accountId: cash,
      categoryId: salary,
    );
    expect(await db.watchPersonBalance(p).first, Money.fromRupees(-300));
  });
}
