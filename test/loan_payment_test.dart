import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/database.dart';
import 'package:xpenc/data/tables.dart';

/// A home-loan EMI is mostly interest early on — the interest portion should
/// count as a real expense, never reduce the loan's outstanding balance.
/// `AppDatabase.addLoanPayment` splits one payment across an expense leg
/// (interest) and a transfer leg (principal), linked via `paymentGroupId`
/// the same way `addExpenseWithChange`'s legs are.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> cashId() async => (await db.watchAccounts().first)
      .firstWhere((a) => a.type == AccountType.cash)
      .id;

  Future<int> loanId({Money? principal}) => db.addLoan(
    name: 'Home Loan',
    principal: principal ?? Money.fromRupees(2000000),
    colorValue: 0xFF2563EB,
    iconKey: 'loan',
  );

  Future<int> interestCategory() async =>
      (await db.watchCategories(CategoryKind.expense).first)
          .firstWhere((c) => c.name == 'Bills')
          .id;

  Future<Money> balanceOf(int id) async => (await db.watchAccounts().first)
      .firstWhere((a) => a.id == id)
      .currentBalance;

  Future<List<TransactionRow>> allOfType(TxType type) =>
      (db.select(db.transactions)..where((t) => t.type.equalsValue(type)))
          .get();

  test(
    'splits an EMI into an interest expense and a principal transfer',
    () async {
      final cash = await cashId();
      final loan = await loanId();
      final interest = await interestCategory();
      final cashBefore = await balanceOf(cash);
      final loanBefore = await balanceOf(loan);

      final ids = await db.addLoanPayment(
        sourceAccountId: cash,
        loanAccountId: loan,
        amount: Money.fromRupees(20000),
        interestAmount: Money.fromRupees(15000),
        interestCategoryId: interest,
        date: DateTime(2026, 9, 5),
        note: 'September EMI',
      );

      expect(ids, hasLength(2));
      expect(await balanceOf(cash), cashBefore - Money.fromRupees(20000));
      // Only the principal (5000) should reduce what's owed.
      expect(await balanceOf(loan), loanBefore + Money.fromRupees(5000));

      final rows = await db.paymentGroupLegs(ids.first);
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.paymentGroupId == ids.first), isTrue);

      final interestLeg = rows.firstWhere((r) => r.id == ids.first);
      expect(interestLeg.type, TxType.expense);
      expect(interestLeg.amount, Money.fromRupees(15000));
      expect(interestLeg.categoryId, interest);
      expect(interestLeg.note, 'September EMI');

      final principalLeg = rows.firstWhere((r) => r.id == ids.last);
      expect(principalLeg.type, TxType.transfer);
      expect(principalLeg.amount, Money.fromRupees(5000));
      expect(principalLeg.accountId, cash);
      expect(principalLeg.toAccountId, loan);

      // The interest leg alone counts toward expense reports.
      final expenses = await allOfType(TxType.expense);
      expect(expenses, hasLength(1));
      expect(expenses.single.amount, Money.fromRupees(15000));
    },
  );

  test(
    'no interest amount behaves exactly like a plain payment (one leg)',
    () async {
      final cash = await cashId();
      final loan = await loanId();
      final loanBefore = await balanceOf(loan);

      final ids = await db.addLoanPayment(
        sourceAccountId: cash,
        loanAccountId: loan,
        amount: Money.fromRupees(8000),
        date: DateTime(2026, 9, 5),
      );

      expect(ids, hasLength(1));
      expect(await balanceOf(loan), loanBefore + Money.fromRupees(8000));

      final leg = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals(ids.single))).getSingle();
      expect(leg.type, TxType.transfer);
      expect(leg.paymentGroupId, isNull);
      expect(await allOfType(TxType.expense), isEmpty);
    },
  );

  test('an advance payment that is pure principal, no interest', () async {
    final cash = await cashId();
    final loan = await loanId();
    final loanBefore = await balanceOf(loan);

    final ids = await db.addLoanPayment(
      sourceAccountId: cash,
      loanAccountId: loan,
      amount: Money.fromRupees(50000),
      date: DateTime(2026, 9, 12),
      note: 'Advance payment',
    );

    expect(ids, hasLength(1));
    expect(await balanceOf(loan), loanBefore + Money.fromRupees(50000));
    expect(await allOfType(TxType.expense), isEmpty);
  });

  test('interest equal to the full amount posts no transfer leg', () async {
    final cash = await cashId();
    final loan = await loanId();
    final interest = await interestCategory();
    final loanBefore = await balanceOf(loan);

    final ids = await db.addLoanPayment(
      sourceAccountId: cash,
      loanAccountId: loan,
      amount: Money.fromRupees(3000),
      interestAmount: Money.fromRupees(3000),
      interestCategoryId: interest,
      date: DateTime(2026, 9, 5),
    );

    expect(ids, hasLength(1));
    expect(await balanceOf(loan), loanBefore);
    final leg = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(ids.single))).getSingle();
    expect(leg.type, TxType.expense);
    expect(leg.paymentGroupId, isNull);
  });

  test('rejects interest greater than the total payment', () async {
    final cash = await cashId();
    final loan = await loanId();
    final interest = await interestCategory();

    expect(
      () => db.addLoanPayment(
        sourceAccountId: cash,
        loanAccountId: loan,
        amount: Money.fromRupees(5000),
        interestAmount: Money.fromRupees(6000),
        interestCategoryId: interest,
        date: DateTime(2026, 9, 5),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a positive interest amount with no category', () async {
    final cash = await cashId();
    final loan = await loanId();

    expect(
      () => db.addLoanPayment(
        sourceAccountId: cash,
        loanAccountId: loan,
        amount: Money.fromRupees(5000),
        interestAmount: Money.fromRupees(1000),
        date: DateTime(2026, 9, 5),
      ),
      throwsArgumentError,
    );
  });

  test(
    'a bad transfer leg is rejected before either leg is written',
    () async {
      final cash = await cashId();
      final interest = await interestCategory();
      final cashBefore = await balanceOf(cash);

      // Source and destination the same account — an impossible transfer,
      // caught before any insert, so the interest leg never lands either.
      await expectLater(
        db.addLoanPayment(
          sourceAccountId: cash,
          loanAccountId: cash,
          amount: Money.fromRupees(5000),
          interestAmount: Money.fromRupees(3000),
          interestCategoryId: interest,
          date: DateTime(2026, 9, 5),
        ),
        throwsArgumentError,
      );

      expect(await balanceOf(cash), cashBefore);
      expect(await allOfType(TxType.expense), isEmpty);
    },
  );
}
