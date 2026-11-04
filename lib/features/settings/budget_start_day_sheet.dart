import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget_cycle.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';

/// Picks which day of the month Dashboard/Budgets/Stats treat as the start
/// of a "month" — 1 for an ordinary calendar month, or a payday-anchored
/// cycle otherwise (e.g. someone paid on the 15th wants their spending
/// period to run 15th-to-14th, not reset on the 1st). Any day up to the
/// 31st, or the last working day for a salary paid on it (GitHub #182).
class BudgetStartDaySheet extends ConsumerWidget {
  const BudgetStartDaySheet({super.key});

  static Future<void> show(BuildContext context) => showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const BudgetStartDaySheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = ref.watch(budgetStartDayProvider);
    Future<void> pick(int day) async {
      await ref.read(dbProvider).setBudgetStartDay(day);
      if (context.mounted) Navigator.of(context).pop();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Budget cycle start day',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dashboard, Budgets and Stats will treat this day as the start '
            'of a "month" — pick the 1st for an ordinary calendar month, or '
            'e.g. your payday if you\'d rather track spending payday-to-'
            'payday. A month without the 29th, 30th or 31st starts on its '
            'last day.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var day = 1; day <= 31; day++)
                _DayChip(
                  day: day,
                  selected: day == selected,
                  onTap: () => pick(day),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // A salary on the last weekday moves about — the 31st one month,
          // the 28th the next — so it's a rule, not a day.
          _LastWorkingDayOption(
            selected: selected == kLastWorkingDay,
            onTap: () => pick(kLastWorkingDay),
          ),
        ],
      ),
    );
  }
}

class _LastWorkingDayOption extends StatelessWidget {
  const _LastWorkingDayOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              AppIcon(Icons.work_outline_rounded, size: 20, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last working day',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'The last Monday to Friday of each month',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? cs.onPrimary.withValues(alpha: 0.85)
                            : cs.onSurfaceVariant,
                      ),
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: Text(
            '$day',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
