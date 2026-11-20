import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/iso_week.dart';
import '../../core/smart_tags.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../data/database.dart';
import '../../data/tables.dart';
import '../dashboard/month_picker_sheet.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../core/l10n/l10n.dart';

/// Which widget the "Date range" section shows — a month at a time (the
/// default), a week-at-a-time stepper (GitHub #121), a plain range picker,
/// or everything. Local to the sheet: neither [TransactionFilters] nor the
/// rest of the app needs to know how a range was chosen, only what it
/// resolved to.
enum _DateFilterMode { month, week, custom, all }

/// Day 1 of [d]'s calendar month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// [month]'s first to last day (plain dates, like every other range here).
DateTimeRange monthRange(DateTime month) => DateTimeRange(
  start: DateTime(month.year, month.month),
  end: DateTime(month.year, month.month + 1, 0),
);

/// Every month (day 1) that has at least one of [txns] — the dots on the
/// month picker.
Set<DateTime> transactionMonths(List<TransactionRow> txns) => {
  for (final t in txns) monthOf(t.date),
};

/// Snapshot of every advanced filter the tune sheet can set — the period
/// (a month, or a week/custom range), account, category, tag. Shared
/// between the top bar (which owns the button and the badge count) and
/// [TransactionsScreen] (which applies it) via `txAdvancedFiltersProvider`.
///
/// The list opens on this month ([TransactionFilters.thisMonth]): what a
/// month's money did is what people come here to see. `const
/// TransactionFilters()` is every transaction — what a jump from Search to a
/// tag wants.
class TransactionFilters {
  const TransactionFilters({
    this.month,
    this.dateRange,
    this.accountIds = const {},
    this.categoryIds = const {},
    this.tagIds = const {},
  });

  /// The default view: the calendar month containing [now] (today).
  factory TransactionFilters.thisMonth([DateTime? now]) =>
      TransactionFilters(month: monthOf(now ?? DateTime.now()));

  /// Day 1 of the calendar month the list shows. Ignored while [dateRange]
  /// is set; both null is all time.
  final DateTime? month;

  /// A week or custom range picked in the sheet — wins over [month].
  final DateTimeRange? dateRange;
  final Set<int> accountIds;
  final Set<int> categoryIds;
  final Set<int> tagIds;

  /// Neither a month nor a range: every transaction.
  bool get isAllTime => month == null && dateRange == null;

  /// The month being shown, when the period is one whole month.
  DateTime? get shownMonth => dateRange == null ? month : null;

  /// The dates the list is limited to, or null for all time.
  DateTimeRange? get range =>
      dateRange ?? (month == null ? null : monthRange(month!));

  /// What narrows the list besides its period — the badge on the Filters
  /// button. The period isn't counted: the card over the list always names
  /// it, and the default month would otherwise light the badge for nothing.
  int get count =>
      (accountIds.isNotEmpty ? 1 : 0) +
      (categoryIds.isNotEmpty ? 1 : 0) +
      (tagIds.isNotEmpty ? 1 : 0);

  /// The same filters over another period: a [month], a [range], or —
  /// neither — all time.
  TransactionFilters withPeriod({DateTime? month, DateTimeRange? range}) =>
      TransactionFilters(
        month: range == null && month != null ? monthOf(month) : null,
        dateRange: range,
        accountIds: accountIds,
        categoryIds: categoryIds,
        tagIds: tagIds,
      );
}

/// Bottom sheet: date range plus multi-select chips for account, category and
/// tag. Edits a local copy — nothing applies to the list until "Apply".
class TransactionFiltersSheet extends ConsumerStatefulWidget {
  const TransactionFiltersSheet({required this.initial, super.key});

  final TransactionFilters initial;

  @override
  ConsumerState<TransactionFiltersSheet> createState() =>
      _TransactionFiltersSheetState();
}

