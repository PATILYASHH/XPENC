import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/budget_cycle.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

/// Opens the month picker and returns the chosen period anchor (day 1 of its
/// month, same shape `selectedMonthProvider` stores), or null if dismissed.
/// [current] is the anchor of the period containing today — months after it
/// can't be picked, since there's nothing recorded there yet to look back at
/// (unless [latest] says a later month has entries).
///
/// [marked] puts a dot under each month that has something in it, so a
/// month worth opening is visible before it's tapped. With [allowAllTime]
/// the sheet also offers "All time", returned as [MonthPickerSheet.allTime].
Future<DateTime?> showMonthPickerSheet(
  BuildContext context, {
  required DateTime selected,
  required DateTime current,
  required int startDay,
  Set<DateTime> marked = const {},
  DateTime? latest,
  bool allowAllTime = false,
}) {
  return showAppSheet<DateTime>(
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
      marked: marked,
      latest: latest,
      allowAllTime: allowAllTime,
    ),
  );
}

/// A year header with ‹ › and a 4×3 grid of months, coloured from the
/// active theme — the Dashboard's one way to move between months (it
/// replaced the ‹ › arrows that used to sit on the This Month card), and
/// Transactions' month picker.
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    required this.selected,
    required this.current,
    required this.startDay,
    this.marked = const {},
    this.latest,
    this.allowAllTime = false,
    super.key,
  });

  /// What the sheet resolves to when "All time" is picked — never a real
  /// month anyone could have picked.
  static final allTime = DateTime(1);

  final DateTime selected;
  final DateTime current;
  final int startDay;
  final Set<DateTime> marked;
  final DateTime? latest;
  final bool allowAllTime;

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _year = widget.selected == MonthPickerSheet.allTime
      ? widget.current.year
      : widget.selected.year;

  DateTime get _last {
    final latest = widget.latest;
    return latest != null && latest.isAfter(widget.current)
        ? latest
        : widget.current;
  }

  bool _isFuture(DateTime month) => month.isAfter(_last);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canGoForward = _year < _last.year;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20).plusNavBar(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: tr('Previous year'),
                icon: const AppIcon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _year--),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    '$_year',
                    key: ValueKey(_year),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Next year'),
                icon: const AppIcon(Icons.chevron_right_rounded),
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
              tr(
                'Each month runs from '
                '{0} (your budget cycle).',
                [budgetCycleStartPhrase(widget.startDay)],
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (widget.marked.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tr('A dot marks a month with entries.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.selected == widget.current
                      ? null
                      : () => Navigator.of(context).pop(widget.current),
                  icon: const AppIcon(Icons.today_rounded),
                  label: const Tr('This month'),
                ),
              ),
              if (widget.allowAllTime) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('monthPickerAllTime'),
                    onPressed: widget.selected == MonthPickerSheet.allTime
                        ? null
                        : () => Navigator.of(
                            context,
                          ).pop(MonthPickerSheet.allTime),
                    icon: const AppIcon(Icons.all_inclusive_rounded),
                    label: const Tr('All time'),
                  ),
                ),
              ],
            ],
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
    final marked = widget.marked.contains(month);
    final ink = isSelected
        ? cs.onPrimary
        : disabled
        ? cs.onSurface.withValues(alpha: 0.35)
        : cs.onSurface;

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('MMM').format(month),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: ink,
              ),
            ),
            if (widget.marked.isNotEmpty) ...[
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: marked
                      ? (isSelected ? cs.onPrimary : cs.primary)
                      : Colors.transparent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
