import 'dart:math' as math;

import '../../core/money.dart';
import '../../data/tables.dart';

/// XPENC Score — a 0–100 read on how well money is being managed, built only
/// from what's already in the ledger. Pure: [computeXpencScore] takes a plain
/// [XpencScoreInput] snapshot so every rule is unit-testable without a
/// database (the provider that assembles the snapshot lives in
/// `xpenc_score_provider.dart`).
///
/// Seven rules ("pillars"), each worth a fixed number of points that add up
/// to 100. A pillar with nothing to judge — no budgets set, no loans taken —
/// is marked not-applicable and dropped, and the rest are scaled back up to
/// 100. Nobody is punished (or rewarded) for a feature they don't use.
///
/// Not a credit score: it never leaves the device and nothing but this app
/// ever reads it.

/// How far back the income/expense rules look. Three months smooths out a
/// one-off big purchase or a late salary without going stale.
const kScoreWindowDays = 90;

/// Fewer income/expense entries than this in the window and the score isn't
/// shown at all — a number built on three transactions would be noise.
const kScoreMinTransactions = 5;

enum ScorePillarId {
  savingsRate,
  livingWithinMeans,
  debtLoad,
  repayment,
  emergencyFund,
  budgets,
  trackingHabit,
}

/// Rule metadata — the fixed part of each pillar, shown on the "How it's
/// calculated" section so the user can see exactly what earns points.
typedef ScorePillarSpec = ({
  ScorePillarId id,
  String title,
  int weight,
  String rule,
});

const kScorePillars = <ScorePillarSpec>[
  (
    id: ScorePillarId.savingsRate,
    title: 'Savings rate',
    weight: 25,
    rule:
        'Share of income left after expenses over the last 90 days. '
        '30% or more earns full points; 0% or less earns none.',
  ),
  (
    id: ScorePillarId.livingWithinMeans,
    title: 'Living within means',
    weight: 10,
    rule:
        'Of the last 3 full months, how many ended with expenses at or '
        'below income.',
  ),
  (
    id: ScorePillarId.debtLoad,
    title: 'Debt load',
    weight: 20,
    rule:
        'Monthly debt obligations as a share of monthly income — loan EMIs, '
        'credit card and pay-later dues, plus a third of what you owe people. '
        '20% or less earns full points; 60% or more earns none.',
  ),
  (
    id: ScorePillarId.repayment,
    title: 'Repayment discipline',
    weight: 15,
    rule:
        'A payment into every active loan in each of the last 3 full months, '
        'and no overdue amounts owed to people.',
  ),
  (
    id: ScorePillarId.emergencyFund,
    title: 'Emergency fund',
    weight: 15,
    rule:
        'Cash, bank, prepaid and savings-goal balances measured in months of '
        'average expenses. 6 months or more earns full points.',
  ),
  (
    id: ScorePillarId.budgets,
    title: 'Budget discipline',
    weight: 10,
    rule: 'Share of your budgets still within their limit this period.',
  ),
  (
    id: ScorePillarId.trackingHabit,
    title: 'Tracking habit',
    weight: 5,
    rule:
        'Days with at least one entry in the last 30. 12 or more earns full '
        'points — the score is only as accurate as the ledger behind it.',
  ),
];

ScorePillarSpec scorePillarSpec(ScorePillarId id) =>
    kScorePillars.firstWhere((p) => p.id == id);

/// One ledger movement, stripped to what the score reads. [amount] is
/// already in the base currency.
typedef ScoreTx = ({
  DateTime date,
  TxType type,
  Money amount,
  int accountId,
  int? toAccountId,
});

/// A loan that still has something outstanding.
typedef ScoreLoan = ({
  int accountId,
  String name,
  Money outstanding,
  // The EMI the user entered (or the amortization derived). Null for a
  // "basic" loan — the average actual monthly payment stands in for it.
  Money? emi,
  // When repayment began: months before this are never expected to carry
  // a payment.
  DateTime start,
});

class XpencScoreInput {
  const XpencScoreInput({
    required this.now,
    required this.txs,
    required this.liquid,
    required this.cardAndPayLaterDue,
    required this.owedToPeople,
    required this.loans,
    required this.peopleYouOwe,
    required this.peopleYouOweOverdue,
    required this.budgetCount,
    required this.budgetsOverspent,
  });

  final DateTime now;
  final List<ScoreTx> txs;

  /// Money you could reach in an emergency: positive cash, bank, prepaid and
  /// goal balances, in the base currency.
  final Money liquid;

  /// Outstanding on credit cards and pay-later accounts — due within a cycle.
  final Money cardAndPayLaterDue;

  /// What you owe people, summed over only the people you owe.
  final Money owedToPeople;

