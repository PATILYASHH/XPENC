import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/loan_amortization.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers.dart';

// fl_chart speaks in doubles — `paise / 100` is fine here only, same rule as
// reports/chart_widgets.dart: these values are drawn, never stored.

typedef _Row = ({int index, Money interest, Money principal, Money balance});

/// "How interest shapes this loan" — a principal-vs-interest breakdown, the
/// remaining balance month by month or the principal/interest split year by
/// year, and a prepayment simulator. Only shown for a loan with a rate and an
/// EMI that's still owing; every figure comes from [LoanAmortization] so it
/// can't disagree with the numbers on the loan detail card.
class LoanInsightsSection extends StatefulWidget {
  const LoanInsightsSection({required this.loan, super.key});

  final LoanProgress loan;

  /// Whether [loan] has enough to project from — callers skip the section
  /// entirely otherwise.
  static bool canShow(LoanProgress loan) =>
      loan.detail.interestRatePct != null &&
      loan.emi != null &&
      loan.outstanding.isPositive;

  @override
  State<LoanInsightsSection> createState() => _LoanInsightsSectionState();
}

enum _ChartView { monthly, yearly }

class _LoanInsightsSectionState extends State<LoanInsightsSection> {
  _ChartView _view = _ChartView.monthly;

  /// Slider position for the simulator, in whole rupees per month.
  double _extraRupees = 0;

  double get _rate => widget.loan.detail.interestRatePct!;
  Money get _emi => widget.loan.emi!;

  List<_Row> _schedule(Money extra) => LoanAmortization.schedule(
    startingBalance: widget.loan.outstanding,
    annualRatePct: _rate,
    emi: _emi,
    extraPerMonth: extra,
  );

  static Money _sumInterest(List<_Row> rows) =>
      rows.fold(const Money.zero(), (sum, r) => sum + r.interest);

  /// Installment [i] (0-based) of a schedule starting from today lands in
  /// the month after this one — an approximation good enough for a chart
  /// label; the real dates live on the Auto rule.
  static DateTime _monthOf(int i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1 + i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = _schedule(const Money.zero());
    if (base.isEmpty) {
      return _card(
        theme,
        child: Text(
          "The EMI doesn't cover this month's interest, so the balance would "
          'never go down. Check the EMI and rate.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.expense),
        ),
      );
    }
    final extra = Money.fromRupees(_extraRupees.round());
    final simulated = extra.isPositive ? _schedule(extra) : base;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _breakdownCard(theme),
        const SizedBox(height: 12),
        _chartCard(theme, base, extra.isPositive ? simulated : null),
        const SizedBox(height: 12),
        _simulatorCard(theme, base, simulated, extra),
      ],
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  Widget _label(ThemeData theme, String text) => Text(
    text.toUpperCase(),
    style: theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );

  // ── Principal vs interest over the whole loan ─────────────────────────────