class _TransactionFiltersSheetState
    extends ConsumerState<TransactionFiltersSheet> {
  DateTimeRange? _dateRange;
  final Set<int> _accountIds = {};
  final Set<int> _categoryIds = {};
  final Set<int> _tagIds = {};

  late _DateFilterMode _dateMode;

  /// The month the Month stepper shows — kept apart from [_dateRange] so
  /// switching modes back and forth doesn't lose it.
  late DateTime _month;

  /// Which week the stepper is showing — independent of [_dateRange], since
  /// that may be null or a custom multi-week range. Stepping (or first
  /// switching into week mode) always writes its result straight into
  /// [_dateRange], same as picking a custom range does.
  late DateTime _weekAnchor = _dateRange?.start ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _dateRange = initial.dateRange;
    _month = initial.month ?? monthOf(DateTime.now());
    _dateMode = initial.dateRange != null
        ? _DateFilterMode.custom
        : initial.month != null
        ? _DateFilterMode.month
        : _DateFilterMode.all;
    _accountIds.addAll(initial.accountIds);
    _categoryIds.addAll(initial.categoryIds);
    _tagIds.addAll(initial.tagIds);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (picked == null) return;
    setState(() => _dateRange = picked);
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPickerSheet(
      context,
      selected: _month,
      current: monthOf(DateTime.now()),
      startDay: 1,
      marked: transactionMonths(
        ref.read(allTransactionsProvider).valueOrNull ?? const [],
      ),
    );
    if (picked == null || picked == MonthPickerSheet.allTime || !mounted) {
      return;
    }
    setState(() => _month = picked);
  }

  void _setDateMode(_DateFilterMode mode) {
    setState(() {
      _dateMode = mode;
      if (mode == _DateFilterMode.week) {
        _dateRange = weekRangeContaining(_weekAnchor);
      } else if (mode != _DateFilterMode.custom) {
        _dateRange = null;
      }
    });
  }

  void _stepWeek(int weeks) {
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: 7 * weeks));
      _dateRange = weekRangeContaining(_weekAnchor);
    });
  }

  void _stepMonth(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  /// Back to how the list opens: this month, nothing else narrowing it.
  void _clearAll() {
    setState(() {
      _dateRange = null;
      _month = monthOf(DateTime.now());
      _dateMode = _DateFilterMode.month;
      _accountIds.clear();
      _categoryIds.clear();
      _tagIds.clear();
    });
  }

  void _apply() {
    final range = switch (_dateMode) {
      _DateFilterMode.week || _DateFilterMode.custom => _dateRange,
      _ => null,
    };
    Navigator.of(context).pop(
      TransactionFilters(
        month: _dateMode == _DateFilterMode.month ? _month : null,
        dateRange: range,
        accountIds: _accountIds,
        categoryIds: _categoryIds,
        tagIds: _tagIds,
      ),
    );
  }

  /// "‹ label ›" — the Month and Week modes' stepper. [onLabel] makes the
  /// label itself a button (the month grid).
  Widget _stepper(
    ThemeData theme, {
    required String label,
    required String previous,
    required String next,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    VoidCallback? onLabel,
  }) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: const AppIcon(Icons.chevron_left_rounded),
          tooltip: previous,
        ),
        Expanded(
          child: onLabel == null
              ? text
              : TextButton.icon(
                  onPressed: onLabel,
                  icon: const AppIcon(Icons.calendar_month_rounded, size: 18),
                  label: text,
                ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const AppIcon(Icons.chevron_right_rounded),
          tooltip: next,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final income =
        ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ??
        const [];
    final expense =
        ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ??
        const [];
    final categories = [...expense, ...income];
    // A smart tag (GitHub #189) never sits on a transaction — the plain
    // tags it makes do — so there's nothing to filter it by.
    final tags = [
      ...?ref
          .watch(tagsProvider)
          .valueOrNull
          ?.where((t) => !SmartTags.isSmart(t.name)),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Tr('Filters', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Tr('Clear all'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  8,
                ).plusNavBar(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(theme, tr('Date range')),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_DateFilterMode>(
                        segments: const [
                          ButtonSegment(
                            value: _DateFilterMode.month,
                            label: Tr('Month'),
                          ),
                          ButtonSegment(
                            value: _DateFilterMode.week,
                            label: Tr('Week'),
                          ),
                          ButtonSegment(
                            value: _DateFilterMode.custom,
                            label: Tr('Custom'),
                          ),
                          ButtonSegment(
                            value: _DateFilterMode.all,
                            label: Tr('All'),
                          ),
                        ],
                        selected: {_dateMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => _setDateMode(s.first),
                      ),
                    ),
                    const SizedBox(height: 10),
                    switch (_dateMode) {
                      _DateFilterMode.month => _stepper(
                        theme,
                        label: DateFormat('MMMM yyyy').format(_month),
                        previous: tr('Previous month'),
                        next: tr('Next month'),
                        onPrevious: () => _stepMonth(-1),
                        onNext: () => _stepMonth(1),
                        onLabel: _pickMonth,
                      ),
                      _DateFilterMode.week => _stepper(
                        theme,
                        label: weekLabel(_weekAnchor),
                        previous: tr('Previous week'),
                        next: tr('Next week'),
                        onPrevious: () => _stepWeek(-1),
                        onNext: () => _stepWeek(1),
                      ),
                      _DateFilterMode.custom => OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const AppIcon(Icons.event_outlined, size: 18),
                        label: Text(
                          _dateRange == null
                              ? tr('Pick dates')
                              : '${DateFormat('d MMM yyyy').format(_dateRange!.start)} '
                                    '– ${DateFormat('d MMM yyyy').format(_dateRange!.end)}',
                        ),
                      ),
                      _DateFilterMode.all => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          tr('Every transaction, from the very first.'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    },
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel(theme, tr('Account')),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in accounts)
                            FilterChip(
                              label: Text(a.name),
                              selected: _accountIds.contains(a.id),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _accountIds.add(a.id);
                                } else {
                                  _accountIds.remove(a.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel(theme, tr('Category')),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in categories)
                            FilterChip(
                              label: Text(c.name),
                              avatar: KeyIcon(c.iconKey, size: 16),
                              selected: _categoryIds.contains(c.id),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _categoryIds.add(c.id);
                                } else {
                                  _categoryIds.remove(c.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel(theme, tr('Tag')),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in tags)
                            FilterChip(
                              label: Text(t.name),
                              selected: _tagIds.contains(t.id),
                              selectedColor: Color(
                                t.colorValue,
                              ).withValues(alpha: 0.22),
                              checkmarkColor: Color(t.colorValue),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _tagIds.add(t.id);
                                } else {
                                  _tagIds.remove(t.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(onPressed: _apply, child: const Tr('Apply')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}
