import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The single charting layer. Stats and Account Reports both build on these —
// no chart is drawn twice. Every widget is safe with empty data (renders a
// muted "No data yet" instead of throwing) and never overflows.
//
// fl_chart speaks in doubles because pixels are doubles. Converting a [Money]
// to a double with `m.paise / 100` is fine *here only* — these values are never
// written back to the database.
// ─────────────────────────────────────────────────────────────────────────────

/// Muted placeholder for a chart that has nothing to show yet.
class _NoData extends StatelessWidget {
  const _NoData({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          'No data yet',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Donut of category slices with a legend below. Sorted descending; anything
/// past the top five is folded into a single grey "Other" slice so the legend
/// stays readable.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({required this.slices, super.key});

  final List<({String label, Money value, Color color})> slices;

  @override
  Widget build(BuildContext context) {
    final positive = slices.where((s) => s.value.isPositive).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (positive.isEmpty) return const _NoData(height: 220);

    final data = <({String label, Money value, Color color})>[];
    if (positive.length > 6) {
      data.addAll(positive.take(5));
      var rest = const Money.zero();
      for (final s in positive.skip(5)) {
        rest += s.value;
      }
      data.add((label: 'Other', value: rest, color: Colors.grey));
    } else {
      data.addAll(positive);
    }

    // See the matching note on BudgetRadialChart: without an explicit full
    // width, this Column shrink-wraps to its widest child instead of the
    // card's own width, and drifts left instead of sitting centred in it.
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 46,
                sectionsSpace: 2,
                sections: [
                  for (final s in data)
                    PieChartSectionData(
                      value: s.value.paise / 100,
                      color: s.color,
                      radius: 60,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [for (final s in data) _LegendChip(slice: s)],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.slice});

  final ({String label, Money value, Color color}) slice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            MoneyFormat.compact(slice.value),
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sectors sized by *budget* share (bigger allocation → bigger wedge), each
/// filled from its centre out by however much of that budget is spent —
/// filled radius is `outerRadius * sqrt(fraction)`, so the *area* coloured in
/// (not just the radius) matches the spent/budget ratio. The rest of the
/// wedge stays a faint tint of the same colour rather than blank or black, so
/// an unspent budget still reads as "this category's slice" at a glance. A
/// category over its cap gets a thin red ring — its fill is capped at 100%,
/// so the ring is the only way to see it went over. Sorted by budget size;
/// past the top five, the tail folds into a grey "Other" slice.
class BudgetRadialChart extends StatelessWidget {
  const BudgetRadialChart({required this.slices, super.key});

  final List<({String label, Money budget, Money spent, Color color})> slices;

  @override
  Widget build(BuildContext context) {
    final positive = slices.where((s) => s.budget.isPositive).toList()
      ..sort((a, b) => b.budget.compareTo(a.budget));

    if (positive.isEmpty) return const _NoData(height: 220);

    final data = <_BudgetSlice>[];
    if (positive.length > 6) {
      for (final s in positive.take(5)) {
        data.add(_BudgetSlice(s.label, s.budget, s.spent, s.color));
      }
      var restBudget = const Money.zero();
      var restSpent = const Money.zero();
      for (final s in positive.skip(5)) {
        restBudget += s.budget;
        restSpent += s.spent;
      }
      data.add(_BudgetSlice('Other', restBudget, restSpent, Colors.grey));
    } else {
      for (final s in positive) {
        data.add(_BudgetSlice(s.label, s.budget, s.spent, s.color));
      }
    }

    // Column alone shrink-wraps to its widest child — here, a 220px circle
    // and a legend that (unlike a Row of Expanded tiles elsewhere on the
    // dashboard) never has to claim the full card width. Left unforced, the
    // whole card ends up narrower than every card around it and drifts to
    // the left edge of the section instead of sitting centred in it. The
    // infinite-width SizedBox forces the card back to the section's width,
    // so Column's own default centring actually has something to centre in.
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: const Key('budgetRadialPaintArea'),
            height: 220,
            width: 220,
            child: CustomPaint(painter: _BudgetSectorPainter(data)),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              for (var i = 0; i < data.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                _BudgetLegendRow(slice: data[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetSlice {
  const _BudgetSlice(this.label, this.budget, this.spent, this.color);

  final String label;
  final Money budget;
  final Money spent;
  final Color color;

  bool get overspent => spent > budget;

  double get fraction =>
      budget.isPositive ? (spent.paise / budget.paise).clamp(0.0, 1.0) : 0.0;
}

class _BudgetSectorPainter extends CustomPainter {
  _BudgetSectorPainter(this.slices);

  final List<_BudgetSlice> slices;

  /// Angular gap between wedges, in radians — skipped on a wedge too thin to
  /// spare it, so a small budget doesn't vanish under its own gap.
  static const _gap = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.budget.paise);
    if (total <= 0) return;

    final center = size.center(Offset.zero);
    final outerRadius = math.min(size.width, size.height) / 2 - 2;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);

    var angle = -math.pi / 2;
    for (final slice in slices) {
      final share = slice.budget.paise / total * 2 * math.pi;
      final gap = share > _gap * 3 ? _gap : 0.0;
      final start = angle + gap / 2;
      final sweep = share - gap;

      canvas.drawPath(
        _wedge(center, outerRect, start, sweep),
        Paint()..color = slice.color.withValues(alpha: 0.16),
      );

      if (slice.fraction > 0) {
        final filledRadius = outerRadius * math.sqrt(slice.fraction);
        canvas.drawPath(
          _wedge(
            center,
            Rect.fromCircle(center: center, radius: filledRadius),
            start,
            sweep,
          ),
          Paint()..color = slice.color,
        );
      }

      if (slice.overspent) {
        canvas.drawArc(
          outerRect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = AppColors.expense,
        );
      }

      angle += share;
    }
  }

  Path _wedge(Offset center, Rect rect, double start, double sweep) => Path()
    ..moveTo(center.dx, center.dy)
    ..arcTo(rect, start, sweep, false)
    ..close();

  @override
  bool shouldRepaint(_BudgetSectorPainter old) => !identical(old.slices, slices);
}

/// One line per category: a colour dot naming it back to its wedge, the
/// name, and `spent / budget` in tabular figures — a real list, not a
/// wrapping cloud of chips, so the eye can scan straight down the amounts.
class _BudgetLegendRow extends StatelessWidget {
  const _BudgetLegendRow({required this.slice});

  final _BudgetSlice slice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${MoneyFormat.compact(slice.spent)}'
          ' / ${MoneyFormat.compact(slice.budget)}'
          '${slice.overspent ? ' · over' : ''}',
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: slice.overspent
                ? AppColors.expense
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontFeatures: kTabularFigures,
          ),
        ),
      ],
    );
  }
}

/// Two bars per month — income (green) and expense (red). Left axis is hidden
/// (too noisy); touch a group for a compact tooltip carrying both values.
class IncomeExpenseBarChart extends StatelessWidget {
  const IncomeExpenseBarChart({required this.months, super.key});

