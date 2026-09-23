import 'money.dart';

/// Reducing-balance (diminishing) EMI amortization math for the loan
/// module — the same method virtually every Indian bank loan
/// (home/personal/car/gold) actually uses: interest each period is charged
/// only on whatever principal is still outstanding, not on the original
/// amount for the whole tenure (that would be a flat-rate loan, not
/// supported here).
///
/// Every method takes [annualRatePct] as a plain percentage (`8.5` for
/// 8.5%/year) — the only place a `double` is allowed near money in this
/// codebase, and only as a rate input. All money math stays in integer
/// paise, rounding at each step, per [Money]'s "never use double for money"
/// rule.
class LoanAmortization {
  const LoanAmortization._();

  /// A safety valve against a misconfigured EMI that doesn't even cover a
  /// period's interest — [amortizeToZero] would otherwise loop forever as
  /// the balance grows instead of shrinking.
  static const _maxInstallments = 1200;

  static double _monthlyRate(double annualRatePct) => annualRatePct / 1200;

  /// One period's interest on [outstandingPrincipal] at [annualRatePct] —
  /// `Money.zero()` when there's no rate or nothing left owing. Rounded to
  /// the nearest paisa.
  ///
  /// This is the single formula reused everywhere a payment needs to know
  /// "how much of this is interest right now": the manual payment sheet's
  /// auto-fill and the recurring-rule auto-split both call this rather than
  /// each carrying their own copy of the math.
  static Money periodInterest({
    required Money outstandingPrincipal,
    required double? annualRatePct,
  }) {
    if (annualRatePct == null || !outstandingPrincipal.isPositive) {
      return const Money.zero();
    }
    final r = _monthlyRate(annualRatePct);
    return Money.fromPaise((outstandingPrincipal.paise * r).round());
  }

  /// The standard EMI formula: `P × r × (1+r)^n / ((1+r)^n − 1)`, `r` being
  /// the monthly rate. A `0` rate degrades to a plain equal split of
  /// [principal] over [tenureMonths].
  static Money calculateEmi({
    required Money principal,
    required double annualRatePct,
    required int tenureMonths,
  }) {
    if (tenureMonths <= 0 || !principal.isPositive) return const Money.zero();
    final r = _monthlyRate(annualRatePct);
    if (r == 0) {
      return Money.fromPaise((principal.paise / tenureMonths).round());
    }
    final factor = _pow(1 + r, tenureMonths);
    final emi = principal.paise * r * factor / (factor - 1);
    return Money.fromPaise(emi.round());
  }

  /// Simulates a fixed [emi] from [startingBalance] for up to [months]
  /// periods, stopping early once the balance hits zero (or once [emi]
  /// stops covering even the period's interest — the balance would only
  /// grow from there, never amortize). Returns how many periods it actually
  /// ran, the interest accrued over exactly those periods, and the balance
  /// left afterward.
  ///
  /// The building block behind [amortizeToZero] (run to completion) and the
  /// loan detail screen's prepayment-savings comparison (run for exactly
  /// how many periods have elapsed since the loan started, to find where
  /// the *original* schedule would be today).
  static ({int monthsElapsed, Money interestSoFar, Money balanceAfter})
  amortizeFor({
    required Money startingBalance,
    required double annualRatePct,
    required Money emi,
    required int months,
  }) {
    var balance = startingBalance;
    var interestSoFar = const Money.zero();
    var n = 0;
    while (balance.isPositive && n < months) {
      final interest = periodInterest(
        outstandingPrincipal: balance,
        annualRatePct: annualRatePct,
      );
      var principalPortion = Money.fromPaise(emi.paise - interest.paise);
      if (!principalPortion.isPositive) break;
      if (principalPortion.paise > balance.paise) principalPortion = balance;
      balance -= principalPortion;
      interestSoFar += interest;
      n++;
    }
    return (
      monthsElapsed: n,
      interestSoFar: interestSoFar,
      balanceAfter: balance,
    );
  }

  /// Runs [amortizeFor] to completion (or [_maxInstallments], whichever
  /// comes first) — how many installments it takes to pay [startingBalance]
  /// off entirely at a fixed [emi], and the total interest across all of
  /// them. `(0, Money.zero())` when there's nothing owing, or when [emi]
  /// doesn't even cover the first period's interest.
  ///
  /// Used both from a loan's original principal (→ total interest payable
  /// over the full original tenure) and from its current outstanding
  /// balance (→ what's left to pay at today's pace, for the
  /// prepayment-savings comparison).
  static ({int months, Money totalInterest}) amortizeToZero({
    required Money startingBalance,
    required double annualRatePct,
    required Money emi,
  }) {
    final result = amortizeFor(
      startingBalance: startingBalance,
      annualRatePct: annualRatePct,
      emi: emi,
      months: _maxInstallments,
    );
    return (months: result.monthsElapsed, totalInterest: result.interestSoFar);
  }

  static double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
