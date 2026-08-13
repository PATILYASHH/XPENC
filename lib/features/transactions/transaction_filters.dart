import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Snapshot of every advanced filter the tune sheet can set — date range,
/// account, category, tag. Shared between the top bar (which owns the button
/// and the badge count) and [TransactionsScreen] (which applies it) via
/// `txAdvancedFiltersProvider`.
class TransactionFilters {
  const TransactionFilters({
    this.dateRange,
    this.accountIds = const {},
    this.categoryIds = const {},
    this.tagIds = const {},
  });

  final DateTimeRange? dateRange;
  final Set<int> accountIds;
  final Set<int> categoryIds;
  final Set<int> tagIds;

  int get count =>
      (dateRange != null ? 1 : 0) +
      (accountIds.isNotEmpty ? 1 : 0) +
      (categoryIds.isNotEmpty ? 1 : 0) +
      (tagIds.isNotEmpty ? 1 : 0);
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

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initial.dateRange;
    _accountIds.addAll(widget.initial.accountIds);
    _categoryIds.addAll(widget.initial.categoryIds);
    _tagIds.addAll(widget.initial.tagIds);
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

  void _clearAll() {
    setState(() {
      _dateRange = null;
      _accountIds.clear();
      _categoryIds.clear();
      _tagIds.clear();
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      TransactionFilters(
        dateRange: _dateRange,
        accountIds: _accountIds,
        categoryIds: _categoryIds,
        tagIds: _tagIds,
      ),
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
    final tags = ref.watch(tagsProvider).valueOrNull ?? const [];

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
                    child: Text('Filters', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(theme, 'Date range'),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _dateRange == null
                            ? 'Any time'
                            : '${DateFormat('d MMM yyyy').format(_dateRange!.start)} '
                                  '– ${DateFormat('d MMM yyyy').format(_dateRange!.end)}',
                      ),
                    ),
                    if (_dateRange != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _dateRange = null),
                          child: const Text('Clear date range'),
                        ),
                      ),
                    if (accounts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel(theme, 'Account'),
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
                      _sectionLabel(theme, 'Category'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in categories)
                            FilterChip(
                              label: Text(c.name),
                              avatar: Icon(
                                AppIcons.resolve(c.iconKey),
                                size: 16,
                              ),
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
                      _sectionLabel(theme, 'Tag'),
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
              child: FilledButton(
                onPressed: _apply,
                child: const Text('Apply'),
              ),
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
