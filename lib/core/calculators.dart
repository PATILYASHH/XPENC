import 'dart:math' as math;

import 'money.dart';

/// Pure math behind the More → Calculators screens (FD, RD, SIP, lumpsum,
/// PPF, GST, Indian income tax). No widgets, no providers — every screen
/// reads its numbers from here so the tests pin the formulas, not the UI.
///
/// Rates come in as plain percentages (`7.1` for 7.1%/year), the same
/// convention as [LoanAmortization]. Money goes in and out as [Money];
/// `double` only appears for the rate/compounding step, rounded back to
/// the nearest paisa on the way out.

/// How often an FD credits interest into its own balance.
enum Compounding {
  monthly(12, 'Monthly'),
  quarterly(4, 'Quarterly'),
  halfYearly(2, 'Half-yearly'),
  yearly(1, 'Yearly');

  const Compounding(this.perYear, this.label);
  final int perYear;
  final String label;
}

/// What you put in, what it grew to, and the difference.
class GrowthResult {
  const GrowthResult({required this.invested, required this.maturity});

  final Money invested;
  final Money maturity;

  Money get returns => maturity - invested;
}

class DepositCalculator {
  const DepositCalculator._();

  /// Fixed deposit: `P × (1 + r/n)^(n·t)`, with [months] as the tenure so a
  /// 1 year 6 month FD doesn't have to be typed as 1.5 years.
  static GrowthResult fixedDeposit({
    required Money principal,
    required double annualRatePct,
    required int months,
    Compounding compounding = Compounding.quarterly,
  }) {
    if (!principal.isPositive || months <= 0) {
      return GrowthResult(invested: principal, maturity: principal);
    }
    final n = compounding.perYear;
    final factor = math.pow(1 + annualRatePct / 100 / n, n * months / 12);
    return GrowthResult(
      invested: principal,
      maturity: Money.fromPaise((principal.paise * factor).round()),
    );
  }

  /// Recurring deposit, compounded quarterly — the method Indian banks and
  /// the post office use. Each monthly [installment] earns interest for the
  /// months it actually stays in: the first for all [months], the last for
  /// one.
  static GrowthResult recurringDeposit({
    required Money installment,
    required double annualRatePct,
    required int months,
  }) {
    if (!installment.isPositive || months <= 0) {
      return const GrowthResult(invested: Money.zero(), maturity: Money.zero());
    }
    final q = annualRatePct / 100 / 4;
    var maturity = 0.0;
    for (var k = 1; k <= months; k++) {
      maturity += installment.paise * math.pow(1 + q, k / 3);
    }
    return GrowthResult(
      invested: installment * months,
      maturity: Money.fromPaise(maturity.round()),
    );
  }
}

class InvestmentCalculator {
  const InvestmentCalculator._();

  /// Monthly SIP, invested at the start of each month and compounded
  /// monthly at [annualReturnPct] / 12 — the same convention the AMC and
  /// broker SIP calculators use. [yearlyStepUpPct] raises the installment
  /// once a year (a 10% step-up turns ₹5,000 into ₹5,500 in year two).
  static GrowthResult sip({
    required Money monthly,
    required double annualReturnPct,
    required int years,
    double yearlyStepUpPct = 0,
  }) {
    if (!monthly.isPositive || years <= 0) {
      return const GrowthResult(invested: Money.zero(), maturity: Money.zero());
    }
    final i = annualReturnPct / 1200;
    var installment = monthly.paise.toDouble();
    var invested = 0.0;
    var balance = 0.0;
    for (var m = 0; m < years * 12; m++) {
      if (m > 0 && m % 12 == 0) installment *= 1 + yearlyStepUpPct / 100;
      invested += installment;
      balance = (balance + installment) * (1 + i);
    }
    return GrowthResult(
      invested: Money.fromPaise(invested.round()),
      maturity: Money.fromPaise(balance.round()),
    );
  }

  /// One-time investment compounded yearly: `P × (1 + r)^t`.
  static GrowthResult lumpsum({
    required Money principal,
    required double annualReturnPct,
    required int years,
  }) {
    if (!principal.isPositive || years <= 0) {
      return GrowthResult(invested: principal, maturity: principal);
    }
    final factor = math.pow(1 + annualReturnPct / 100, years);
    return GrowthResult(
      invested: principal,
      maturity: Money.fromPaise((principal.paise * factor).round()),
    );
  }

