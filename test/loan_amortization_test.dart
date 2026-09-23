import 'package:flutter_test/flutter_test.dart';
import 'package:xpenc/core/loan_amortization.dart';
import 'package:xpenc/core/money.dart';

void main() {
  group('calculateEmi', () {
    test('₹1,00,000 at 10%/yr over 12 months matches the textbook EMI', () {
      final emi = LoanAmortization.calculateEmi(
        principal: Money.fromRupees(100000),
        annualRatePct: 10,
        tenureMonths: 12,
      );
      // Standard EMI calculators give ₹8,791.59 for these inputs.
      expect(emi.rupees, closeTo(8791.59, 1));
    });

    test('a zero rate splits the principal evenly across the tenure', () {
      final emi = LoanAmortization.calculateEmi(
        principal: Money.fromRupees(12000),
        annualRatePct: 0,
        tenureMonths: 12,
      );
      expect(emi, Money.fromRupees(1000));
    });
  });

  group('periodInterest', () {
    test('is zero with no rate', () {
      expect(
        LoanAmortization.periodInterest(
          outstandingPrincipal: Money.fromRupees(50000),
          annualRatePct: null,
        ),
        const Money.zero(),
      );
    });

    test('is zero once the balance is paid off', () {
      expect(
        LoanAmortization.periodInterest(
          outstandingPrincipal: const Money.zero(),
          annualRatePct: 12,
        ),
        const Money.zero(),
      );
    });

    test('charges one month of the annual rate on the outstanding balance', () {
      final interest = LoanAmortization.periodInterest(
        outstandingPrincipal: Money.fromRupees(120000),
        annualRatePct: 12,
      );
      // 12%/yr == 1%/month.
      expect(interest, Money.fromRupees(1200));
    });
  });

  group('amortizeToZero', () {
    test(
      "reproduces calculateEmi's own schedule length and total interest",
      () {
        final principal = Money.fromRupees(100000);
        const rate = 10.0;
        const tenure = 12;
        final emi = LoanAmortization.calculateEmi(
          principal: principal,
          annualRatePct: rate,
          tenureMonths: tenure,
        );

        final result = LoanAmortization.amortizeToZero(
          startingBalance: principal,
          annualRatePct: rate,
          emi: emi,
        );

        expect(result.months, tenure);
        // Total paid across the schedule should equal principal + interest,
        // within a few paise of EMI-rounding slack.
        final totalPaid = Money.fromPaise(emi.paise * result.months);
        expect(
          totalPaid.paise,
          closeTo((principal + result.totalInterest).paise, tenure),
        );
      },
    );

    test('an EMI too small to cover interest amortizes nothing', () {
      final result = LoanAmortization.amortizeToZero(
        startingBalance: Money.fromRupees(100000),
        annualRatePct: 12,
        emi: Money.fromRupees(500), // < 1%/month interest of ₹1,000
      );
      expect(result.months, 0);
      expect(result.totalInterest, const Money.zero());
    });

    test('a partial prepayment lowers total interest versus the original '
        'schedule', () {
      const principal = 100000.0;
      const rate = 10.0;
      const tenure = 24;
      final emi = LoanAmortization.calculateEmi(
        principal: Money.fromRupees(principal),
        annualRatePct: rate,
        tenureMonths: tenure,
      );
      final original = LoanAmortization.amortizeToZero(
        startingBalance: Money.fromRupees(principal),
        annualRatePct: rate,
        emi: emi,
      );

      // Simulate having paid an extra ₹20,000 off the principal at some
      // point, then continuing at the same EMI from there.
      final withPrepayment = LoanAmortization.amortizeToZero(
        startingBalance: Money.fromRupees(principal - 20000),
        annualRatePct: rate,
        emi: emi,
      );

      expect(
        withPrepayment.totalInterest.paise,
        lessThan(original.totalInterest.paise),
      );
      expect(withPrepayment.months, lessThan(original.months));
    });
  });
}
