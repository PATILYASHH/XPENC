import 'package:flutter/material.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/world_tax.dart';
import 'calculator_widgets.dart';

/// Countries the Income Tax calculator covers. [currencyCode] formats the
/// results and picks the default country from the app's currency setting.
enum TaxCountry {
  india('🇮🇳', 'India', 'INR'),
  us('🇺🇸', 'United States', 'USD'),
  uk('🇬🇧', 'United Kingdom', 'GBP'),
  germany('🇩🇪', 'Germany', 'EUR');

  const TaxCountry(this.flag, this.label, this.currencyCode);

  final String flag;
  final String label;
  final String currencyCode;

  Currency get currency => currencyForCode(currencyCode);

  String format(Money m) => MoneyFormat.forCurrency(m, currency);

  String get inputPrefix => '${currency.symbol} ';

  /// The country matching the app's currency, India otherwise.
  static TaxCountry forCurrency(String code) => values.firstWhere(
    (c) => c.currencyCode == code,
    orElse: () => TaxCountry.india,
  );

  String get footnote => switch (this) {
    TaxCountry.india =>
      'Based on FY 2025-26 slabs (Budget 2025). Covers normal-rate income '
          'only — capital gains, lottery and other special-rate income are '
          'taxed separately. Verify with a CA or the income-tax portal before '
          'filing.',
    TaxCountry.us =>
      'Federal tax year 2025 brackets. State and local income tax are not '
          'included. Credits (child tax credit, EITC, etc.) are not applied. '
          'Estimates only — check with a tax professional or IRS.gov.',
    TaxCountry.uk =>
      'England, Wales & Northern Ireland, 2025/26 and 2026/27 (thresholds '
          'frozen). Scotland has different income tax bands. Student loan '
          'repayments are not included. Estimates only — check GOV.UK.',
    TaxCountry.germany =>
      '2025 tariff (§32a EStG). Enter taxable income after social insurance '
          'and other deductions. Church tax (8–9%) is not included. '
          'Estimates only — check with a Steuerberater or ELSTER.',
  };
}

/// Summary tiles + line-by-line breakdown shared by every non-India country.
class TaxSummaryView extends StatelessWidget {
  const TaxSummaryView({
    required this.summary,
    required this.country,
    super.key,
  });

  final TaxSummary summary;
  final TaxCountry country;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = country.format;
    final taxes = summary.lines.where((l) => l.isTax).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalcResultCard(
          label: 'Total tax (yearly)',
          value: summary.totalTax,
          format: fmt,
          sub:
              '${summary.effectiveRatePct.toStringAsFixed(1)}% effective · '
              '${summary.marginalRatePct.toStringAsFixed(0)}% marginal',
          parts: [
            CalcPart('Take-home', summary.afterTax, cs.primary),
            for (var i = 0; i < taxes.length; i++)
              CalcPart(taxes[i].label, taxes[i].amount, _taxColors[i % 3]),
          ],
        ),
        const SizedBox(height: 12),
        CalcBreakdownCard(
          rows: [
            CalcRow('Gross income', fmt(summary.gross)),
            for (final l in summary.lines.where((l) => !l.isTax))
              CalcRow(l.label, '− ${fmt(l.amount)}'),
            CalcRow('Taxable income', fmt(summary.taxable)),
            for (final l in taxes) CalcRow(l.label, fmt(l.amount)),
            CalcRow('Total tax', fmt(summary.totalTax), bold: true),
            CalcRow('Take-home (yearly)', fmt(summary.afterTax), bold: true),
            CalcRow(
              'Take-home (monthly)',
              fmt(Money.fromPaise((summary.afterTax.paise / 12).round())),
            ),
          ],
        ),
      ],
    );
  }
}

const _taxColors = [Color(0xFFDC2626), Color(0xFFF97316), Color(0xFFD97706)];

// ── United States ───────────────────────────────────────────────────────────

class UsTaxBody extends StatefulWidget {
  const UsTaxBody({super.key});

  @override
  State<UsTaxBody> createState() => _UsTaxBodyState();
}

class _UsTaxBodyState extends State<UsTaxBody> with CalculatorFormMixin {
  var _status = UsFilingStatus.single;
  late final _wages = field('75000');
  late final _other = field('0');
  late final _preTax = field('0');
  late final _itemized = field('0');

