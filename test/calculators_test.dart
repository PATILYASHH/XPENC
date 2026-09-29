import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/calculators.dart';
import 'package:xpenc/core/money.dart';

Money r(num rupees) => Money.fromRupees(rupees);

void main() {
  group('DepositCalculator', () {
    test('FD compounds quarterly: 1L at 7% for 5 years', () {
      final res = DepositCalculator.fixedDeposit(
        principal: r(100000),
        annualRatePct: 7,
        months: 60,
      );
      expect(res.maturity, const Money(14147782));
      expect(res.returns, const Money(4147782));
    });

    test('RD: 5,000/month at 7% for 12 months, quarterly compounding', () {
      final res = DepositCalculator.recurringDeposit(
        installment: r(5000),
        annualRatePct: 7,
        months: 12,
      );
      expect(res.invested, r(60000));
      expect(res.maturity, const Money(6231066));
    });

    test('zero tenure returns the principal untouched', () {
      final res = DepositCalculator.fixedDeposit(
        principal: r(1000),
        annualRatePct: 7,
        months: 0,
      );
      expect(res.maturity, r(1000));
    });
  });

  group('InvestmentCalculator', () {
    test('SIP: 5,000/month at 12% for 10 years', () {
      final res = InvestmentCalculator.sip(
        monthly: r(5000),
        annualReturnPct: 12,
        years: 10,
      );
      expect(res.invested, r(600000));
      expect(res.maturity, const Money(116169538));
    });

    test('SIP step-up invests more each year', () {
      final res = InvestmentCalculator.sip(
        monthly: r(5000),
        annualReturnPct: 12,
        years: 2,
        yearlyStepUpPct: 10,
      );
      expect(res.invested, r(5000 * 12 + 5500 * 12));
    });

    test('lumpsum: 1L at 12% for 10 years', () {
      final res = InvestmentCalculator.lumpsum(
        principal: r(100000),
        annualReturnPct: 12,
        years: 10,
      );
      expect(res.maturity, const Money(31058482));
    });

    test('PPF: 1.5L/year at 7.1% for 15 years', () {
      final ppf = InvestmentCalculator.ppf(
        yearlyDeposit: r(150000),
        annualRatePct: 7.1,
        years: 15,
      );
      expect(ppf.yearEndBalances, hasLength(15));
      expect(ppf.result.invested, r(2250000));
      expect(ppf.result.maturity, const Money(406820922));
    });
  });

  group('GstCalculator', () {
    test('adds 18% on top', () {
      final g = GstCalculator.compute(
        amount: r(1000),
        ratePct: 18,
        inclusive: false,
      );
      expect(g.tax, r(180));
      expect(g.total, r(1180));
    });

    test('pulls 18% back out of an inclusive price', () {
      final g = GstCalculator.compute(
        amount: r(1180),
        ratePct: 18,
        inclusive: true,
      );
      expect(g.base, r(1000));
      expect(g.tax, r(180));
    });
  });

  group('IncomeTaxCalculator', () {
    TaxBreakdown newRegime(num salary) => IncomeTaxCalculator.compute(
      TaxInput(salary: r(salary)),
      TaxRegime.newRegime,
    );

    test('new regime: 12.75L salary is tax-free (75k std deduction + 87A)', () {
      final t = newRegime(1275000);
      expect(t.taxableIncome, r(1200000));
      expect(t.totalTax, const Money.zero());
    });

    test('new regime: marginal relief just above 12L', () {
      // Taxable 12.5L → slab tax 67,500, capped at the 50,000 above 12L.
      final t = newRegime(1325000);
      expect(t.slabTax, r(67500));
      expect(t.totalTax, r(52000));
    });

    test('new regime: 13L taxable pays slab tax + cess', () {
      expect(newRegime(1375000).totalTax, r(78000));
    });

    test('old regime: 10L salary with full 80C', () {
      final t = IncomeTaxCalculator.compute(
        TaxInput(salary: r(1000000), section80C: r(200000)),
        TaxRegime.oldRegime,
      );
      expect(t.deductions, r(200000)); // 50k std + 80C capped at 1.5L
      expect(t.taxableIncome, r(800000));
      expect(t.totalTax, r(75400));
    });

    test('old regime: 87A wipes tax out at 5L taxable', () {
      final t = IncomeTaxCalculator.compute(
        TaxInput(salary: r(550000)),
        TaxRegime.oldRegime,
      );
      expect(t.taxableIncome, r(500000));
      expect(t.totalTax, const Money.zero());
    });

    test('surcharge marginal relief just above 50L', () {
      final t = IncomeTaxCalculator.compute(
        TaxInput(otherIncome: r(5010000)),
        TaxRegime.newRegime,
      );
      expect(t.slabTax, r(1083000));
      expect(t.surcharge, r(7000));
    });

    test('full 10% surcharge well above 50L', () {
      final t = IncomeTaxCalculator.compute(
        TaxInput(otherIncome: r(6000000)),
        TaxRegime.newRegime,
      );
      expect(t.slabTax, r(1380000));
      expect(t.surcharge, r(138000));
    });
  });
}