  final List<ScoreLoan> loans;

  /// How many people you currently owe, and how many of those have an
  /// "I owe" entry whose due date has already passed.
  final int peopleYouOwe;
  final int peopleYouOweOverdue;

  final int budgetCount;
  final int budgetsOverspent;
}

class ScorePillar {
  const ScorePillar({
    required this.id,
    required this.applicable,
    required this.fraction,
    required this.detail,
    this.tip,
  });

  /// Not applicable — nothing to judge. Excluded from the total.
  const ScorePillar.skipped(this.id, this.detail)
    : applicable = false,
      fraction = 0,
      tip = null;

  final ScorePillarId id;
  final bool applicable;

  /// 0–1 share of this pillar's [weight] earned.
  final double fraction;

  /// What was measured, in plain words ("Saved 24% of income").
  final String detail;

  /// The single most useful thing to do about it — null when the pillar is
  /// already at (or near) full marks.
  final String? tip;

  ScorePillarSpec get spec => scorePillarSpec(id);
  String get title => spec.title;
  int get weight => spec.weight;
  double get points => applicable ? fraction * weight : 0;
}

enum ScoreGrade { excellent, good, fair, needsWork, atRisk }

extension ScoreGradeX on ScoreGrade {
  String get label => switch (this) {
    ScoreGrade.excellent => 'Excellent',
    ScoreGrade.good => 'Good',
    ScoreGrade.fair => 'Fair',
    ScoreGrade.needsWork => 'Needs work',
    ScoreGrade.atRisk => 'At risk',
  };

  String get blurb => switch (this) {
    ScoreGrade.excellent =>
      'Your money is in great shape. Keep the habits that got you here.',
    ScoreGrade.good =>
      'Solid footing. A couple of small changes would push you to the top.',
    ScoreGrade.fair =>
      'Getting there. Focus on the lowest-scoring rule below first.',
    ScoreGrade.needsWork =>
      'Some habits are costing you. The tips below show where to start.',
    ScoreGrade.atRisk =>
      'Spending or debt is outpacing income. Start with the first tip below.',
  };
}

ScoreGrade gradeFor(int score) {
  if (score >= 80) return ScoreGrade.excellent;
  if (score >= 65) return ScoreGrade.good;
  if (score >= 50) return ScoreGrade.fair;
  if (score >= 35) return ScoreGrade.needsWork;
  return ScoreGrade.atRisk;
}

class XpencScore {
  const XpencScore({
    required this.score,
    required this.pillars,
    required this.windowIncome,
    required this.windowExpense,
    required this.entriesInWindow,
  });

  /// 0–100, or null when there isn't enough data to be meaningful — see
  /// [kScoreMinTransactions].
  final int? score;
  final List<ScorePillar> pillars;
  final Money windowIncome;
  final Money windowExpense;
  final int entriesInWindow;

  bool get hasScore => score != null;
  ScoreGrade? get grade => score == null ? null : gradeFor(score!);

  /// Applicable pillars, most points lost first — what to fix next.
  List<ScorePillar> get improvements {
    final out = [
      for (final p in pillars)
        if (p.applicable && p.tip != null) p,
    ]..sort((a, b) => (b.weight - b.points).compareTo(a.weight - a.points));
    return out;
  }
}

double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);

String _pct(double v) => '${(v * 100).round()}%';

/// Linear ramp: [full] or better earns 1, [zero] or worse earns 0. Works in
/// both directions (higher-is-better or lower-is-better).
double _ramp(double value, {required double zero, required double full}) =>
    _clamp01((value - zero) / (full - zero));

/// The first instant of the month [offset] months from [now]'s month.
DateTime _monthStart(DateTime now, int offset) =>
    DateTime(now.year, now.month + offset);

XpencScore computeXpencScore(XpencScoreInput input) {
  final now = input.now;
  final windowStart = now.subtract(const Duration(days: kScoreWindowDays));

  var income = const Money.zero();
  var expense = const Money.zero();
  var entries = 0;
  for (final t in input.txs) {
    if (t.date.isBefore(windowStart) || t.date.isAfter(now)) continue;
    if (t.type == TxType.income) {
      income += t.amount;
      entries++;
    } else if (t.type == TxType.expense) {
      expense += t.amount;
      entries++;
    }
  }
  final months = kScoreWindowDays / 30;
  final avgIncome = income.paise / months;
  final avgExpense = expense.paise / months;

  final pillars = <ScorePillar>[
    _savingsRate(income, expense),
    _livingWithinMeans(input),
    _debtLoad(input, avgIncome),
    _repayment(input),
    _emergencyFund(input, avgExpense),
    _budgets(input),
    _trackingHabit(input),
  ];

  int? score;
  if (entries >= kScoreMinTransactions) {
    final possible = pillars
        .where((p) => p.applicable)
        .fold(0, (sum, p) => sum + p.weight);
    final earned = pillars.fold(0.0, (sum, p) => sum + p.points);
    if (possible > 0) score = (earned / possible * 100).round().clamp(0, 100);
  }

  return XpencScore(
    score: score,
    pillars: pillars,
    windowIncome: income,
    windowExpense: expense,
    entriesInWindow: entries,
  );
}