  Widget _breakdownCard(ThemeData theme) {
    final loan = widget.loan;
    final principal = loan.principal;
    final interest =
        loan.totalInterestScheduled ??
        _sumInterest(
          LoanAmortization.schedule(
            startingBalance: principal,
            annualRatePct: _rate,
            emi: _emi,
          ),
        );
    final total = principal + interest;
    final principalShare = total.isZero ? 1.0 : principal.paise / total.paise;
    final extraPct = principal.isZero
        ? 0
        : (interest.paise * 100 / principal.paise).round();
    final loanColor = Color(loan.account.colorValue);

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(theme, 'What this loan really costs'),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Interest adds '),
                TextSpan(
                  text: '$extraPct%',
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' on top of what you borrowed.'),
              ],
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: (principalShare * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: loanColor),
                  ),
                  Expanded(
                    flex: ((1 - principalShare) * 1000).round().clamp(1, 1000),
                    child: const ColoredBox(color: AppColors.expense),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _legendLine(theme, loanColor, 'Borrowed', principal),
          const SizedBox(height: 6),
          _legendLine(theme, AppColors.expense, 'Interest', interest),
          const SizedBox(height: 6),
          _legendLine(theme, null, 'Total you repay', total, bold: true),
        ],
      ),
    );
  }

  Widget _legendLine(
    ThemeData theme,
    Color? color,
    String label,
    Money value, {
    bool bold = false,
  }) {
    return Row(
      children: [
        if (color != null)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          )
        else
          const SizedBox(width: 10),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          MoneyFormat.symbol(value),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Month-wise balance / year-wise split ──────────────────────────────────

  Widget _chartCard(ThemeData theme, List<_Row> base, List<_Row>? simulated) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _label(
                  theme,
                  _view == _ChartView.monthly
                      ? 'Balance left, month by month'
                      : 'Each year: principal vs interest',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<_ChartView>(
            segments: const [
              ButtonSegment(value: _ChartView.monthly, label: Text('Monthly')),
              ButtonSegment(value: _ChartView.yearly, label: Text('Yearly')),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 16),
          if (_view == _ChartView.monthly)
            _BalanceLineChart(
              base: base,
              simulated: simulated,
              color: Color(widget.loan.account.colorValue),
              monthOf: _monthOf,
            )
          else
            _YearlySplitChart(
              years: _byYear(simulated ?? base),
              principalColor: Color(widget.loan.account.colorValue),
            ),
          if (_view == _ChartView.monthly && simulated != null) ...[
            const SizedBox(height: 8),
            Text(
              'Dashed: with the extra payment from the simulator below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_view == _ChartView.yearly) ...[
            const SizedBox(height: 8),
            Text(
              'Early years are mostly interest; the principal share grows '
              'as the balance shrinks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<({int year, Money principal, Money interest})> _byYear(
    List<_Row> rows,
  ) {
    final byYear = <int, ({Money principal, Money interest})>{};
    for (final r in rows) {
      final year = _monthOf(r.index).year;
      final prev =
          byYear[year] ??
          (principal: const Money.zero(), interest: const Money.zero());
      byYear[year] = (
        principal: prev.principal + r.principal,
        interest: prev.interest + r.interest,
      );
    }
    final years = byYear.keys.toList()..sort();
    return [
      for (final y in years)
        (
          year: y,
          principal: byYear[y]!.principal,
          interest: byYear[y]!.interest,
        ),
    ];
  }

  // ── Prepayment simulator ──────────────────────────────────────────────────

  Widget _simulatorCard(
    ThemeData theme,
    List<_Row> base,
    List<_Row> simulated,
    Money extra,
  ) {
    final cs = theme.colorScheme;
    // Up to one extra EMI a month, in steps that stay usable on a slider.
    final maxExtra = (_emi.paise / 100).clamp(100, double.infinity).toDouble();
    final step = maxExtra >= 20000 ? 1000.0 : (maxExtra >= 2000 ? 100.0 : 10.0);
    final divisions = (maxExtra / step).floor().clamp(1, 200);
    final sliderMax = divisions * step;

    final baseInterest = _sumInterest(base);
    final simInterest = _sumInterest(simulated);
    final saved = baseInterest - simInterest;
    final monthsSooner = base.length - simulated.length;
    final df = DateFormat('MMM yyyy');

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(theme, 'What if I pay extra?'),
          const SizedBox(height: 10),
          Text(
            extra.isPositive
                ? '+${MoneyFormat.symbol(extra)} every month'
                : 'Slide to add a monthly prepayment',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Slider(
            value: _extraRupees.clamp(0, sliderMax),
            min: 0,
            max: sliderMax,
            divisions: divisions,
            label: MoneyFormat.symbol(extra),
            onChanged: (v) => setState(() => _extraRupees = v),
          ),
          _simRow(
            theme,
            'Debt-free by',
            extra.isPositive
                ? '${df.format(_monthOf(simulated.length - 1))} '
                      '(was ${df.format(_monthOf(base.length - 1))})'
                : df.format(_monthOf(base.length - 1)),
          ),
          _simRow(
            theme,
            'Interest left to pay',
            MoneyFormat.symbol(simInterest),
          ),
          if (extra.isPositive) ...[
            _simRow(
              theme,
              'Interest saved',
              MoneyFormat.symbol(saved),
              color: AppColors.income,
            ),
            _simRow(
              theme,
              'Finish sooner by',
              _formatMonths(monthsSooner),
              color: AppColors.income,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Assumes the rate stays the same and the bank reduces tenure '
            '(not EMI) on prepayment.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _simRow(ThemeData theme, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMonths(int months) {
    final y = months ~/ 12;
    final m = months % 12;
    final parts = [
      if (y > 0) '$y yr${y == 1 ? '' : 's'}',
      if (m > 0 || y == 0) '$m mo',
    ];
    return parts.join(' ');
  }
}

/// Remaining balance after each installment — [base] solid, [simulated]
/// (the prepayment scenario, when there is one) dashed.
class _BalanceLineChart extends StatelessWidget {
  const _BalanceLineChart({
    required this.base,
    required this.simulated,
    required this.color,
    required this.monthOf,
  });

  final List<_Row> base;
  final List<_Row>? simulated;
  final Color color;
  final DateTime Function(int index) monthOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxY =
        base.first.balance.paise / 100 + base.first.principal.paise / 100;
    final lastX = (base.length - 1).toDouble();
    // About five bottom labels whatever the tenure.
    final labelEvery = (base.length / 5).ceil().clamp(1, 1200);

    List<FlSpot> spots(List<_Row> rows) => [
      for (final r in rows) FlSpot(r.index.toDouble(), r.balance.paise / 100),
    ];

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastX <= 0 ? 1 : lastX,
          minY: 0,
          maxY: maxY <= 0 ? 1 : maxY * 1.05,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (value != i ||
                      i < 0 ||
                      i >= base.length ||
                      i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat("MMM ''yy").format(monthOf(i)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.barIndex == 0 ? '' : 'With extra · '}'
                    '${DateFormat('MMM yyyy').format(monthOf(s.x.round()))}\n'
                    '${MoneyFormat.compact(Money.fromRupees(s.y))} left',
                    theme.textTheme.labelMedium?.copyWith(
                          color: cs.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ) ??
                        const TextStyle(),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots(base),
              isCurved: false,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            if (simulated != null)
              LineChartBarData(
                spots: spots(simulated!),
                isCurved: false,
                color: AppColors.income,
                barWidth: 2.5,
                dashArray: const [6, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}

/// One stacked bar per calendar year: principal (the loan's colour) under
/// interest (red).
class _YearlySplitChart extends StatelessWidget {
  const _YearlySplitChart({required this.years, required this.principalColor});

  final List<({int year, Money principal, Money interest})> years;
  final Color principalColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    var maxVal = 0.0;
    for (final y in years) {
      final total = (y.principal.paise + y.interest.paise) / 100;
      if (total > maxVal) maxVal = total;
    }
    final barWidth = years.length > 12 ? 8.0 : (years.length > 6 ? 12.0 : 18.0);
    final labelEvery = (years.length / 6).ceil().clamp(1, 100);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxVal <= 0 ? 1 : maxVal * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= years.length || i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      "'${years[i].year % 100}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => cs.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (group.x < 0 || group.x >= years.length) return null;
                final y = years[group.x];
                return BarTooltipItem(
                  '${y.year}\n',
                  theme.textTheme.labelMedium?.copyWith(
                        color: cs.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ) ??
                      const TextStyle(),
                  children: [
                    TextSpan(
                      text: 'Principal ${MoneyFormat.compact(y.principal)}\n',
                      style: TextStyle(
                        color: cs.onInverseSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: 'Interest ${MoneyFormat.compact(y.interest)}',
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < years.length; i++)
              () {
                final p = years[i].principal.paise / 100;
                final interest = years[i].interest.paise / 100;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: p + interest,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      rodStackItems: [
                        BarChartRodStackItem(0, p, principalColor),
                        BarChartRodStackItem(
                          p,
                          p + interest,
                          AppColors.expense,
                        ),
                      ],
                    ),
                  ],
                );
              }(),
          ],
        ),
      ),
    );
  }
}
