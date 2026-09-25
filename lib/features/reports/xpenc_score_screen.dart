import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers.dart';
import 'chart_widgets.dart';
import 'stats_sections.dart';
import 'xpenc_score.dart';
import 'xpenc_score_provider.dart';

/// Where the full score breakdown lives. Pushed on the root navigator, so it
/// opens full-screen from the Stats tab as well as from More › Stats.
const kXpencScoreRoute = '/more/stats/score';

/// Green for a healthy score, amber for middling, red for trouble — the same
/// semantic money colours the rest of the app uses, so "green = good" holds.
Color scoreColor(double fraction) {
  if (fraction >= 0.65) return AppColors.income;
  if (fraction >= 0.5) return const Color(0xFFD97706);
  return AppColors.expense;
}

/// A 270° ring gauge with the score in the middle. [score] null draws an
/// empty ring with a dash — the "not enough data yet" state.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    required this.score,
    this.size = 132,
    this.strokeWidth = 12,
    this.caption,
    super.key,
  });

  final int? score;
  final double size;
  final double strokeWidth;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fraction = (score ?? 0) / 100;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _GaugePainter(
            fraction: value,
            color: scoreColor(fraction),
            track: cs.surfaceContainerHighest,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score == null ? '—' : '${(value * 100).round()}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.3,
                    height: 1,
                    fontFeatures: kTabularFigures,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption ?? 'of 100',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double strokeWidth;

  static const _sweep = 1.5 * math.pi;
  static const _start = 0.75 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        _start,
        _sweep * fraction.clamp(0.0, 1.0),
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}

/// The Stats hub's hero card: gauge, grade, and the single biggest thing to
/// improve. Taps through to [XpencScoreScreen].
class XpencScoreCard extends ConsumerWidget {
  const XpencScoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ledger = ref.watch(allTransactionsProvider);
    if (ledger.isLoading) return const StatsSectionLoader(height: 164);

    final result = ref.watch(xpencScoreProvider);
    final grade = result.grade;
    final next = result.improvements.firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(kXpencScoreRoute),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ScoreGauge(score: result.score, size: 112, strokeWidth: 10),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'XPENC SCORE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      grade?.label ?? 'Not enough data yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: result.score == null
                            ? cs.onSurface
                            : scoreColor(result.score! / 100),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.hasScore
                          ? (next == null
                                ? 'Every rule at full marks.'
                                : 'Next: improve ${next.title.toLowerCase()}')
                          : 'Add at least $kScoreMinTransactions income or '
                                'expense entries to see your score.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'See breakdown',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full breakdown: the gauge, what each rule earned and why, what to do
/// next, and the rules themselves.
class XpencScoreScreen extends ConsumerWidget {
  const XpencScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ledger = ref.watch(allTransactionsProvider);
    final result = ref.watch(xpencScoreProvider);
    final grade = result.grade;

    return Scaffold(
      appBar: AppBar(title: const Text('XPENC Score')),
      body: ledger.isLoading
          ? const StatsSectionLoader(height: 240)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Center(child: ScoreGauge(score: result.score, size: 184)),
                const SizedBox(height: 12),
                Text(
                  grade?.label ?? 'Not enough data yet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: result.score == null
                        ? cs.onSurface
                        : scoreColor(result.score! / 100),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  grade?.blurb ??
                      'Add at least $kScoreMinTransactions income or expense '
                          'entries (you have ${result.entriesInWindow} in the '
                          'last $kScoreWindowDays days) and your score appears '
                          'here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Income · 90 days',
                        value: MoneyFormat.compact(result.windowIncome),
                        color: AppColors.income,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Expense · 90 days',
                        value: MoneyFormat.compact(result.windowExpense),
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (result.hasScore && result.improvements.isNotEmpty) ...[
                  const SectionCaption('What to improve'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (final (i, p)
                              in result.improvements.take(3).indexed)
                            ListTile(
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: cs.surfaceContainerHighest,
                                child: Text(
                                  '${i + 1}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(p.tip!),
                              subtitle: Text(
                                '+${(p.weight - p.points).round()} points '
                                'available · ${p.title}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                const SectionCaption('Breakdown'),
                for (final p in result.pillars) ...[
                  _PillarCard(pillar: p),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 18),
                const SectionCaption('How it\'s calculated'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final spec in kScorePillars) ...[
                          Text(
                            '${spec.title} · ${spec.weight} pts',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            spec.rule,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'Rules with nothing to judge (no budgets, no loans) '
                          'are left out and the rest scaled to 100, so you '
                          'are never marked down for a feature you don\'t '
                          'use. Transfers between your own accounts and money '
                          'lent to or repaid by people never count as income '
                          'or expense.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Grades: 80+ Excellent · 65+ Good · 50+ Fair · '
                          '35+ Needs work · below 35 At risk.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Calculated on this device from your own records. Not a '
                  'credit score, and never shared.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.pillar});

  final ScorePillar pillar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final p = pillar;
    final color = p.applicable ? scoreColor(p.fraction) : cs.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_iconOf(p.id), size: 20, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  p.applicable
                      ? '${p.points.round()} / ${p.weight}'
                      : 'Not scored',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: p.applicable ? p.fraction : 0,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(ScorePillarId id) => switch (id) {
    ScorePillarId.savingsRate => Icons.savings_outlined,
    ScorePillarId.livingWithinMeans => Icons.balance_rounded,
    ScorePillarId.debtLoad => Icons.credit_score_outlined,
    ScorePillarId.repayment => Icons.event_available_outlined,
    ScorePillarId.emergencyFund => Icons.health_and_safety_outlined,
    ScorePillarId.budgets => Icons.pie_chart_outline_rounded,
    ScorePillarId.trackingHabit => Icons.edit_calendar_outlined,
  };
}
