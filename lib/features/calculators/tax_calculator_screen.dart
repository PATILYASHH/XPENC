import 'package:flutter/material.dart';

import '../../core/calculators.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import 'calculator_screen.dart' show formatInr;
import '../../core/widgets/app_surfaces.dart';
import 'calculator_widgets.dart';
import 'world_tax_bodies.dart';

/// Income tax by country. India compares its two regimes; every other
/// country renders a [TaxSummaryView]. Opens on the country matching the
/// app's currency.
class TaxCalculatorScreen extends StatefulWidget {
  const TaxCalculatorScreen({super.key});

  @override
  State<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends State<TaxCalculatorScreen> {
  late var _country = TaxCountry.forCurrency(MoneyFormat.currency.code);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return CalculatorScaffold(
      title: 'Income Tax',
      footnote: _country.footnote,
      children: [
        DropdownButtonFormField<TaxCountry>(
          initialValue: _country,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Country',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in TaxCountry.values)
              DropdownMenuItem(value: c, child: Text('${c.flag}  ${c.label}')),
          ],
          onChanged: (c) {
            if (c != null) setState(() => _country = c);
          },
        ),
        const SizedBox(height: 8),
        switch (_country) {
          TaxCountry.india => const _IndiaTaxBody(),
          TaxCountry.us => const UsTaxBody(),
          TaxCountry.uk => const UkTaxBody(),
          TaxCountry.germany => const GermanyTaxBody(),
        },
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(Icons.public_rounded, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'More countries will be added over time. Missing yours? '
                  'Tell us via About → Feedback & suggestions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Indian income tax, new vs old regime side by side. Salaried users get
/// the standard deduction automatically; old-regime deductions are capped
/// at their legal limits by [IncomeTaxCalculator].
class _IndiaTaxBody extends StatefulWidget {
  const _IndiaTaxBody();

  @override
  State<_IndiaTaxBody> createState() => _IndiaTaxBodyState();
}

class _IndiaTaxBodyState extends State<_IndiaTaxBody> with CalculatorFormMixin {
  var _age = TaxpayerAge.below60;
  var _shown = TaxRegime.newRegime;
  late final _salary = field('1200000');
  late final _other = field('0');
  late final _sec80c = field('150000');
  late final _sec80d = field('0');
  late final _hra = field('0');
  late final _homeLoan = field('0');
  late final _nps = field('0');
  late final _otherDed = field('0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final input = TaxInput(
      salary: moneyOf(_salary),
      otherIncome: moneyOf(_other),
      age: _age,
      section80C: moneyOf(_sec80c),
      section80D: moneyOf(_sec80d),
      hraExemption: moneyOf(_hra),
      homeLoanInterest: moneyOf(_homeLoan),
      npsExtra: moneyOf(_nps),
      otherDeductions: moneyOf(_otherDed),
    );
    final newTax = IncomeTaxCalculator.compute(input, TaxRegime.newRegime);
    final oldTax = IncomeTaxCalculator.compute(input, TaxRegime.oldRegime);
    final diff = newTax.totalTax - oldTax.totalTax;
    final shown = _shown == TaxRegime.newRegime ? newTax : oldTax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CalcHeading('Income (yearly)'),
        CalcField(controller: _salary, label: 'Salary / pension', prefix: '₹ '),
        CalcField(
          controller: _other,
          label: 'Other income',
          prefix: '₹ ',
          helper: 'Interest, rent, freelance, etc.',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Age', style: theme.textTheme.bodyMedium),
              for (final a in TaxpayerAge.values)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _age == a,
                  onSelected: (_) => setState(() => _age = a),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _RegimeCompare(newTax: newTax, oldTax: oldTax),
        const SizedBox(height: 8),
        Text(
          diff.isZero
              ? 'Both regimes cost the same.'
              : diff.isNegative
              ? 'New regime saves you ${formatInr(-diff)}'
              : 'Old regime saves you ${formatInr(diff)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: diff.isZero ? cs.onSurfaceVariant : AppColors.income,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const CalcHeading('Old regime deductions'),
        CalcField(
          controller: _sec80c,
          label: '80C (PF, ELSS, LIC, PPF…)',
          prefix: '₹ ',
          helper: 'Up to ₹1,50,000',
        ),
        CalcField(
          controller: _sec80d,
          label: '80D (health insurance)',
          prefix: '₹ ',
        ),
        CalcField(controller: _hra, label: 'HRA exemption', prefix: '₹ '),
        CalcField(
          controller: _homeLoan,
          label: 'Home loan interest (24b)',
          prefix: '₹ ',
          helper: 'Up to ₹2,00,000 for a self-occupied home',
        ),
        CalcField(
          controller: _nps,
          label: 'NPS 80CCD(1B)',
          prefix: '₹ ',
          helper: 'Up to ₹50,000',
        ),
        CalcField(
          controller: _otherDed,
          label: 'Other deductions',
          prefix: '₹ ',
          helper: '80E, 80G, 80TTA, professional tax…',
        ),
        const SizedBox(height: 8),
        const CalcHeading('Breakdown'),
        CalcModeToggle(
          value: _shown,
          options: const {
            TaxRegime.newRegime: 'New regime',
            TaxRegime.oldRegime: 'Old regime',
          },
          onChanged: (r) => setState(() => _shown = r),
        ),
        CalcBreakdownCard(
          rows: [
            CalcRow('Gross income', formatInr(shown.grossIncome)),
            CalcRow('Deductions', '− ${formatInr(shown.deductions)}'),
            CalcRow('Taxable income', formatInr(shown.taxableIncome)),
            CalcRow('Tax on slabs', formatInr(shown.slabTax)),
            if (shown.rebate.isPositive)
              CalcRow('Rebate 87A', '− ${formatInr(shown.rebate)}'),
            if (shown.surcharge.isPositive)
              CalcRow('Surcharge', formatInr(shown.surcharge)),
            CalcRow('Health & education cess (4%)', formatInr(shown.cess)),
            CalcRow('Total tax', formatInr(shown.totalTax), bold: true),
            CalcRow(
              'Per month',
              formatInr(Money.fromPaise((shown.totalTax.paise / 12).round())),
            ),
            CalcRow(
              'Effective rate',
              '${shown.effectiveRatePct.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ],
    );
  }
}

/// New and old regime totals side by side, the cheaper one highlighted.
class _RegimeCompare extends StatelessWidget {
  const _RegimeCompare({required this.newTax, required this.oldTax});

  final TaxBreakdown newTax;
  final TaxBreakdown oldTax;

  @override
  Widget build(BuildContext context) {
    final newBetter = newTax.totalTax <= oldTax.totalTax;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RegimeTile('New regime', newTax.totalTax, best: newBetter),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _RegimeTile('Old regime', oldTax.totalTax, best: !newBetter),
          ),
        ],
      ),
    );
  }
}

class _RegimeTile extends StatelessWidget {
  const _RegimeTile(this.label, this.tax, {required this.best});

  final String label;
  final Money tax;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppCard(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: best ? AppColors.income : cs.outline,
          width: best ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatInr(tax),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            if (best) ...[
              const SizedBox(height: 4),
              Text(
                'Lower tax',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.income,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
