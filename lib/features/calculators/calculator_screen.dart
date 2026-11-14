import 'package:flutter/material.dart';

import '../../core/calculators.dart';
import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import 'calculator_kind.dart';
import 'calculator_widgets.dart';
import 'loan_calculator_screen.dart';
import 'tax_calculator_screen.dart';
import '../../core/l10n/l10n.dart';

/// Route target for `/more/calculators/<kind>`.
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({required this.kind, super.key});

  final CalculatorKind kind;

  @override
  Widget build(BuildContext context) => switch (kind) {
    CalculatorKind.deposit => const DepositCalculatorScreen(),
    CalculatorKind.loan => const LoanCalculatorScreen(),
    CalculatorKind.incomeTax => const TaxCalculatorScreen(),
    CalculatorKind.sip => const SipCalculatorScreen(),
    CalculatorKind.ppf => const PpfCalculatorScreen(),
    CalculatorKind.gst => const GstCalculatorScreen(),
  };
}

/// Rupee formatting for the India-only calculators (tax, PPF, GST), whatever
/// currency the app is set to.
String formatInr(Money m) => MoneyFormat.forCurrency(m, kDefaultCurrency);

// ── FD & RD ─────────────────────────────────────────────────────────────────

enum _DepositMode { fd, rd }

class DepositCalculatorScreen extends StatefulWidget {
  const DepositCalculatorScreen({super.key});

  @override
  State<DepositCalculatorScreen> createState() =>
      _DepositCalculatorScreenState();
}

