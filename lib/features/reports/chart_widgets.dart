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

/// Donut of category slices. Sorted descending; anything past the top five
/// is folded into a single grey "Other" slice. No labels sit on the chart by
/// default — tap or hover a wedge to see its name and amount in the donut's
/// hollow centre; [showLegend] additionally puts a legend below (Stats and
/// Account Reports want that at-a-glance list; the Dashboard's compact card
/// doesn't).
class CategoryPieChart extends StatefulWidget {
  const CategoryPieChart({
    required this.slices,
    this.showLegend = true,
    this.onSliceTap,
    super.key,
  });

  /// [id] is whatever the caller wants back via [onSliceTap] — e.g. a
  /// category id to drill into. Null for a slice nothing should navigate to
  /// (the synthetic "Other" tail always gets null; a non-category chart like
  /// the accounts-balance one can leave every slice's id null).
  final List<({String label, Money value, Color color, int? id})> slices;
  final bool showLegend;

  /// Tapping a legend chip whose slice carries a non-null id calls this with
  /// that id. Left null (the default) makes the legend non-interactive.
  final ValueChanged<int>? onSliceTap;

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final positive = widget.slices.where((s) => s.value.isPositive).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (positive.isEmpty) return const _NoData(height: 220);

    final data = <({String label, Money value, Color color, int? id})>[];
    if (positive.length > 6) {
      data.addAll(positive.take(5));
      var rest = const Money.zero();
      for (final s in positive.skip(5)) {
        rest += s.value;
      }
      data.add((label: 'Other', value: rest, color: Colors.grey, id: null));
    } else {
      data.addAll(positive);
    }
    final total = data.fold<int>(0, (sum, d) => sum + d.value.paise);

    final touched = _touchedIndex >= 0 && _touchedIndex < data.length
        ? data[_touchedIndex]
        : null;

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
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 46,
                      sectionsSpace: 2,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          final index =
                              response?.touchedSection?.touchedSectionIndex ??
                              -1;
                          if (index == _touchedIndex) return;
                          setState(() => _touchedIndex = index);
                        },
                      ),
                      sections: [
                        for (var i = 0; i < data.length; i++)
                          PieChartSectionData(
                            value: data[i].value.paise / 100,
                            color: data[i].color,
                            radius: i == _touchedIndex ? 68 : 60,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                if (touched != null)
                  IgnorePointer(child: _CenterLabel(slice: touched)),
              ],
            ),
          ),
          if (widget.showLegend) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final s in data)
                  _LegendChip(
                    slice: s,
                    percentOfTotal: total == 0 ? null : s.value.paise / total * 100,
                    onTap: (widget.onSliceTap == null || s.id == null)
                        ? null
                        : () => widget.onSliceTap!(s.id!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The touched/hovered wedge's name and amount, centred in the donut hole.
class _CenterLabel extends StatelessWidget {
  const _CenterLabel({required this.slice});

  final ({String label, Money value, Color color, int? id}) slice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 84,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            MoneyFormat.compact(slice.value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.slice, this.percentOfTotal, this.onTap});

  final ({String label, Money value, Color color, int? id}) slice;
  final double? percentOfTotal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueLine = percentOfTotal == null
        ? MoneyFormat.compact(slice.value)
        : '${MoneyFormat.compact(slice.value)} (${percentOfTotal!.round()}%)';

    final chip = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
          // Label and value stack in one Flexible so a long percentage-
          // annotated value wraps to a second line instead of overflowing
          // the chip's width, the way it would fighting for space as a
          // sibling of the label in a single Row.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  valueLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: chip);
  }
}

/// Sectors sized by *budget* share (bigger allocation → bigger wedge), each
/// filled from its centre out by however much of that budget is spent —
/// filled radius is `outerRadius * sqrt(fraction)`, so the *area* coloured in
/// (not just the radius) matches the spent/budget ratio. The rest of the
/// wedge stays a faint tint of the same colour rather than blank or black, so
/// an unspent budget still reads as "this category's slice" at a glance. A
/// category over its cap gets a red ring plus a diagonal hazard-stripe
/// overlay on its fill — its fill is capped at 100%, so those are the only
/// way to see it went over. Sorted by budget size; past the top five, the
/// tail folds into a grey "Other" slice. No labels sit on the chart by
/// default — tap or hover a wedge to see its name and spent/budget in the
/// centre.
class BudgetRadialChart extends StatefulWidget {
  const BudgetRadialChart({required this.slices, super.key});

  /// [fundingColor], when set (GitHub #100 v2, only while Ready to Assign is
  /// on), overrides [color] for this slice's fill — green/amber for
  /// funded/underfunded. The overspent hazard-stripe + red ring stays
  /// keyed off [spent]/[budget] regardless, so it still overlays either way.
  final List<
    ({String label, Money budget, Money spent, Color color, Color? fundingColor})
  >
  slices;

  @override
  State<BudgetRadialChart> createState() => _BudgetRadialChartState();
}

class _BudgetRadialChartState extends State<BudgetRadialChart> {
  static const _chartSize = Size(220, 220);

  int _touchedIndex = -1;