  @override
  Widget build(BuildContext context) {
    const country = TaxCountry.us;
    final summary = UsTaxCalculator.compute(
      wages: moneyOf(_wages),
      otherIncome: moneyOf(_other),
      preTaxDeductions: moneyOf(_preTax),
      itemizedDeductions: moneyOf(_itemized),
      status: _status,
    );
    final std = UsTaxCalculator.standardDeduction(_status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CalcHeading('Filing status'),
        _Chips(
          values: UsFilingStatus.values,
          selected: _status,
          label: (s) => s.label,
          onSelected: (s) => setState(() => _status = s),
        ),
        const CalcHeading('Income (yearly)'),
        CalcField(
          controller: _wages,
          label: 'Wages / salary (W-2)',
          prefix: country.inputPrefix,
        ),
        CalcField(
          controller: _other,
          label: 'Other income',
          prefix: country.inputPrefix,
          helper: 'Interest, freelance, rental — no FICA applied',
        ),
        const CalcHeading('Deductions'),
        CalcField(
          controller: _preTax,
          label: 'Pre-tax contributions',
          prefix: country.inputPrefix,
          helper: '401(k), HSA, traditional IRA',
        ),
        CalcField(
          controller: _itemized,
          label: 'Itemized deductions (optional)',
          prefix: country.inputPrefix,
          helper:
              'Used only if above the ${country.format(Money.fromRupees(std))} '
              'standard deduction',
        ),
        const SizedBox(height: 4),
        TaxSummaryView(summary: summary, country: country),
      ],
    );
  }
}

// ── United Kingdom ──────────────────────────────────────────────────────────

class UkTaxBody extends StatefulWidget {
  const UkTaxBody({super.key});

  @override
  State<UkTaxBody> createState() => _UkTaxBodyState();
}

class _UkTaxBodyState extends State<UkTaxBody> with CalculatorFormMixin {
  late final _salary = field('45000');
  late final _other = field('0');
  late final _pension = field('0');

  @override
  Widget build(BuildContext context) {
    const country = TaxCountry.uk;
    final summary = UkTaxCalculator.compute(
      salary: moneyOf(_salary),
      otherIncome: moneyOf(_other),
      pensionSacrifice: moneyOf(_pension),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CalcHeading('Income (yearly)'),
        CalcField(
          controller: _salary,
          label: 'Salary (PAYE)',
          prefix: country.inputPrefix,
        ),
        CalcField(
          controller: _other,
          label: 'Other taxable income',
          prefix: country.inputPrefix,
          helper: 'Rent, savings interest over allowance — no NI applied',
        ),
        CalcField(
          controller: _pension,
          label: 'Pension via salary sacrifice',
          prefix: country.inputPrefix,
          helper: 'Reduces both income tax and National Insurance',
        ),
        const SizedBox(height: 4),
        TaxSummaryView(summary: summary, country: country),
      ],
    );
  }
}

// ── Germany ─────────────────────────────────────────────────────────────────

class GermanyTaxBody extends StatefulWidget {
  const GermanyTaxBody({super.key});

  @override
  State<GermanyTaxBody> createState() => _GermanyTaxBodyState();
}

class _GermanyTaxBodyState extends State<GermanyTaxBody>
    with CalculatorFormMixin {
  var _married = false;
  late final _taxable = field('50000');

  @override
  Widget build(BuildContext context) {
    const country = TaxCountry.germany;
    final summary = GermanyTaxCalculator.compute(
      taxableIncome: moneyOf(_taxable),
      married: _married,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CalcHeading('Filing'),
        _Chips(
          values: const [false, true],
          selected: _married,
          label: (m) => m ? 'Married, joint (splitting)' : 'Single',
          onSelected: (m) => setState(() => _married = m),
        ),
        const CalcHeading('Income (yearly)'),
        CalcField(
          controller: _taxable,
          label: 'Taxable income (zvE)',
          prefix: country.inputPrefix,
          helper: _married
              ? 'Combined for both spouses'
              : 'After social insurance, Werbungskosten, etc.',
        ),
        const SizedBox(height: 4),
        TaxSummaryView(summary: summary, country: country),
      ],
    );
  }
}

class _Chips<T> extends StatelessWidget {
  const _Chips({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onSelected(v),
          ),
      ],
    ),
  );
}