class _DepositCalculatorScreenState extends State<DepositCalculatorScreen>
    with CalculatorFormMixin {
  var _mode = _DepositMode.fd;
  var _compounding = Compounding.quarterly;
  late final _amount = field('100000');
  late final _rate = field('7');
  late final _years = field('5');
  late final _months = field('0');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFd = _mode == _DepositMode.fd;
    final months = intOf(_years) * 12 + intOf(_months);
    final result = isFd
        ? DepositCalculator.fixedDeposit(
            principal: moneyOf(_amount),
            annualRatePct: numOf(_rate),
            months: months,
            compounding: _compounding,
          )
        : DepositCalculator.recurringDeposit(
            installment: moneyOf(_amount),
            annualRatePct: numOf(_rate),
            months: months,
          );

    return CalculatorScaffold(
      title: tr('FD & RD'),
      children: [
        CalcModeToggle(
          value: _mode,
          options: {
            _DepositMode.fd: tr('Fixed deposit'),
            _DepositMode.rd: tr('Recurring deposit'),
          },
          onChanged: (m) => setState(() => _mode = m),
        ),
        CalcField(
          controller: _amount,
          label: isFd ? tr('Deposit amount') : tr('Monthly deposit'),
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
        if (isFd)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in Compounding.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _compounding == c,
                    onSelected: (_) => setState(() => _compounding = c),
                  ),
              ],
            ),
          )
        else
          const SizedBox(height: 4),
        CalcResultCard(
          label: tr('Maturity value'),
          value: result.maturity,
          format: MoneyFormat.symbol,
          sub: months <= 0 ? tr('Enter a tenure') : 'After ${_tenure(months)}',
          parts: [
            CalcPart(
              isFd ? tr('Deposit') : tr('Total deposited'),
              result.invested,
              cs.primary,
            ),
            CalcPart(tr('Interest earned'), result.returns, AppColors.income),
          ],
        ),
        if (!isFd) ...[
          const SizedBox(height: 12),
          Tr(
            'Compounded quarterly, the way banks and the post office '
            'calculate RD interest.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

String _tenure(int months) {
  final y = months ~/ 12;
  final m = months % 12;
  return [
    if (y > 0) tr('{0} year{1}', [y, y == 1 ? '' : 's']),
    if (m > 0) tr('{0} month{1}', [m, m == 1 ? '' : 's']),
  ].join(' ');
}

// ── SIP & Lumpsum ───────────────────────────────────────────────────────────

enum _InvestMode { sip, lumpsum }

class SipCalculatorScreen extends StatefulWidget {
  const SipCalculatorScreen({super.key});

  @override
  State<SipCalculatorScreen> createState() => _SipCalculatorScreenState();
}

class _SipCalculatorScreenState extends State<SipCalculatorScreen>
    with CalculatorFormMixin {
  var _mode = _InvestMode.sip;
  late final _amount = field('5000');
  late final _lumpsum = field('100000');
  late final _rate = field('12');
  late final _years = field('10');
  late final _stepUp = field('0');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSip = _mode == _InvestMode.sip;
    final result = isSip
        ? InvestmentCalculator.sip(
            monthly: moneyOf(_amount),
            annualReturnPct: numOf(_rate),
            years: intOf(_years),
            yearlyStepUpPct: numOf(_stepUp),
          )
        : InvestmentCalculator.lumpsum(
            principal: moneyOf(_lumpsum),
            annualReturnPct: numOf(_rate),
            years: intOf(_years),
          );

    return CalculatorScaffold(
      title: tr('SIP & Lumpsum'),
      footnote:
          tr('Market returns are not guaranteed. This assumes the same return '
          'every year, which real funds never deliver.'),
      children: [
        CalcModeToggle(
          value: _mode,
          options: {
            _InvestMode.sip: tr('Monthly SIP'),
            _InvestMode.lumpsum: 'Lumpsum',
          },
          onChanged: (m) => setState(() => _mode = m),
        ),
        if (isSip)
          CalcField(
            controller: _amount,
            label: tr('Monthly investment'),
            prefix: MoneyFormat.inputPrefix,
          )
        else
          CalcField(
            controller: _lumpsum,
            label: tr('One-time investment'),
            prefix: MoneyFormat.inputPrefix,
          ),
        CalcFieldPair(
          CalcField(
            controller: _rate,
            label: tr('Expected return'),
            suffix: '% p.a.',
          ),
          CalcField(
            controller: _years,
            label: tr('Period'),
            suffix: 'yrs',
            decimal: false,
          ),
        ),
        if (isSip)
          CalcField(
            controller: _stepUp,
            label: tr('Yearly step-up (optional)'),
            suffix: '%',
            helper: tr('Raise your SIP by this much every year'),
          ),
        const SizedBox(height: 4),
        CalcResultCard(
          label: tr('Estimated value'),
          value: result.maturity,
          format: MoneyFormat.symbol,
          parts: [
            CalcPart(tr('Invested'), result.invested, cs.primary),
            CalcPart(tr('Estimated returns'), result.returns, AppColors.income),
          ],
        ),
      ],
    );
  }
}

// ── PPF ─────────────────────────────────────────────────────────────────────

class PpfCalculatorScreen extends StatefulWidget {
  const PpfCalculatorScreen({super.key});

  @override
  State<PpfCalculatorScreen> createState() => _PpfCalculatorScreenState();
}

class _PpfCalculatorScreenState extends State<PpfCalculatorScreen>
    with CalculatorFormMixin {
  late final _deposit = field('150000');
  late final _rate = field('7.1');
  late final _years = field('15');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final deposit = moneyOf(_deposit);
    final years = intOf(_years);
    final ppf = InvestmentCalculator.ppf(
      yearlyDeposit: deposit,
      annualRatePct: numOf(_rate),
      years: years,
    );
    final overLimit = deposit > kPpfYearlyLimit;

    return CalculatorScaffold(
      title: 'PPF',
      footnote:
          tr('Estimates only. The PPF rate is set by the government every '
          'quarter; this assumes today\'s rate for the whole period.'),
      children: [
        CalcField(
          controller: _deposit,
          label: tr('Yearly deposit'),
          prefix: '₹ ',
          helper: overLimit
              ? tr('PPF allows at most {0} a year', [formatInr(kPpfYearlyLimit)])
              : tr('Minimum ₹500, maximum {0}', [formatInr(kPpfYearlyLimit)]),
        ),
        CalcFieldPair(
          CalcField(controller: _rate, label: tr('Interest rate'), suffix: '%'),
          CalcField(
            controller: _years,
            label: tr('Period'),
            suffix: 'yrs',
            decimal: false,
            helper: tr('15, then +5 blocks'),
          ),
        ),
        const SizedBox(height: 4),
        CalcResultCard(
          label: tr('Maturity value'),
          value: ppf.result.maturity,
          format: formatInr,
          sub: tr('Tax-free at maturity (EEE)'),
          parts: [
            CalcPart(tr('Total deposited'), ppf.result.invested, cs.primary),
            CalcPart(tr('Interest earned'), ppf.result.returns, AppColors.income),
          ],
        ),
        if (ppf.yearEndBalances.isNotEmpty) ...[
          const SizedBox(height: 20),
          Tr(
            'Year-end balance',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          CalcBreakdownCard(
            rows: [
              for (var y = 0; y < ppf.yearEndBalances.length; y++)
                CalcRow('Year ${y + 1}', formatInr(ppf.yearEndBalances[y])),
            ],
          ),
        ],
      ],
    );
  }
}

// ── GST ─────────────────────────────────────────────────────────────────────

class GstCalculatorScreen extends StatefulWidget {
  const GstCalculatorScreen({super.key});

  @override
  State<GstCalculatorScreen> createState() => _GstCalculatorScreenState();
}

class _GstCalculatorScreenState extends State<GstCalculatorScreen>
    with CalculatorFormMixin {
  static const _rates = <double>[3, 5, 12, 18, 28, 40];

  var _inclusive = false;
  late final _amount = field('1000');
  late final _rate = field('18');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rate = numOf(_rate);
    final gst = GstCalculator.compute(
      amount: moneyOf(_amount),
      ratePct: rate,
      inclusive: _inclusive,
    );
    final half = Money.fromPaise((gst.tax.paise / 2).round());

    return CalculatorScaffold(
      title: 'GST',
      children: [
        CalcModeToggle(
          value: _inclusive,
          options: {false: tr('Add GST'), true: tr('Remove GST')},
          onChanged: (v) => setState(() => _inclusive = v),
        ),
        CalcField(
          controller: _amount,
          label: _inclusive ? tr('Price including GST') : tr('Price before GST'),
          prefix: '₹ ',
        ),
        CalcField(controller: _rate, label: tr('GST rate'), suffix: '%'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _rates)
                ChoiceChip(
                  label: Text('${r.toStringAsFixed(0)}%'),
                  selected: rate == r,
                  onSelected: (_) => _rate.text = r.toStringAsFixed(0),
                ),
            ],
          ),
        ),
        CalcResultCard(
          label: _inclusive ? tr('Price before GST') : tr('Total price'),
          value: _inclusive ? gst.base : gst.total,
          format: formatInr,
          parts: [
            CalcPart(tr('Base price'), gst.base, cs.primary),
            CalcPart('GST', gst.tax, AppColors.expense),
          ],
        ),
        const SizedBox(height: 12),
        CalcBreakdownCard(
          rows: [
            CalcRow('CGST (${_trim(rate / 2)}%)', formatInr(half)),
            CalcRow('SGST (${_trim(rate / 2)}%)', formatInr(gst.tax - half)),
            CalcRow(tr('IGST ({0}%) · inter-state', [_trim(rate)]), formatInr(gst.tax)),
          ],
        ),
      ],
    );
  }
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