  /// PPF: one deposit at the start of each financial year, interest
  /// compounded yearly. Returns the balance at the end of every year so the
  /// screen can show the growth, plus the maturity summary.
  static ({GrowthResult result, List<Money> yearEndBalances}) ppf({
    required Money yearlyDeposit,
    required double annualRatePct,
    required int years,
  }) {
    final balances = <Money>[];
    if (!yearlyDeposit.isPositive || years <= 0) {
      return (
        result: const GrowthResult(
          invested: Money.zero(),
          maturity: Money.zero(),
        ),
        yearEndBalances: balances,
      );
    }
    var balance = 0.0;
    for (var y = 0; y < years; y++) {
      balance = (balance + yearlyDeposit.paise) * (1 + annualRatePct / 100);
      balances.add(Money.fromPaise(balance.round()));
    }
    return (
      result: GrowthResult(
        invested: yearlyDeposit * years,
        maturity: balances.last,
      ),
      yearEndBalances: balances,
    );
  }
}

/// PPF's statutory yearly deposit ceiling.
const Money kPpfYearlyLimit = Money(15000000);

class GstCalculator {
  const GstCalculator._();

  /// [inclusive] = the [amount] already includes GST and we're pulling it
  /// back out; otherwise GST is added on top. CGST/SGST are each half of
  /// the tax (intra-state); IGST is the whole of it (inter-state).
  static ({Money base, Money tax, Money total}) compute({
    required Money amount,
    required double ratePct,
    required bool inclusive,
  }) {
    if (inclusive) {
      final base = Money.fromPaise(
        (amount.paise * 100 / (100 + ratePct)).round(),
      );
      return (base: base, tax: amount - base, total: amount);
    }
    final tax = Money.fromPaise((amount.paise * ratePct / 100).round());
    return (base: amount, tax: tax, total: amount + tax);
  }
}

// ── Indian income tax ─────────────────────────────────────────────────────

enum TaxRegime { newRegime, oldRegime }

/// Only matters in the old regime, where seniors get a higher basic
/// exemption. The new regime has one slab table for everyone.
enum TaxpayerAge {
  below60('Below 60'),
  senior('60 – 79'),
  superSenior('80+');

  const TaxpayerAge(this.label);
  final String label;
}

/// Everything the user typed in, in rupees-as-[Money].
class TaxInput {
  const TaxInput({
    this.salary = const Money.zero(),
    this.otherIncome = const Money.zero(),
    this.age = TaxpayerAge.below60,
    this.section80C = const Money.zero(),
    this.section80D = const Money.zero(),
    this.hraExemption = const Money.zero(),
    this.homeLoanInterest = const Money.zero(),
    this.npsExtra = const Money.zero(),
    this.otherDeductions = const Money.zero(),
  });

  /// Gross salary/pension — the only income standard deduction applies to.
  final Money salary;

  /// Interest, rent, freelance, etc.
  final Money otherIncome;
  final TaxpayerAge age;

  // Old-regime-only deductions. Capped at their legal limits in
  // [IncomeTaxCalculator]; HRA and "other" are taken as typed.
  final Money section80C;
  final Money section80D;
  final Money hraExemption;
  final Money homeLoanInterest;
  final Money npsExtra;
  final Money otherDeductions;

  Money get grossIncome => salary + otherIncome;
}

class TaxBreakdown {
  const TaxBreakdown({
    required this.regime,
    required this.grossIncome,
    required this.deductions,
    required this.taxableIncome,
    required this.slabTax,
    required this.rebate,
    required this.surcharge,
    required this.cess,
  });

  final TaxRegime regime;
  final Money grossIncome;
  final Money deductions;
  final Money taxableIncome;
  final Money slabTax;

  /// Section 87A rebate, including the new regime's marginal relief just
  /// above ₹12L.
  final Money rebate;
  final Money surcharge;

  /// 4% health & education cess.
  final Money cess;

  Money get totalTax => slabTax - rebate + surcharge + cess;

  /// Total tax as a share of gross income, 0–100.
  double get effectiveRatePct =>
      grossIncome.isPositive ? totalTax.paise / grossIncome.paise * 100 : 0;
}

/// FY 2025-26 slabs (Budget 2025), which carry into FY 2026-27. All limits
/// below are in rupees.
class IncomeTaxCalculator {
  const IncomeTaxCalculator._();

  static const double _inf = double.infinity;

  static const _newSlabs = <(double, double)>[
    (400000, 0),
    (800000, 5),
    (1200000, 10),
    (1600000, 15),
    (2000000, 20),
    (2400000, 25),
    (_inf, 30),
  ];

