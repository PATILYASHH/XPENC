import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/budget_cycle.dart';

/// Opens the month picker and returns the chosen period anchor (day 1 of its
/// month, same shape `selectedMonthProvider` stores), or null if dismissed.
/// [current] is the anchor of the period containing today — months after it
/// can't be picked, since there's nothing recorded there yet to look back at.
Future<DateTime?> showMonthPickerSheet(
  BuildContext context, {
  required DateTime selected,
  required DateTime current,
  required int startDay,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    // Sized to its content rather than capped at half the screen — the
    // grid otherwise overflows in landscape or at a large font scale.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => MonthPickerSheet(
      selected: selected,
      current: current,
      startDay: startDay,
    ),
  );
}

/// A year header with ‹ › and a 4×3 grid of months, coloured from the
/// active theme — the Dashboard's one way to move between months (it
/// replaced the ‹ › arrows that used to sit on the This Month card).
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    required this.selected,
    required this.current,
    required this.startDay,
    super.key,
  });

  final DateTime selected;
  final DateTime current;
  final int startDay;

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _year = widget.selected.year;

  bool _isFuture(DateTime month) => month.isAfter(widget.current);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canGoForward = _year < widget.current.year;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous year',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _year--),
              ),
              Expanded(
                child: Text(
                  '$_year',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next year',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: canGoForward ? () => setState(() => _year++) : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              for (var m = 1; m <= 12; m++)
                _monthCell(theme, DateTime(_year, m)),
            ],
          ),
          if (widget.startDay != 1) ...[
            const SizedBox(height: 12),
            Text(
              'Each month runs from the ${ordinalDay(widget.startDay)} '
              '(your budget cycle).',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.selected == widget.current
                ? null
                : () => Navigator.of(context).pop(widget.current),
            icon: const Icon(Icons.today_rounded),
            label: const Text('This month'),
          ),
        ],
      ),
    );
  }

  Widget _monthCell(ThemeData theme, DateTime month) {
    final cs = theme.colorScheme;
    final isSelected = month == widget.selected;
    final isCurrent = month == widget.current;
    final disabled = _isFuture(month);

    return Material(
      color: isSelected ? cs.primary : cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent && !isSelected
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : () => Navigator.of(context).pop(month),
        child: Center(
          child: Text(
            DateFormat('MMM').format(month),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? cs.onPrimary
                  : disabled
                  ? cs.onSurface.withValues(alpha: 0.35)
                  : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
