import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/data/tables.dart';
import 'package:xpenc/features/reports/xpenc_score.dart';

/// Pure rule tests for [computeXpencScore] — no database, fixed "now".
void main() {
  final now = DateTime(2026, 9, 25, 12);

  ScoreTx tx(
    TxType type,
    num rupees,
    DateTime date, {
    int accountId = 1,
    int? toAccountId,
  }) => (
    date: date,
    type: type,
    amount: Money.fromRupees(rupees),
    accountId: accountId,
    toAccountId: toAccountId,
  );

  /// Salary on the 1st and rent+groceries through each of the last
  /// [months] months, plus entries on most recent days.
  List<ScoreTx> steadyLedger({
    num salary = 100000,
    num spend = 50000,
    int months = 4,
  }) => [
    for (var m = 0; m < months; m++) ...[
      tx(TxType.income, salary, DateTime(now.year, now.month - m, 1)),
      tx(TxType.expense, spend / 2, DateTime(now.year, now.month - m, 2)),
      tx(TxType.expense, spend / 2, DateTime(now.year, now.month - m, 15)),
    ],
    for (var d = 0; d < 14; d++)
      tx(TxType.expense, 0.01, now.subtract(Duration(days: d))),
  ];

  XpencScoreInput input({
    List<ScoreTx>? txs,
    Money liquid = const Money.zero(),
    Money revolving = const Money.zero(),
    Money people = const Money.zero(),
    List<ScoreLoan> loans = const [],
    int peopleYouOwe = 0,
    int overdue = 0,
    int budgets = 0,
    int overspent = 0,
  }) => XpencScoreInput(
    now: now,
    txs: txs ?? steadyLedger(),
    liquid: liquid,
    cardAndPayLaterDue: revolving,
    owedToPeople: people,
    loans: loans,
    peopleYouOwe: peopleYouOwe,
    peopleYouOweOverdue: overdue,
    budgetCount: budgets,
    budgetsOverspent: overspent,
  );

  ScorePillar pillar(XpencScore s, ScorePillarId id) =>
      s.pillars.firstWhere((p) => p.id == id);

  test('pillar weights add up to 100', () {
    expect(kScorePillars.fold(0, (s, p) => s + p.weight), 100);
  });

  test('no score below the minimum number of entries', () {
    final s = computeXpencScore(
      input(txs: [tx(TxType.income, 1000, now), tx(TxType.expense, 10, now)]),
    );
    expect(s.score, isNull);
    expect(s.hasScore, isFalse);
  });

  test('transfers and person movements never count as income or expense', () {
    final s = computeXpencScore(
      input(
        txs: [
          ...steadyLedger(),
          tx(TxType.transfer, 999999, now, toAccountId: 2),
          tx(TxType.personOut, 999999, now),
          tx(TxType.personIn, 999999, now),
        ],
      ),
    );
    final plain = computeXpencScore(input());
    expect(s.windowIncome, plain.windowIncome);
    expect(s.windowExpense, plain.windowExpense);
  });

  test('savings rate: 30% or more earns full points, 0% none', () {
    final great = computeXpencScore(input(txs: steadyLedger(spend: 60000)));
    expect(pillar(great, ScorePillarId.savingsRate).fraction, closeTo(1, 0.01));

    final half = computeXpencScore(input(txs: steadyLedger(spend: 85000)));
    // ~15% saved -> ~half of the 30% target.
    expect(
      pillar(half, ScorePillarId.savingsRate).fraction,
      closeTo(0.5, 0.02),
    );

    final broke = computeXpencScore(input(txs: steadyLedger(spend: 120000)));
    expect(pillar(broke, ScorePillarId.savingsRate).fraction, 0);
    expect(pillar(broke, ScorePillarId.savingsRate).tip, isNotNull);
  });

  test('living within means counts full months only', () {
    final s = computeXpencScore(input(txs: steadyLedger(spend: 120000)));
    final p = pillar(s, ScorePillarId.livingWithinMeans);
    expect(p.fraction, 0);
    expect(p.detail, contains('0 of 3'));
  });

  test('not-applicable pillars are dropped, not scored as zero', () {
    final s = computeXpencScore(input(liquid: Money.fromRupees(1000000)));
    expect(pillar(s, ScorePillarId.budgets).applicable, isFalse);
    expect(pillar(s, ScorePillarId.repayment).applicable, isFalse);
    // Healthy ledger, no debt, big cushion, daily tracking: a perfect score
    // even though budgets and repayment have nothing to judge.
    expect(s.score, 100);
  });

  test('debt load: obligations under 20% of income are full marks', () {
    final loan = (
      accountId: 9,
      name: 'Home loan',
      outstanding: Money.fromRupees(2000000),
      emi: Money.fromRupees(15000),
      start: DateTime(2025),
    );
    final ok = computeXpencScore(input(loans: [loan]));
    expect(pillar(ok, ScorePillarId.debtLoad).fraction, 1);

    final heavy = computeXpencScore(
      input(
        loans: [
          (
            accountId: 9,
            name: 'Home loan',
            outstanding: Money.fromRupees(2000000),
            emi: Money.fromRupees(60000),
            start: DateTime(2025),
          ),
        ],
      ),
    );
    expect(pillar(heavy, ScorePillarId.debtLoad).fraction, 0);
  });

  test('debt load counts card dues in full and a third of IOUs', () {
    final s = input(
      revolving: Money.fromRupees(10000),
      people: Money.fromRupees(30000),
    );
    expect(monthlyDebtObligations(s), Money.fromRupees(20000));
  });

  test('repayment: a missed EMI month costs points and names the loan', () {
    final loan = (
      accountId: 9,
      name: 'Car loan',
      outstanding: Money.fromRupees(300000),
      emi: Money.fromRupees(10000),
      start: DateTime(2025),
    );
    final paidTwo = [
      ...steadyLedger(),
      for (final m in [1, 2])
        tx(
          TxType.transfer,
          10000,
          DateTime(now.year, now.month - m, 5),
          toAccountId: 9,
        ),
    ];
    final s = computeXpencScore(input(txs: paidTwo, loans: [loan]));
    final p = pillar(s, ScorePillarId.repayment);
    expect(p.fraction, closeTo(2 / 3, 0.001));
    expect(p.tip, contains('Car loan'));
  });

  test('repayment: months before the loan started are not expected', () {
    final loan = (
      accountId: 9,
      name: 'New loan',
      outstanding: Money.fromRupees(100000),
      emi: Money.fromRupees(5000),
      start: DateTime(now.year, now.month - 1, 10),
    );
    final s = computeXpencScore(
      input(
        txs: [
          ...steadyLedger(),
          tx(
            TxType.transfer,
            5000,
            DateTime(now.year, now.month - 1, 20),
            toAccountId: 9,
          ),
        ],
        loans: [loan],
      ),
    );
    expect(pillar(s, ScorePillarId.repayment).fraction, 1);
  });

  test('repayment: overdue dues to people are penalised', () {
    final s = computeXpencScore(input(peopleYouOwe: 4, overdue: 1));
    expect(pillar(s, ScorePillarId.repayment).fraction, 0.75);
  });

  test('emergency fund ramps to full at 6 months of expenses', () {
    // Spend 50k a month -> 150k over 3 months -> 6 months is 300k.
    final full = computeXpencScore(input(liquid: Money.fromRupees(300000)));
    expect(
      pillar(full, ScorePillarId.emergencyFund).fraction,
      closeTo(1, 0.01),
    );
    final half = computeXpencScore(input(liquid: Money.fromRupees(150000)));
    expect(
      pillar(half, ScorePillarId.emergencyFund).fraction,
      closeTo(0.5, 0.02),
    );
  });

  test('budget discipline is the share of budgets within limit', () {
    final s = computeXpencScore(input(budgets: 5, overspent: 2));
    expect(pillar(s, ScorePillarId.budgets).fraction, 0.6);
  });

  test('tracking habit needs 12 active days in the last 30 for full marks', () {
    final sparse = computeXpencScore(
      input(
        txs: [
          for (var i = 0; i < 6; i++)
            tx(TxType.expense, 10, now.subtract(Duration(days: i * 5))),
        ],
      ),
    );
    expect(pillar(sparse, ScorePillarId.trackingHabit).fraction, 0.5);
  });

  test('grades follow the published cut-offs', () {
    expect(gradeFor(100), ScoreGrade.excellent);
    expect(gradeFor(80), ScoreGrade.excellent);
    expect(gradeFor(79), ScoreGrade.good);
    expect(gradeFor(65), ScoreGrade.good);
    expect(gradeFor(50), ScoreGrade.fair);
    expect(gradeFor(35), ScoreGrade.needsWork);
    expect(gradeFor(34), ScoreGrade.atRisk);
    expect(gradeFor(0), ScoreGrade.atRisk);
  });

  test('improvements are ordered by points lost', () {
    final s = computeXpencScore(
      input(txs: steadyLedger(spend: 120000), budgets: 2, overspent: 1),
    );
    final lost = [for (final p in s.improvements) p.weight - p.points];
    for (var i = 1; i < lost.length; i++) {
      expect(lost[i - 1], greaterThanOrEqualTo(lost[i]));
    }
    expect(s.improvements.first.id, ScorePillarId.savingsRate);
  });
}