  static List<(double, double)> _oldSlabs(TaxpayerAge age) => switch (age) {
    TaxpayerAge.below60 => const [
      (250000, 0),
      (500000, 5),
      (1000000, 20),
      (_inf, 30),
    ],
    TaxpayerAge.senior => const [
      (300000, 0),
      (500000, 5),
      (1000000, 20),
      (_inf, 30),
    ],
    TaxpayerAge.superSenior => const [(500000, 0), (1000000, 20), (_inf, 30)],
  };

  static const newStandardDeduction = 75000.0;
  static const oldStandardDeduction = 50000.0;
  static const limit80C = 150000.0;
  static const limit80D = 100000.0;
  static const limitHomeLoan = 200000.0;
  static const limitNps = 50000.0;

  static const _newRebateLimit = 1200000.0;
  static const _newRebateMax = 60000.0;
  static const _oldRebateLimit = 500000.0;
  static const _oldRebateMax = 12500.0;

  static TaxBreakdown compute(TaxInput input, TaxRegime regime) {
    final gross = input.grossIncome.rupees;
    final salary = input.salary.rupees;
    final isNew = regime == TaxRegime.newRegime;

    double deductions;
    if (isNew) {
      deductions = math.min(salary, newStandardDeduction);
    } else {
      deductions =
          math.min(salary, oldStandardDeduction) +
          math.min(input.section80C.rupees, limit80C) +
          math.min(input.section80D.rupees, limit80D) +
          input.hraExemption.rupees +
          math.min(input.homeLoanInterest.rupees, limitHomeLoan) +
          math.min(input.npsExtra.rupees, limitNps) +
          input.otherDeductions.rupees;
    }
    deductions = math.min(deductions, gross);
    final taxable = math.max(0.0, gross - deductions);

    final slabs = isNew ? _newSlabs : _oldSlabs(input.age);
    final slabTax = _slabTax(taxable, slabs);
    final afterRebate = _afterRebate(taxable, slabTax, isNew);
    final rebate = slabTax - afterRebate;

    final surcharge = _surcharge(
      taxable,
      afterRebate,
      (x) => _afterRebate(x, _slabTax(x, slabs), isNew),
      isNew,
    );
    final cess = (afterRebate + surcharge) * 0.04;

    return TaxBreakdown(
      regime: regime,
      grossIncome: input.grossIncome,
      deductions: Money.fromRupees(deductions.roundToDouble()),
      taxableIncome: Money.fromRupees(taxable.roundToDouble()),
      slabTax: Money.fromRupees(slabTax.roundToDouble()),
      rebate: Money.fromRupees(rebate.roundToDouble()),
      surcharge: Money.fromRupees(surcharge.roundToDouble()),
      cess: Money.fromRupees(cess.roundToDouble()),
    );
  }

  static double _slabTax(double income, List<(double, double)> slabs) {
    var tax = 0.0;
    var lower = 0.0;
    for (final (upper, rate) in slabs) {
      if (income <= lower) break;
      tax += (math.min(income, upper) - lower) * rate / 100;
      lower = upper;
    }
    return tax;
  }

  /// Section 87A. New regime: nil tax up to ₹12L, and just above it the tax
  /// can't exceed the income over ₹12L (marginal relief). Old regime: up to
  /// ₹12,500 off when taxable income is ₹5L or less.
  static double _afterRebate(double taxable, double tax, bool isNew) {
    if (isNew) {
      if (taxable <= _newRebateLimit) {
        return math.max(0, tax - _newRebateMax);
      }
      return math.min(tax, taxable - _newRebateLimit);
    }
    if (taxable <= _oldRebateLimit) {
      return math.max(0, tax - _oldRebateMax);
    }
    return tax;
  }

  /// Surcharge on tax above ₹50L, with marginal relief: crossing a
  /// threshold can't cost more in extra tax than the income above it. The
  /// new regime caps the rate at 25%.
  static double _surcharge(
    double taxable,
    double tax,
    double Function(double) taxAt,
    bool isNew,
  ) {
    final bands = <(double, double)>[
      (50000000, isNew ? 25 : 37),
      (20000000, 25),
      (10000000, 15),
      (5000000, 10),
    ];
    for (var b = 0; b < bands.length; b++) {
      final (threshold, rate) = bands[b];
      if (taxable <= threshold) continue;
      final belowRate = b + 1 < bands.length ? bands[b + 1].$2 : 0.0;
      var surcharge = tax * rate / 100;
      final cap =
          taxAt(threshold) * (1 + belowRate / 100) + (taxable - threshold);
      if (tax + surcharge > cap) surcharge = math.max(0, cap - tax);
      return surcharge;
    }
    return 0;
  }
}
