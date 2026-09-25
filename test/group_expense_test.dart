import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/group_split_math.dart';
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

    test(
      'a non-divisible total sums exactly, no paisa lost or gained',
      () async {
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
      },
    );

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
    test(
      'my share becomes an "I owe them" entry, no money moves from me',
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
      },
    );
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

  group('auto-archiving a settled group', () {
    test(
      'once every member repays in full, the group and its members '
      'auto-archive; the expense history that made it "settled" stays',
      () async {
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

        var groups = await db.watchGroups().first;
        expect(
          groups.map((g) => g.id),
          contains(groupId),
          reason: 'still owed money — must stay visible',
        );

        // Both members pay me back in full.
        await db.addPersonEntry(
          personId: ram,
          direction: PersonDirection.iOwe,
          amount: Money.fromRupees(300),
          date: DateTime(2026, 7, 20),
        );
        await db.addPersonEntry(
          personId: shyam,
          direction: PersonDirection.iOwe,
          amount: Money.fromRupees(300),
          date: DateTime(2026, 7, 20),
        );

        final activePersons = await db.watchPersons().first;
        expect(
          activePersons.map((p) => p.id),
          isNot(anyOf(contains(ram), contains(shyam))),
        );
        final archivedPersons = await db.watchArchivedPersons().first;
        expect(archivedPersons.map((p) => p.id), containsAll([ram, shyam]));

        groups = await db.watchGroups().first;
        expect(groups.map((g) => g.id), isNot(contains(groupId)));
        final archivedGroups = await db.watchArchivedGroups().first;
        expect(archivedGroups.map((g) => g.id), contains(groupId));

        // The expense itself is history, not undone by the settlement.
        final expense = await (db.select(
          db.groupExpenses,
        )..where((e) => e.id.equals(expenseId))).getSingleOrNull();
        expect(expense, isNotNull);
      },
    );
  });

  group('group-only balances', () {
    /// A member's amount in [groupId], the way the group screen shows it.
    Future<Money> groupDue(int groupId, int personId) async {
      final groupOf = await db.watchPersonEntryGroupIds().first;
      final entries = await db.watchPersonEntries(personId).first;
      final dues = allocateGroupDues([
        for (final e in entries)
          (
            id: e.id,
            date: e.date,
            signed: e.direction == PersonDirection.theyOwe
                ? e.amount
                : -e.amount,
            groupId: groupOf[e.id],
          ),
      ]);
      return dues[groupId] ?? const Money.zero();
    }

    Future<({int abc, int bcd, int hotel})> seedHotel() async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final abc = await db.addPerson('ABC');
      final bcd = await db.addPerson('BCD');
      await db.addPersonEntry(
        personId: abc,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 7, 1),
      );
      final hotel = await db.addGroup('Hotel');
      await db.setGroupMembers(hotel, {abc, bcd});
      await db.addGroupExpense(
        groupId: hotel,
        amount: Money.fromRupees(3000),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, abc, bcd},
      );
      return (abc: abc, bcd: bcd, hotel: hotel);
    }

    test(
      'a group shows only its own split; the person total includes both '
      '(ABC owes 500 individually, then a 3,000 hotel bill split 3 ways)',
      () async {
        final (:abc, :bcd, :hotel) = await seedHotel();

        expect(await groupDue(hotel, abc), Money.fromRupees(1000));
        expect(await groupDue(hotel, bcd), Money.fromRupees(1000));
        expect(await db.watchPersonBalance(abc).first, Money.fromRupees(1500));
        expect(await db.watchPersonBalance(bcd).first, Money.fromRupees(1000));
      },
    );

    test('a repayment on the person comes off the group first', () async {
      final (:abc, :bcd, :hotel) = await seedHotel();

      await db.addPersonEntry(
        personId: abc,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(1000),
        date: DateTime(2026, 7, 10),
      );

      expect(await groupDue(hotel, abc), const Money.zero());
      // The individual 500 is what's left.
      expect(await db.watchPersonBalance(abc).first, Money.fromRupees(500));
      expect(await groupDue(hotel, bcd), Money.fromRupees(1000));
    });

    test('a partial repayment reduces the group amount', () async {
      final (:abc, bcd: _, :hotel) = await seedHotel();
      await db.addPersonEntry(
        personId: abc,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(400),
        date: DateTime(2026, 7, 10),
      );
      expect(await groupDue(hotel, abc), Money.fromRupees(600));
    });

    test('an older repayment never clears a newer group bill', () async {
      final cash = await cashId();
      await seedCash(Money.fromRupees(5000));
      final food = await catId(CategoryKind.expense, 'Food');
      final (groupId, ram, _) = await seedGroup();
      // Ram borrowed 500 and paid it back — all before the trip.
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 6, 1),
      );
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(500),
        date: DateTime(2026, 6, 20),
      );
      await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(900),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram},
      );
      expect(await groupDue(groupId, ram), Money.fromRupees(450));
    });

    test('when a member paid, the group shows what I owe them', () async {
      final (groupId, ram, shyam) = await seedGroup();
      await db.addGroupExpense(
        groupId: groupId,
        amount: Money.fromRupees(900),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        payerId: ram,
        participantIds: {null, ram, shyam},
      );

      expect(await groupDue(groupId, ram), Money.fromRupees(-300));
      // Shyam's share is owed to Ram, not me — never tracked here.
      expect(await groupDue(groupId, shyam), const Money.zero());

      // Paying Ram back settles it.
      await db.addPersonEntry(
        personId: ram,
        direction: PersonDirection.theyOwe,
        amount: Money.fromRupees(300),
        date: DateTime(2026, 7, 8),
      );
      expect(await groupDue(groupId, ram), const Money.zero());
    });

    test('a group settles and auto-archives even while a member still owes '
        'individually', () async {
      final (:abc, :bcd, :hotel) = await seedHotel();
      await db.addPersonEntry(
        personId: abc,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(1000),
        date: DateTime(2026, 7, 10),
      );
      await db.addPersonEntry(
        personId: bcd,
        direction: PersonDirection.iOwe,
        amount: Money.fromRupees(1000),
        date: DateTime(2026, 7, 10),
      );

      final archived = await db.watchArchivedGroups().first;
      expect(archived.map((g) => g.id), contains(hotel));
      expect(await db.watchPersonBalance(abc).first, Money.fromRupees(500));
    });
  });

  group('allocateGroupDues', () {
    Money r(num v) => Money.fromRupees(v);
    PersonLedgerItem item(int id, int day, num rupees, [int? groupId]) => (
      id: id,
      date: DateTime(2026, 7, day),
      signed: r(rupees),
      groupId: groupId,
    );

    test('repayments settle the oldest group first, then the next', () {
      final dues = allocateGroupDues([
        item(1, 1, 300, 10),
        item(2, 2, 200, 20),
        item(3, 5, -400),
      ]);
      expect(dues[10], const Money.zero());
      expect(dues[20], r(100));
    });

    test('a lending entry in the same direction never reduces a group', () {
      final dues = allocateGroupDues([item(1, 1, 300, 10), item(2, 2, 500)]);
      expect(dues[10], r(300));
    });

    test('each payment only settles groups owed the other way', () {
      final dues = allocateGroupDues([
        item(1, 1, 500),
        item(2, 3, 1000, 10), // they owe me 1,000 in group 10
        item(3, 4, -250, 20), // I owe them 250 in group 20
        item(4, 6, -700), // they repay 700 -> group 10
        item(5, 7, 100), // I pay them 100 -> group 20
      ]);
      expect(dues[10], r(300));
      expect(dues[20], r(-150));
    });
  });
}