  void _updateTouch(Offset local, List<_BudgetSlice> data, int total) {
    final center = _chartSize.center(Offset.zero);
    final outerRadius = math.min(_chartSize.width, _chartSize.height) / 2 - 2;
    final delta = local - center;

    if (total <= 0 || delta.distance > outerRadius) {
      if (_touchedIndex != -1) setState(() => _touchedIndex = -1);
      return;
    }

    // Same angle math as the painter, but against the un-gapped share —
    // the gap between wedges is too thin to matter for hit-testing.
    var rel = math.atan2(delta.dy, delta.dx) - -math.pi / 2;
    if (rel < 0) rel += 2 * math.pi;

    var angle = 0.0;
    for (var i = 0; i < data.length; i++) {
      final share = data[i].budget.paise / total * 2 * math.pi;
      if (rel < angle + share) {
        if (_touchedIndex != i) setState(() => _touchedIndex = i);
        return;
      }
      angle += share;
    }
  }

  @override
  Widget build(BuildContext context) {
    final positive = widget.slices.where((s) => s.budget.isPositive).toList()
      ..sort((a, b) => b.budget.compareTo(a.budget));

    if (positive.isEmpty) return const _NoData(height: 220);

    final data = <_BudgetSlice>[];
    if (positive.length > 6) {
      for (final s in positive.take(5)) {
        data.add(
          _BudgetSlice(s.label, s.budget, s.spent, s.color, s.fundingColor),
        );
      }
      var restBudget = const Money.zero();
      var restSpent = const Money.zero();
      for (final s in positive.skip(5)) {
        restBudget += s.budget;
        restSpent += s.spent;
      }
      // Folded into "Other": a single funding color can't represent several
      // categories at once, so this tail always falls back to its own grey.
      data.add(_BudgetSlice('Other', restBudget, restSpent, Colors.grey));
    } else {
      for (final s in positive) {
        data.add(
          _BudgetSlice(s.label, s.budget, s.spent, s.color, s.fundingColor),
        );
      }
    }

    final total = data.fold<int>(0, (sum, s) => sum + s.budget.paise);
    final touched = _touchedIndex >= 0 && _touchedIndex < data.length
        ? data[_touchedIndex]
        : null;

    // Column alone shrink-wraps to its widest child — here, just a 220px
    // circle, which (unlike a Row of Expanded tiles elsewhere on the
    // dashboard) never has to claim the full card width. Left unforced, the
    // whole card ends up narrower than every card around it and drifts to
    // the left edge of the section instead of sitting centred in it. The
    // infinite-width SizedBox forces the card back to the section's width,
    // so Column's own default centring actually has something to centre in.
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: MouseRegion(
          onHover: (event) => _updateTouch(event.localPosition, data, total),
          onExit: (_) {
            if (_touchedIndex != -1) setState(() => _touchedIndex = -1);
          },
          child: GestureDetector(
            onTapUp: (details) =>
                _updateTouch(details.localPosition, data, total),
            child: SizedBox(
              key: const Key('budgetRadialPaintArea'),
              height: _chartSize.height,
              width: _chartSize.width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _BudgetSectorPainter(data)),
                  ),
                  if (touched != null)
                    IgnorePointer(child: _BudgetCenterLabel(slice: touched)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetSlice {
  const _BudgetSlice(
    this.label,
    this.budget,
    this.spent,
    this.color, [
    this.fundingColor,
  ]);

  final String label;
  final Money budget;
  final Money spent;
  final Color color;
  final Color? fundingColor;

  /// The color actually painted for the wedge fill — [fundingColor] when
  /// set, else the category's own [color].
  Color get fillColor => fundingColor ?? color;

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

  /// Spacing between hazard-stripe lines on an overspent wedge, in pixels.
  static const _hatchSpacing = 9.0;

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
      final wedge = _wedge(center, outerRect, start, sweep);

      canvas.drawPath(
        wedge,
        Paint()..color = slice.fillColor.withValues(alpha: 0.16),
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
          Paint()..color = slice.fillColor,
        );
      }

      if (slice.overspent) {
        // Hazard stripes over the (fully-filled, since fraction is capped
        // at 1.0) wedge — the ring alone reads as decoration at a glance;
        // a texture change is harder to miss.
        canvas.save();
        canvas.clipPath(wedge);
        final hatchPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.24)
          ..strokeWidth = 2.4;
        final diag = outerRect.width + outerRect.height;
        for (var d = -diag; d < diag; d += _hatchSpacing) {
          canvas.drawLine(
            Offset(outerRect.left + d, outerRect.top),
            Offset(outerRect.left + d + outerRect.height, outerRect.bottom),
            hatchPaint,
          );
        }
        canvas.restore();

        canvas.drawArc(
          outerRect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
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

/// The touched/hovered wedge's name and spent/budget, centred on the chart.
/// Unlike [CategoryPieChart]'s donut, this pie has no hollow centre, so a
/// translucent circular backdrop keeps the text legible over the wedges
/// behind it.
class _BudgetCenterLabel extends StatelessWidget {
  const _BudgetCenterLabel({required this.slice});

  final _BudgetSlice slice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 108,
      height: 108,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${MoneyFormat.compact(slice.spent)}'
            ' / ${MoneyFormat.compact(slice.budget)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: slice.overspent
                  ? AppColors.expense
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontFeatures: kTabularFigures,
            ),
          ),
          if (slice.overspent) ...[
            const SizedBox(height: 2),
            Text(
              'Over budget',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
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
