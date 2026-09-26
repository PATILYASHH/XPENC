import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/group_split_math.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// "Who owes whom" math and the queries that feed it and the group tags.
void main() {
  Money r(int rupees) => Money.fromRupees(rupees);

  group('computeGroupDebts', () {
    test('a member owes the payer their share; the pair nets out', () {
      // 2 paid 300 split with 3 (150 each); 3 paid 100 split with 2 (50 each).
      final debts = computeGroupDebts(
        shares: [
          (payerId: 2, memberId: 2, amount: r(150)),
          (payerId: 2, memberId: 3, amount: r(150)),
          (payerId: 3, memberId: 3, amount: r(50)),
          (payerId: 3, memberId: 2, amount: r(50)),
        ],
        myBalances: const {},
      );
      expect(debts, [(from: 3, to: 2, amount: r(100))]);
    });

    test('pairs with me come from myBalances, not from shares', () {
      final debts = computeGroupDebts(
        shares: [
          // Ignored — my pairs come from the balances (repayments applied).
          (payerId: null, memberId: 2, amount: r(500)),
          (payerId: 3, memberId: null, amount: r(200)),
        ],
        myBalances: {2: r(300), 3: -r(200), 4: const Money.zero()},
      );
      expect(debts, [
        (from: 2, to: null, amount: r(300)),
        (from: null, to: 3, amount: r(200)),
      ]);
    });
  });

  group('simplifyGroupDebts', () {
    test('clears a chain in one payment', () {
      // 1 owes 2 ₹100, 2 owes 3 ₹100 → 1 pays 3 directly.
      final net = groupNetBalances([
        (from: 1, to: 2, amount: r(100)),
        (from: 2, to: 3, amount: r(100)),
      ]);
      expect(net[2], const Money.zero());
      expect(simplifyGroupDebts(net), [(from: 1, to: 3, amount: r(100))]);
    });

    test('every net balance is cleared exactly', () {
      final debts = <GroupDebt>[
        (from: 1, to: null, amount: r(250)),
        (from: 2, to: null, amount: r(120)),
        (from: null, to: 3, amount: r(90)),
        (from: 2, to: 3, amount: r(40)),
        (from: 3, to: 1, amount: r(15)),
      ];
      final net = groupNetBalances(debts);
      expect(net.values.fold(0, (a, b) => a + b.paise), 0);

      final plan = simplifyGroupDebts(net);
      expect(plan.length, lessThan(net.length));
      final after = groupNetBalances(plan);
      for (final id in net.keys) {
        expect(after[id] ?? const Money.zero(), net[id], reason: 'id $id');
      }
    });

    test('everyone settled → no payments', () {
      expect(simplifyGroupDebts({null: const Money.zero()}), isEmpty);
    });
  });

  group('queries', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('shares and transaction → group map cover a group expense', () async {
      final cash = (await db.watchAccounts().first)
          .firstWhere((a) => a.type == AccountType.cash)
          .id;
      final food = (await db.watchCategories(
        CategoryKind.expense,
      ).first).firstWhere((c) => c.name == 'Food').id;
      final ram = await db.addPerson('Ram');
      final shyam = await db.addPerson('Shyam');
      final groupId = await db.addGroup('Trip');
      await db.setGroupMembers(groupId, {ram, shyam});

      // Ram paid; Shyam's share is a third-party debt with no ledger row.
      await db.addGroupExpense(
        groupId: groupId,
        amount: r(300),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 5),
        payerId: ram,
        participantIds: {null, ram, shyam},
      );
      // I paid; my own share is a real expense transaction.
      await db.addGroupExpense(
        groupId: groupId,
        amount: r(90),
        splitMethod: GroupSplitMethod.equal,
        date: DateTime(2026, 7, 6),
        accountId: cash,
        categoryId: food,
        participantIds: {null, ram, shyam},
      );

      final shares = await db.watchGroupExpenseShares(groupId).first;
      expect(shares, hasLength(6));

      final txGroups = await db.watchTransactionGroupIds().first;
      final myExpense = shares.firstWhere(
        (s) => s.personId == null && s.transactionId != null,
      );
      expect(txGroups[myExpense.transactionId], groupId);

      final expenses = await db.watchGroupExpenses(groupId).first;
      final payerOf = {for (final e in expenses) e.id: e.payerId};
      final debts = computeGroupDebts(
        shares: [
          for (final s in shares)
            (
              payerId: payerOf[s.groupExpenseId],
              memberId: s.personId,
              amount: s.amount,
            ),
        ],
        myBalances: const {},
      );
      expect(debts, [(from: shyam, to: ram, amount: r(100))]);
    });
  });
}