ScorePillar _savingsRate(Money income, Money expense) {
  const id = ScorePillarId.savingsRate;
  if (income.isZero && expense.isZero) {
    return const ScorePillar.skipped(id, 'No income or expenses yet');
  }
  if (!income.isPositive) {
    return ScorePillar(
      id: id,
      applicable: true,
      fraction: 0,
      detail: 'Expenses with no recorded income',
      tip:
          'Record your income too — salary, freelance, interest — so the '
          'score can see what you earn.',
    );
  }
  final rate = (income.paise - expense.paise) / income.paise;
  final fraction = _ramp(rate, zero: 0, full: 0.30);
  return ScorePillar(
    id: id,
    applicable: true,
    fraction: fraction,
    detail: rate >= 0
        ? 'Saved ${_pct(rate)} of income'
        : 'Spent ${_pct(-rate)} more than you earned',
    tip: fraction >= 1
        ? null
        : rate < 0
        ? 'Expenses are above income. Cut your top spending category first.'
        : 'Aim to keep at least 30% of income. Your top expense categories '
              'are the fastest place to find it.',
  );
}

ScorePillar _livingWithinMeans(XpencScoreInput input) {
  const id = ScorePillarId.livingWithinMeans;
  var active = 0;
  var within = 0;
  for (var i = 1; i <= 3; i++) {
    final start = _monthStart(input.now, -i);
    final end = _monthStart(input.now, -i + 1);
    var inc = 0;
    var exp = 0;
    var any = false;
    for (final t in input.txs) {
      if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
      if (t.type == TxType.income) {
        inc += t.amount.paise;
        any = true;
      } else if (t.type == TxType.expense) {
        exp += t.amount.paise;
        any = true;
      }
    }
    if (!any) continue;
    active++;
    if (exp <= inc) within++;
  }
  if (active == 0) {
    return const ScorePillar.skipped(id, 'Needs one full month of entries');
  }
  final fraction = within / active;
  return ScorePillar(
    id: id,
    applicable: true,
    fraction: fraction,
    detail:
        '$within of $active full month${active == 1 ? '' : 's'} '
        'within income',
    tip: fraction >= 1
        ? null
        : 'Some months ended in the red. A monthly budget on your biggest '
              'categories keeps spending under income.',
  );
}

ScorePillar _debtLoad(XpencScoreInput input, double avgIncome) {
  const id = ScorePillarId.debtLoad;
  final obligations = monthlyDebtObligations(input);
  if (obligations.isZero || obligations.isNegative) {
    return const ScorePillar(
      id: id,
      applicable: true,
      fraction: 1,
      detail: 'No debt obligations',
    );
  }
  if (avgIncome <= 0) {
    return const ScorePillar(
      id: id,
      applicable: true,
      fraction: 0,
      detail: 'Debt with no recorded income',
      tip:
          'Record your income so debt can be weighed against it — and '
          'prioritise clearing the most expensive debt first.',
    );
  }
  final ratio = obligations.paise / avgIncome;
  final fraction = _ramp(ratio, zero: 0.60, full: 0.20);
  return ScorePillar(
    id: id,
    applicable: true,
    fraction: fraction,
    detail: 'Debt takes ${_pct(ratio)} of monthly income',
    tip: fraction >= 1
        ? null
        : 'Keep monthly debt payments under 20% of income. Clear credit card '
              'and pay-later dues in full first — they cost the most.',
  );
}

/// What debt asks of each month: loan EMIs (or the average actual payment
/// for a loan with no EMI set), card and pay-later dues in full, and a third
/// of informal IOUs (assumed cleared within about three months).
Money monthlyDebtObligations(XpencScoreInput input) {
  var total = input.cardAndPayLaterDue.paise + input.owedToPeople.paise ~/ 3;
  for (final loan in input.loans) {
    if (!loan.outstanding.isPositive) continue;
    final emi = loan.emi ?? _averageMonthlyPayment(input, loan.accountId);
    // An EMI larger than what's left is just what's left.
    total += math.min(emi.paise, loan.outstanding.paise);
  }
  return Money(total);
}

