import 'package:flutter/material.dart';

import '../../core/loan_amortization.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import 'calculator_widgets.dart';
import '../../core/l10n/l10n.dart';

/// Reducing-balance EMI calculator. Reuses [LoanAmortization] — the same
/// math behind real loans in Goals & Loans — so the numbers here match what
/// the app shows once the loan is actually added.
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen>
    with CalculatorFormMixin {
  late final _principal = field('1000000');
  late final _rate = field('9');
  late final _years = field('5');
  late final _months = field('0');
  late final _extra = field('0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final principal = moneyOf(_principal);
    final rate = numOf(_rate);
    final tenure = intOf(_years) * 12 + intOf(_months);
    final extra = moneyOf(_extra);

    final emi = LoanAmortization.calculateEmi(
      principal: principal,
      annualRatePct: rate,
      tenureMonths: tenure,
    );
    final schedule = LoanAmortization.schedule(
      startingBalance: principal,
      annualRatePct: rate,
      emi: emi,
    );
    final totalInterest = schedule.fold(
      const Money.zero(),
      (Money s, r) => s + r.interest,
    );

    // Prepayment comparison, only when an extra amount is entered.
    final withExtra = extra.isPositive && emi.isPositive
        ? LoanAmortization.schedule(
            startingBalance: principal,
            annualRatePct: rate,
            emi: emi,
            extraPerMonth: extra,
          )
        : null;
    final extraInterest = withExtra?.fold(
      const Money.zero(),
      (Money s, r) => s + r.interest,
    );

    // Group the month-by-month schedule into loan years.
    final yearly = <({Money principal, Money interest, Money balance})>[];
    for (var i = 0; i < schedule.length; i += 12) {
      final chunk = schedule.skip(i).take(12);
      yearly.add((
        principal: chunk.fold(const Money.zero(), (s, r) => s + r.principal),
        interest: chunk.fold(const Money.zero(), (s, r) => s + r.interest),
        balance: chunk.last.balance,
      ));
    }

    return CalculatorScaffold(
      title: tr('Loan EMI'),
      children: [
        CalcField(
          controller: _principal,
          label: tr('Loan amount'),
          prefix: MoneyFormat.inputPrefix,
        ),
        CalcField(controller: _rate, label: tr('Interest rate'), suffix: '% p.a.'),
        CalcFieldPair(
          CalcField(
            controller: _years,
            label: tr('Years'),
            suffix: 'yrs',
            decimal: false,
          ),
          CalcField(
            controller: _months,
            label: tr('Months'),
            suffix: 'mo',
            decimal: false,
          ),
        ),
        const SizedBox(height: 4),
        CalcResultCard(
          label: tr('Monthly EMI'),
          value: emi,
          format: MoneyFormat.symbol,
          sub: tenure <= 0
              ? tr('Enter a tenure')
              : tr('Total payable {0}', [MoneyFormat.symbol(principal + totalInterest)]),
          parts: [
            CalcPart(tr('Principal'), principal, cs.primary),
            CalcPart(tr('Total interest'), totalInterest, AppColors.expense),
          ],
        ),
        const SizedBox(height: 20),
        Tr(
          'Prepay every month',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        CalcField(
          controller: _extra,
          label: tr('Extra payment on top of EMI'),
          prefix: MoneyFormat.inputPrefix,
        ),
        if (withExtra != null && extraInterest != null)
          CalcBreakdownCard(
            rows: [
              CalcRow(
                tr('Loan closes in'),
                tr('{0} months (vs {1})', [withExtra.length, tenure]),
              ),
              CalcRow(
                tr('Interest saved'),
                MoneyFormat.symbol(totalInterest - extraInterest),
                bold: true,
              ),
            ],
          ),
        if (yearly.isNotEmpty) ...[
          const SizedBox(height: 20),
          Tr(
            'Year-wise schedule',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _ScheduleRow(
                    tr('Year'),
                    tr('Principal'),
                    tr('Interest'),
                    tr('Balance'),
                    header: true,
                  ),
                  for (var y = 0; y < yearly.length; y++)
                    _ScheduleRow(
                      '${y + 1}',
                      MoneyFormat.compact(yearly[y].principal),
                      MoneyFormat.compact(yearly[y].interest),
                      MoneyFormat.compact(yearly[y].balance),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow(
    this.year,
    this.principal,
    this.interest,
    this.balance, {
    this.header = false,
  });

  final String year;
  final String principal;
  final String interest;
  final String balance;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = header
        ? theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          )
        : theme.textTheme.bodySmall?.copyWith(fontFeatures: kTabularFigures);
    Widget cell(String t, {int flex = 3}) => Expanded(
      flex: flex,
      child: Text(t, style: style, textAlign: TextAlign.end),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(year, style: style)),
          cell(principal),
          cell(interest),
          cell(balance),
        ],
      ),
    );
  }
}