  final List<({DateTime month, Money income, Money expense})> months;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const _NoData(height: 240);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    var maxVal = 0.0;
    for (final m in months) {
      final inc = m.income.paise / 100;
      final exp = m.expense.paise / 100;
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }
    final maxY = maxVal <= 0 ? 1.0 : maxVal * 1.18;

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: maxY,
          alignment: BarChartAlignment.spaceEvenly,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (value != i || i < 0 || i >= months.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat('MMM').format(months[i].month),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
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
                if (group.x < 0 || group.x >= months.length) return null;
                final m = months[group.x];
                return BarTooltipItem(
                  '${DateFormat('MMM yyyy').format(m.month)}\n',
                  theme.textTheme.labelMedium?.copyWith(
                        color: cs.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ) ??
                      const TextStyle(),
                  children: [
                    TextSpan(
                      text: 'In  ${MoneyFormat.compact(m.income)}\n',
                      style: const TextStyle(
                        color: AppColors.income,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: 'Out ${MoneyFormat.compact(m.expense)}',
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
            for (var i = 0; i < months.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                    toY: months[i].income.paise / 100,
                    color: AppColors.income,
                    width: 8,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: months[i].expense.paise / 100,
                    color: AppColors.expense,
                    width: 8,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Single smooth net-worth line with a gradient fill. Net worth can go
/// negative, so minY is never clamped to zero — it is derived from the data.
class NetWorthLineChart extends StatelessWidget {
  const NetWorthLineChart({required this.points, super.key});

  final List<({DateTime month, Money value})> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const _NoData(height: 220);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    var minV = points.first.value.paise / 100;
    var maxV = minV;
    for (final p in points) {
      final v = p.value.paise / 100;
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final span = maxV - minV;
    // Never let minY == maxY — a flat line still needs a drawable band.
    final pad = span == 0 ? (maxV.abs() * 0.1 + 1) : span * 0.1;
    final minY = minV - pad;
    final maxY = maxV + pad;

    // At most six bottom labels: skip intermediate months on longer series.
    final labelEvery = (points.length / 6).ceil();
    final lastX = (points.length - 1).toDouble();

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastX,
          minY: minY,
          maxY: maxY,
          lineTouchData: const LineTouchData(enabled: false),
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
                      i >= points.length ||
                      i % labelEvery != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      DateFormat('MMM').format(points[i].month),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value.paise / 100),
              ],
              isCurved: true,
              curveSmoothness: 0.3,
              color: cs.secondary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.secondary.withValues(alpha: 0.30),
                    cs.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact metric card: an uppercase label, a big value that scales down to
/// fit, and an optional muted sub-line.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.sub,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color ?? cs.onSurface,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
