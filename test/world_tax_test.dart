import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/money.dart';
import 'package:xpenc/core/world_tax.dart';

Money m(num v) => Money.fromRupees(v);

Money line(TaxSummary s, String prefix) =>
    s.lines.firstWhere((l) => l.label.startsWith(prefix)).amount;

void main() {
  group('UsTaxCalculator (2025)', () {
    test('single, 75k wages: federal + FICA', () {
      final s = UsTaxCalculator.compute(wages: m(75000));
      expect(s.taxable, m(59250)); // 75,000 − 15,750 standard deduction
      expect(line(s, 'Federal'), m(7949));
      expect(line(s, 'Social Security'), m(4650));
      expect(line(s, 'Medicare'), m(1088));
      expect(s.totalTax, m(13687));
      expect(s.marginalRatePct, closeTo(22, 0.01));
    });

    test(
      'Social Security caps at the wage base; extra Medicare above 250k MFJ',
      () {
        final s = UsTaxCalculator.compute(
          wages: m(400000),
          status: UsFilingStatus.marriedJoint,
        );
        expect(line(s, 'Social Security'), m(10918));
        expect(line(s, 'Medicare'), m(7150));
      },
    );

    test('itemized deductions win only when larger than standard', () {
      final low = UsTaxCalculator.compute(
        wages: m(75000),
        itemizedDeductions: m(5000),
      );
      final high = UsTaxCalculator.compute(
        wages: m(75000),
        itemizedDeductions: m(25000),
      );
      expect(low.taxable, m(59250));
      expect(high.taxable, m(50000));
    });
  });

  group('UkTaxCalculator (2025/26)', () {
    test('45k salary', () {
      final s = UkTaxCalculator.compute(salary: m(45000));
      expect(line(s, 'Income tax'), m(6486));
      expect(line(s, 'National Insurance'), m(2594));
    });

    test('personal allowance tapers above 100k — 60% marginal band', () {
      final s = UkTaxCalculator.compute(salary: m(110000));
      expect(line(s, 'Personal allowance'), m(7570));
      expect(line(s, 'Income tax'), m(33432));
      expect(s.marginalRatePct, closeTo(60, 0.01));
    });

    test('additional rate above 125,140', () {
      final s = UkTaxCalculator.compute(salary: m(130000));
      expect(line(s, 'Personal allowance'), const Money.zero());
      expect(line(s, 'Income tax'), m(44703));
    });

    test('salary sacrifice cuts both income tax and NI', () {
      final s = UkTaxCalculator.compute(
        salary: m(45000),
        pensionSacrifice: m(5000),
      );
      expect(line(s, 'Income tax'), m(5486));
      expect(line(s, 'National Insurance'), m(2194));
    });
  });

  group('GermanyTaxCalculator (2025)', () {
    test('tariff zones', () {
      expect(GermanyTaxCalculator.tariff(12096), 0);
      expect(GermanyTaxCalculator.tariff(15000), 485);
      expect(GermanyTaxCalculator.tariff(50000), 10691);
      expect(GermanyTaxCalculator.tariff(100000), 31088);
    });

    test('splitting halves the income for married couples', () {
      final s = GermanyTaxCalculator.compute(
        taxableIncome: m(100000),
        married: true,
      );
      expect(line(s, 'Einkommensteuer'), m(21382));
      expect(line(s, 'Solidarit'), const Money.zero());
    });

    test('Soli phases in above the exemption', () {
      final s = GermanyTaxCalculator.compute(taxableIncome: m(100000));
      // min(5.5% × 31,088, 11.9% × (31,088 − 19,950))
      expect(line(s, 'Solidarit'), m(1325));
    });
  });
}
