import 'dart:math' as math;

import 'money.dart';

/// Income tax outside India, for More → Calculators → Income Tax. Each
/// country returns the same [TaxSummary] shape so one screen can render all
/// of them. India lives in `calculators.dart` because its new-vs-old regime
/// comparison doesn't fit this shape.
///
/// Amounts are in the country's own major unit (dollars, pounds, euros)
/// wrapped in [Money] — `Money.fromRupees` just means "major units × 100",
/// whatever the currency.

/// One line of a [TaxSummary]: a tax (counted in the total) or an
/// informational row like a deduction or allowance (not counted).
class TaxLine {
  const TaxLine(this.label, this.amount, {this.isTax = true});

  final String label;
  final Money amount;
  final bool isTax;
}

class TaxSummary {
  const TaxSummary({
    required this.gross,
    required this.taxable,
    required this.lines,
    required this.marginalRatePct,
  });

  final Money gross;
  final Money taxable;
  final List<TaxLine> lines;

  /// Income tax on the next unit of income, 0–100 (payroll taxes excluded).
  final double marginalRatePct;

  Money get totalTax => lines
      .where((l) => l.isTax)
      .fold(const Money.zero(), (s, l) => s + l.amount);

  Money get afterTax => gross - totalTax;

  double get effectiveRatePct =>
      gross.isPositive ? totalTax.paise / gross.paise * 100 : 0;
}

Money _m(double v) => Money.fromRupees(v.roundToDouble());

double _slabTax(double income, List<(double, double)> slabs) {
  var tax = 0.0;
  var lower = 0.0;
  for (final (upper, rate) in slabs) {
    if (income <= lower) break;
    tax += (math.min(income, upper) - lower) * rate / 100;
    lower = upper;
  }
  return tax;
}

double _marginal(double Function(double) taxOf, double taxable) =>
    ((taxOf(taxable + 100) - taxOf(taxable)) / 100 * 100)
        .clamp(0, 100)
        .toDouble();

// ── United States ───────────────────────────────────────────────────────────

enum UsFilingStatus {
  single('Single'),
  marriedJoint('Married, joint'),
  headOfHousehold('Head of household');

  const UsFilingStatus(this.label);
  final String label;
}

/// Federal income tax + FICA for tax year 2025 (IRS Rev. Proc. 2024-40
/// brackets, standard deduction as raised by the July 2025 tax act). State
/// and local income tax are not included — they vary from 0% to 13%+.
class UsTaxCalculator {
  const UsTaxCalculator._();

  static const _inf = double.infinity;

  static List<(double, double)> _brackets(UsFilingStatus s) => switch (s) {
    UsFilingStatus.single => const [
      (11925, 10),
      (48475, 12),
      (103350, 22),
      (197300, 24),
      (250525, 32),
      (626350, 35),
      (_inf, 37),
    ],
    UsFilingStatus.marriedJoint => const [
      (23850, 10),
      (96950, 12),
      (206700, 22),
      (394600, 24),
      (501050, 32),
      (751600, 35),
      (_inf, 37),
    ],
    UsFilingStatus.headOfHousehold => const [
      (17000, 10),
      (64850, 12),
      (103350, 22),
      (197300, 24),
      (250500, 32),
      (626350, 35),
      (_inf, 37),
    ],
  };

  static double standardDeduction(UsFilingStatus s) => switch (s) {
    UsFilingStatus.single => 15750,
    UsFilingStatus.marriedJoint => 31500,
    UsFilingStatus.headOfHousehold => 23625,
  };

  static const socialSecurityWageBase = 176100.0;

  static double _additionalMedicareThreshold(UsFilingStatus s) =>
      s == UsFilingStatus.marriedJoint ? 250000 : 200000;

  /// [preTaxDeductions] = 401(k)/HSA/etc. taken out of pay before income tax
  /// (still subject to FICA). The larger of [itemizedDeductions] and the
  /// standard deduction is used, as on a real return.
  static TaxSummary compute({
    required Money wages,
    Money otherIncome = const Money.zero(),
    Money preTaxDeductions = const Money.zero(),
    Money itemizedDeductions = const Money.zero(),
    UsFilingStatus status = UsFilingStatus.single,
  }) {
    final w = wages.rupees;
    final gross = w + otherIncome.rupees;
    final std = standardDeduction(status);
    final itemized = itemizedDeductions.rupees;
    final deduction = math.max(std, itemized);
    final preTax = math.min(preTaxDeductions.rupees, gross);
    final taxable = math.max(0.0, gross - preTax - deduction);

    final brackets = _brackets(status);
    final federal = _slabTax(taxable, brackets);
    final socialSecurity = math.min(w, socialSecurityWageBase) * 0.062;
    final medicare =
        w * 0.0145 +
        math.max(0.0, w - _additionalMedicareThreshold(status)) * 0.009;

    return TaxSummary(
      gross: _m(gross),
      taxable: _m(taxable),
      marginalRatePct: _marginal((x) => _slabTax(x, brackets), taxable),
      lines: [
        if (preTax > 0)
          TaxLine('Pre-tax contributions', _m(preTax), isTax: false),
        TaxLine(
          itemized > std ? 'Itemized deductions' : 'Standard deduction',
          _m(deduction),
          isTax: false,
        ),
        TaxLine('Federal income tax', _m(federal)),
        TaxLine('Social Security (6.2%)', _m(socialSecurity)),
        TaxLine('Medicare', _m(medicare)),
      ],
    );
  }
}

