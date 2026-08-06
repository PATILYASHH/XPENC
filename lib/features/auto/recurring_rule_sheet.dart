import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Opens the add/edit sheet. Pass [existing] to edit that rule instead of
/// creating a new one.
Future<void> showRecurringRuleSheet(
  BuildContext context, {
  RecurringRuleRow? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => RecurringRuleSheet(existing: existing),
  );
}

/// Create or edit an Auto rule — an income or expense that posts itself on a
/// schedule, with no confirmation step. A rule marked "amount varies" still
/// posts on schedule, using the entered amount as a placeholder, but flags
/// the result via [Transactions.needsAmountReview] so the user is nudged to
/// correct it. See [AppDatabase.runDueRecurringRules].
class RecurringRuleSheet extends ConsumerStatefulWidget {
  const RecurringRuleSheet({this.existing, super.key});

  final RecurringRuleRow? existing;

  @override
  ConsumerState<RecurringRuleSheet> createState() => _RecurringRuleSheetState();
}

class _RecurringRuleSheetState extends ConsumerState<RecurringRuleSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _payeeFocus = FocusNode();

  CategoryKind _kind = CategoryKind.expense;
  int? _accountId;
  int? _categoryId;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  late DateTime _dueDate;
  double _notifyDays = 3;
  bool _isEstimate = false;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _dueDate = DateTime.now();
      return;
    }
    _nameController.text = e.name;
    _amountController.text = _bufferFromMoney(e.amount);
    _payeeController.text = e.payee ?? '';
    _kind = e.kind;
    _accountId = e.accountId;
    _categoryId = e.categoryId;
    _frequency = e.frequency;
    _dueDate = e.nextDueDate;
    _notifyDays = e.notifyDaysBefore.toDouble();
    _isEstimate = e.isEstimate;
  }

  static String _bufferFromMoney(Money amount) {
    final paise = amount.abs.paise;
    final rupees = paise ~/ 100;
    final fraction = paise % 100;
    if (fraction == 0) return '$rupees';
    return '$rupees.${fraction.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _payeeController.dispose();
    _payeeFocus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give it a name.');
      return;
    }
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      _showError('Enter an amount greater than zero.');
      return;
    }
    if (_accountId == null) {
      _showError('Choose an account.');
      return;
    }
    if (_categoryId == null) {
      _showError('Choose a category.');
      return;
    }
    final payeeText = _payeeController.text.trim();
    final payee = _kind == CategoryKind.expense && payeeText.isNotEmpty
        ? payeeText
        : null;

    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      if (_isEditing) {
        await ref
            .read(dbProvider)
            .updateRecurringRule(
              id: widget.existing!.id,
              name: name,
              kind: _kind,
              amount: amount,
              accountId: _accountId!,
              categoryId: _categoryId!,
              payee: payee,
              frequency: _frequency,
              nextDueDate: _dueDate,
              notifyDaysBefore: _notifyDays.round(),
              isEstimate: _isEstimate,
            );
      } else {
        await ref
            .read(dbProvider)
            .addRecurringRule(
              name: name,
              kind: _kind,
              amount: amount,
              accountId: _accountId!,
              categoryId: _categoryId!,
              payee: payee,
              frequency: _frequency,
              startsOn: _dueDate,
              notifyDaysBefore: _notifyDays.round(),
              isEstimate: _isEstimate,
            );
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not save.');
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save.');
      return;
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories =
        ref.watch(categoriesProvider(_kind)).valueOrNull ?? const [];
    final categoryMap = ref.watch(categoryMapProvider);

    // The chosen category may no longer match the kind after toggling —
    // clear it rather than silently keep an invalid id selected.
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _categoryId = null);
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom:
            MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit auto rule' : 'New auto rule',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<CategoryKind>(
              segments: const [
                ButtonSegment(
                  value: CategoryKind.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: CategoryKind.income,
                  label: Text('Income'),
                ),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: _kind == CategoryKind.expense
                    ? 'e.g. Netflix, Rent'
                    : 'e.g. Salary',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
              ),
              decoration: InputDecoration(
                labelText: _isEstimate ? 'Usual amount' : 'Amount',
                prefixText: MoneyFormat.inputPrefix,
                helperText: _isEstimate
                    ? "You'll be nudged to confirm the exact figure each "
                          'time it posts.'
                    : null,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Amount varies each time'),
              subtitle: const Text(
                'For a salary or bill that changes, e.g. by hours worked.',
              ),
              value: _isEstimate,
              onChanged: (v) => setState(() => _isEstimate = v),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _accountId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: categories.any((c) => c.id == _categoryId)
                  ? _categoryId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(_categoryLabel(c, categoryMap)),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            if (_kind == CategoryKind.expense) ...[
              const SizedBox(height: 16),
              _payeeField(theme),
            ],
            const SizedBox(height: 20),
            // Four segments can outgrow a narrow phone or a larger system
            // font scale — scroll rather than let it overflow (GitHub #14).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<RecurringFrequency>(
                segments: const [
                  ButtonSegment(
                    value: RecurringFrequency.daily,
                    label: Text('Daily'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.weekly,
                    label: Text('Weekly'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.biweekly,
                    label: Text('2 weeks'),
                  ),
                  ButtonSegment(
                    value: RecurringFrequency.monthly,
                    label: Text('Monthly'),
                  ),
                ],
                selected: {_frequency},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _frequency = s.first),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Next due date' : 'Starts on',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEE, d MMM yyyy').format(_dueDate),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_frequency == RecurringFrequency.monthly)
              Text(
                'A shorter month snaps to its last day, then returns to the '
                '${_dueDate.day}${_ordinalSuffix(_dueDate.day)} once it exists again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Notify me ${_notifyDays.round()} '
              'day${_notifyDays.round() == 1 ? '' : 's'} before',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: _notifyDays,
              min: 0,
              max: 7,
              divisions: 7,
              label: '${_notifyDays.round()}',
              onChanged: (v) => setState(() => _notifyDays = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Create rule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payeeField(ThemeData theme) {
    final suggestions = ref.watch(payeeSuggestionsProvider);
    return Autocomplete<String>(
      textEditingController: _payeeController,
      focusNode: _payeeFocus,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return suggestions.where((s) => s.toLowerCase().contains(q));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Payee (optional)',
            hintText: 'Who gets paid?',
          ),
        );
      },
    );
  }

  String _categoryLabel(CategoryRow c, Map<int, CategoryRow> byId) {
    if (c.parentId == null) return c.name;
    final parent = byId[c.parentId];
    return parent == null ? c.name : '${parent.name} › ${c.name}';
  }

  static String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