Money _averageMonthlyPayment(XpencScoreInput input, int loanId) {
  final start = _monthStart(input.now, -3);
  final end = _monthStart(input.now, 0);
  var paid = 0;
  for (final t in input.txs) {
    if (t.type != TxType.transfer || t.toAccountId != loanId) continue;
    if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
    paid += t.amount.paise;
  }
  return Money(paid ~/ 3);
}

ScorePillar _repayment(XpencScoreInput input) {
  const id = ScorePillarId.repayment;
  final ratios = <double>[];
  final parts = <String>[];
  String? tip;

  var expected = 0;
  var paid = 0;
  final missedLoans = <String>{};
  for (final loan in input.loans) {
    if (!loan.outstanding.isPositive) continue;
    for (var i = 1; i <= 3; i++) {
      final start = _monthStart(input.now, -i);
      final end = _monthStart(input.now, -i + 1);
      // A month that closed before repayment began owes nothing.
      if (!end.isAfter(loan.start)) continue;
      expected++;
      final hit = input.txs.any(
        (t) =>
            t.type == TxType.transfer &&
            t.toAccountId == loan.accountId &&
            !t.date.isBefore(start) &&
            t.date.isBefore(end),
      );
      if (hit) {
        paid++;
      } else {
        missedLoans.add(loan.name);
      }
    }
  }
  if (expected > 0) {
    ratios.add(paid / expected);
    parts.add('$paid of $expected loan payments made');
    if (missedLoans.isNotEmpty) {
      tip =
          'Missed a month on ${missedLoans.join(', ')}. Set up a recurring '
          'transfer so every EMI posts on time.';
    }
  }

  if (input.peopleYouOwe > 0) {
    final overdue = input.peopleYouOweOverdue;
    ratios.add(1 - overdue / input.peopleYouOwe);
    parts.add(
      overdue == 0
          ? 'No overdue dues to people'
          : '$overdue overdue due${overdue == 1 ? '' : 's'} to people',
    );
    if (overdue > 0) {
      tip ??=
          'Settle what you owe people past its due date — or agree a new '
          'date and update it.';
    }
  }

  if (ratios.isEmpty) {
    return const ScorePillar.skipped(id, 'No loans or dues to repay');
  }
  final fraction = ratios.reduce((a, b) => a + b) / ratios.length;
  return ScorePillar(
    id: id,
    applicable: true,
    fraction: _clamp01(fraction),
    detail: parts.join(' · '),
    tip: fraction >= 1 ? null : tip,
  );
}

ScorePillar _emergencyFund(XpencScoreInput input, double avgExpense) {
  const id = ScorePillarId.emergencyFund;
  if (avgExpense <= 0) {
    return const ScorePillar.skipped(id, 'Needs a few expenses to measure');
  }
  final months = math.max(0, input.liquid.paise) / avgExpense;
  final fraction = _ramp(months, zero: 0, full: 6);
  return ScorePillar(
    id: id,
    applicable: true,
    fraction: fraction,
    detail: 'Covers ${months.toStringAsFixed(1)} months of expenses',
    tip: fraction >= 1
        ? null
        : 'Build a cushion of 6 months of expenses. A savings goal with a '
              'small monthly transfer is the easiest way to start.',
  );
}

ScorePillar _budgets(XpencScoreInput input) {
  const id = ScorePillarId.budgets;
  if (input.budgetCount == 0) {
    return const ScorePillar.skipped(id, 'No budgets set');
  }
  final ok = input.budgetCount - input.budgetsOverspent;
  final fraction = ok / input.budgetCount;
  return ScorePillar(
    id: id,
    applicable: true,
    fraction: _clamp01(fraction),
    detail: '$ok of ${input.budgetCount} budgets on track',
    tip: fraction >= 1
        ? null
        : '${input.budgetsOverspent} budget'
              '${input.budgetsOverspent == 1 ? ' is' : 's are'} overspent. '
              'Slow down there for the rest of the period, or resize the '
              'budget if it was unrealistic.',
  );
}

ScorePillar _trackingHabit(XpencScoreInput input) {
  const id = ScorePillarId.trackingHabit;
  final since = input.now.subtract(const Duration(days: 30));
  final days = <int>{};
  for (final t in input.txs) {
    if (t.date.isBefore(since) || t.date.isAfter(input.now)) continue;
    days.add(
      DateTime(t.date.year, t.date.month, t.date.day).millisecondsSinceEpoch,
    );
  }
  final fraction = _ramp(days.length.toDouble(), zero: 0, full: 12);
  return ScorePillar(
    id: id,
    applicable: true,
    fraction: fraction,
    detail: 'Entries on ${days.length} of the last 30 days',
    tip: fraction >= 1
        ? null
        : 'Log spending as it happens. A daily reminder '
              '(Settings › Notifications) helps.',
  );
}