// ── United Kingdom ──────────────────────────────────────────────────────────

/// Income tax + employee National Insurance for England, Wales and Northern
/// Ireland, tax years 2025/26 and 2026/27 (thresholds are frozen). Scotland
/// has its own income tax bands and isn't covered.
class UkTaxCalculator {
  const UkTaxCalculator._();

  static const personalAllowance = 12570.0;
  static const _taperStart = 100000.0;
  static const _basicBand = 37700.0;
  static const _additionalThreshold = 125140.0;
  static const _niPrimaryThreshold = 12570.0;
  static const _niUpperLimit = 50270.0;

  static double allowanceFor(double income) =>
      math.max(0, personalAllowance - math.max(0, income - _taperStart) / 2);

  static double _incomeTax(double income) {
    final taxable = math.max(0.0, income - allowanceFor(income));
    return math.min(taxable, _basicBand) * 0.20 +
        (math.min(taxable, _additionalThreshold) - _basicBand).clamp(
              0,
              double.infinity,
            ) *
            0.40 +
        math.max(0.0, taxable - _additionalThreshold) * 0.45;
  }

  /// [pensionSacrifice] comes off salary before both income tax and NI.
  /// [otherIncome] (rent, interest, self-employment) pays income tax only.
  static TaxSummary compute({
    required Money salary,
    Money otherIncome = const Money.zero(),
    Money pensionSacrifice = const Money.zero(),
  }) {
    final grossSalary = salary.rupees;
    final sacrifice = math.min(pensionSacrifice.rupees, grossSalary);
    final payeSalary = grossSalary - sacrifice;
    final income = payeSalary + otherIncome.rupees;
    final allowance = allowanceFor(income);
    final taxable = math.max(0.0, income - allowance);

    final ni =
        (math.min(payeSalary, _niUpperLimit) - _niPrimaryThreshold).clamp(
              0,
              double.infinity,
            ) *
            0.08 +
        math.max(0.0, payeSalary - _niUpperLimit) * 0.02;

    return TaxSummary(
      gross: _m(grossSalary + otherIncome.rupees),
      taxable: _m(taxable),
      // Numeric so the 60% band from the allowance taper shows up.
      marginalRatePct: _marginal(_incomeTax, income),
      lines: [
        if (sacrifice > 0)
          TaxLine('Pension (salary sacrifice)', _m(sacrifice), isTax: false),
        TaxLine('Personal allowance', _m(allowance), isTax: false),
        TaxLine('Income tax', _m(_incomeTax(income))),
        TaxLine('National Insurance', _m(ni)),
      ],
    );
  }
}

// ── Germany ─────────────────────────────────────────────────────────────────

/// Einkommensteuer (§32a EStG, 2025 tariff) + Solidaritätszuschlag, from
/// taxable income (zu versteuerndes Einkommen). Social insurance and church
/// tax are not included.
class GermanyTaxCalculator {
  const GermanyTaxCalculator._();

  static const basicAllowance = 12096.0;
  static const _soliThresholdSingle = 19950.0;

  /// The 2025 tariff formula for one person, floored to whole euros as the
  /// law requires.
  static double tariff(double zvE) {
    final x = zvE.floorToDouble();
    double tax;
    if (x <= basicAllowance) {
      tax = 0;
    } else if (x <= 17443) {
      final y = (x - basicAllowance) / 10000;
      tax = (932.30 * y + 1400) * y;
    } else if (x <= 68480) {
      final z = (x - 17443) / 10000;
      tax = (176.64 * z + 2397) * z + 1015.13;
    } else if (x <= 277825) {
      tax = 0.42 * x - 10911.92;
    } else {
      tax = 0.45 * x - 19246.67;
    }
    return tax.floorToDouble();
  }

  /// Married couples filing jointly use splitting: twice the tax on half the
  /// joint income.
  static double incomeTax(double zvE, {required bool married}) =>
      married ? 2 * tariff((zvE / 2).floorToDouble()) : tariff(zvE);

  static TaxSummary compute({
    required Money taxableIncome,
    bool married = false,
  }) {
    final zvE = math.max(0.0, taxableIncome.rupees);
    final est = incomeTax(zvE, married: married);
    final threshold = _soliThresholdSingle * (married ? 2 : 1);
    // 5.5%, phased in above the exemption: never more than 11.9% of the
    // income tax above it.
    final soli = est <= threshold
        ? 0.0
        : math.min(est * 0.055, (est - threshold) * 0.119);

    return TaxSummary(
      gross: _m(zvE),
      taxable: _m(zvE),
      marginalRatePct: _marginal((x) => incomeTax(x, married: married), zvE),
      lines: [
        TaxLine('Einkommensteuer (income tax)', _m(est)),
        TaxLine('Solidaritätszuschlag', _m(soli)),
      ],
    );
  }
}
