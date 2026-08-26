import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// Group expenses are pure composition over the existing addTransaction/
/// addPersonEntry — no new money-movement primitive. These tests exist to
/// prove that composition is correct: every paisa lands where the split
/// method says it should, and deleting a group expense always reverses it
/// exactly, even if a share was already touched directly elsewhere.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;
  Future<int> catId(CategoryKind k, String n) async =>
      (await db.watchCategories(k).first).firstWhere((c) => c.name == n).id;

  Future<Money> balance(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

  Future<void> seedCash(Money amount) async {
    await db.addTransaction(
      type: TxType.income,
      amount: amount,
      accountId: await cashId(),
      categoryId: await catId(CategoryKind.income, 'Salary'),
      date: DateTime(2026, 7, 1),
    );
  }

  Future<(int groupId, int ram, int shyam)> seedGroup() async {
    final ram = await db.addPerson('Ram');
    final shyam = await db.addPerson('Shyam');
    final groupId = await db.addGroup('Trip');
    await db.setGroupMembers(groupId, {ram, shyam});
    return (groupId, ram, shyam);
  }

  group('addGroupExpense — I paid', () {
    test('my share posts as a real expense, everyone else owes me', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final (groupId, ram, shyam) = await seedGroup();

      final expenseId = await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(900),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram, shyam},
      );

      // 900 split 3 ways is exact — no rounding to worry about here.
      expect(await balance(cash), Money.fromRupees(5000 - 900));
      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(300));
      expect(await db.watchPersonBalance(shyam).first, Money.fromRupees(300));

      final shares = await (db.select(
        db.groupExpenseShares,
      )..where((s) => s.groupExpenseId.equals(expenseId))).get();
      expect(shares.length, 3);

      final mine = shares.firstWhere((s) => s.personId == null);
      expect(mine.transactionId, isNotNull);
      expect(mine.personEntryId, isNull);
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(mine.transactionId!))).getSingle();
      expect(tx.type, TxType.expense);
      expect(tx.categoryId, food);

      final ramShare = shares.firstWhere((s) => s.personId == ram);
      expect(ramShare.personEntryId, isNotNull);
      expect(ramShare.transactionId, isNull);
      final ramEntry = await (db.select(
        db.personEntries,
      )..where((e) => e.id.equals(ramShare.personEntryId!))).getSingle();
      expect(ramEntry.direction, PersonDirection.theyOwe);
      final ramTx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(ramEntry.transactionId!))).getSingle();
      expect(ramTx.type, TxType.personOut);
    });

    test('a non-divisible total sums exactly, no paisa lost or gained', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final (groupId, ram, shyam) = await seedGroup();

      await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(100), // 10000 paise / 3
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram, shyam},
      );

      expect(await balance(cash), Money.fromRupees(4900));
      final ramBal = await db.watchPersonBalance(ram).first;
      final shyamBal = await db.watchPersonBalance(shyam).first;
      expect(ramBal + shyamBal, Money.fromPaise(6666)); // 3333 + 3333
    });

    test('percentage split sums exactly', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final (groupId, ram, shyam) = await seedGroup();

      await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(250),
        splitMethod: GroupSplitMethod.percentage,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram, shyam},
        percentBasisPoints: {null: 5000, ram: 3000, shyam: 2000},
      );

      expect(await balance(cash), Money.fromRupees(5000 - 250));
      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(75));
      expect(await db.watchPersonBalance(shyam).first, Money.fromRupees(50));
    });

    test('manual split sums exactly', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final (groupId, ram, shyam) = await seedGroup();

      await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(300),
        splitMethod: GroupSplitMethod.manual,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram, shyam},
        manualAmounts: {
          null: Money.fromRupees(150),
          ram: Money.fromRupees(100),
          shyam: Money.fromRupees(50),
        },
      );

      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(100));
      expect(await db.watchPersonBalance(shyam).first, Money.fromRupees(50));
    });
  });

  group('addGroupExpense — someone else paid', () {
    test('my share becomes an "I owe them" entry, no money moves from me',
        () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final (groupId, ram, shyam) = await seedGroup();

      final expenseId = await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(900),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        payerId: ram, // Ram paid
        participantIds: {null, ram, shyam},
      );

      // No account of mine moved — Ram paid, not me.
      expect(await balance(cash), Money.fromRupees(5000));
      expect(await db.watchPersonBalance(ram).first, Money.fromRupees(-300));

      final shares = await (db.select(
        db.groupExpenseShares,
      )..where((s) => s.groupExpenseId.equals(expenseId))).get();
      expect(shares.length, 3);

      final mine = shares.firstWhere((s) => s.personId == null);
      expect(mine.personEntryId, isNotNull);
      final mineEntry = await (db.select(
        db.personEntries,
      )..where((e) => e.id.equals(mine.personEntryId!))).getSingle();
      expect(mineEntry.direction, PersonDirection.iOwe);
      expect(mineEntry.personId, ram);
      expect(mineEntry.accountId, isNull); // tracking only, no money moved

      // The payer's own share is real (their money) but this schema can't
      // track it as anyone's debt to anyone — both link ids stay null.
      final ramShare = shares.firstWhere((s) => s.personId == ram);
      expect(ramShare.personEntryId, isNull);
      expect(ramShare.transactionId, isNull);

      // Shyam owes Ram, not me — unrepresentable, computed but unpersisted.
      final shyamShare = shares.firstWhere((s) => s.personId == shyam);
      expect(shyamShare.personEntryId, isNull);
      expect(shyamShare.transactionId, isNull);
      expect(shyamShare.amount, Money.fromRupees(300));
      // And critically: it must NOT show up as owed to me.
      expect(await db.watchPersonBalance(shyam).first, Money.zero());
    });
  });

  group('deleteGroupExpense', () {
    test('reverses every tracked share; balances return to zero', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final (groupId, ram, shyam) = await seedGroup();

      final expenseId = await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(900),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram, shyam},
      );

      await db.deleteGroupExpense(expenseId);

      expect(await balance(cash), Money.fromRupees(5000));
      expect(await db.watchPersonBalance(ram).first, Money.zero());
      expect(await db.watchPersonBalance(shyam).first, Money.zero());
      final remainingShares = await (db.select(
        db.groupExpenseShares,
      )..where((s) => s.groupExpenseId.equals(expenseId))).get();
      expect(remainingShares, isEmpty);
      final remainingExpense = await (db.select(
        db.groupExpenses,
      )..where((e) => e.id.equals(expenseId))).getSingleOrNull();
      expect(remainingExpense, isNull);
    });

    test('does not throw if a share\'s linked entry was already deleted '
        'directly from that person\'s own ledger', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final (groupId, ram, shyam) = await seedGroup();

      final expenseId = await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(900),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram, shyam},
      );

      final shares = await (db.select(
        db.groupExpenseShares,
      )..where((s) => s.groupExpenseId.equals(expenseId))).get();
      final ramShare = shares.firstWhere((s) => s.personId == ram);
      // Simulate the user deleting Ram's entry directly from his own page.
      await db.deletePersonEntry(ramShare.personEntryId!);

      await expectLater(db.deleteGroupExpense(expenseId), completes);

      // Shyam's share (and my own expense transaction) still got cleaned up.
      expect(await db.watchPersonBalance(shyam).first, Money.zero());
      expect(await balance(cash), Money.fromRupees(5000));
    });
  });
}
