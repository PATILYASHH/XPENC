import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

const _presetColors = <int>[
  0xFF16A34A,
  0xFF2563EB,
  0xFFDC2626,
  0xFFA855F7,
  0xFFF97316,
  0xFF0EA5E9,
  0xFF78716C,
  0xFFEC4899,
];

const _iconKeys = <String>[
  'savings',
  'travel',
  'education',
  'shopping',
  'health',
  'gift',
  'card',
  'other',
];

/// A savings target tracked live from a real account's balance — see
/// `SavingsGoals` in tables.dart. No separate ledger: "contributing" is just
/// depositing or transferring into that account the normal way.
class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(savingsGoalsProvider);
    final progress = ref.watch(savingsGoalProgressListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            "Couldn't load savings goals.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        data: (_) {
          if (progress.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
              child: Column(
                children: [
                  Icon(
                    Icons.savings_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No savings goals yet — tap + to set one, linked to any '
                    'account you already have.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            itemCount: progress.length,
            itemBuilder: (context, i) => _GoalCard(progress: progress[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New goal',
        onPressed: () => _openGoalEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress});

  final SavingsGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = progress.goal;
    final color = Color(goal.colorValue);
    final daysLeft = goal.targetDate?.difference(DateTime.now()).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/more/savings/${goal.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.resolve(goal.iconKey), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (progress.account != null)
                            Text(
                              progress.account!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (progress.reached)
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.income,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: MoneyFormat.symbol(progress.saved),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' of ${MoneyFormat.symbol(goal.targetAmount)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (daysLeft != null)
                      Text(
                        daysLeft >= 0 ? '$daysLeft days left' : 'Past due',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: daysLeft >= 0
                              ? theme.colorScheme.onSurfaceVariant
                              : AppColors.expense,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openGoalEditor(BuildContext context, {SavingsGoalRow? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _GoalEditorSheet(existing: existing),
  );
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  const _GoalEditorSheet({this.existing});

  final SavingsGoalRow? existing;

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late int _colorValue;
  late String _iconKey;
  int? _accountId;
  DateTime? _targetDate;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : MoneyFormat.bare(existing.targetAmount),
    );
    _colorValue = existing?.colorValue ?? _presetColors.first;
    _iconKey = existing?.iconKey ?? _iconKeys.first;
    _accountId = existing?.accountId;
    _targetDate = existing?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give the goal a name.');
      return;
    }
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      _showError('Enter a target amount greater than zero.');
      return;
    }
    if (_accountId == null) {
      _showError('Pick the account this goal tracks.');
      return;
    }

    setState(() => _submitting = true);
    final db = ref.read(dbProvider);
    try {
      if (_isEdit) {
        await db.updateSavingsGoal(
          id: widget.existing!.id,
          name: name,
          targetAmount: amount,
          accountId: _accountId!,
          targetDate: _targetDate,
          colorValue: _colorValue,
          iconKey: _iconKey,
        );
      } else {
        await db.addSavingsGoal(
          name: name,
          targetAmount: amount,
          accountId: _accountId!,
          targetDate: _targetDate,
          colorValue: _colorValue,
          iconKey: _iconKey,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not save the goal.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not save the goal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit goal' : 'New savings goal',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Emergency fund, Goa trip',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: '₹ ',
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: accounts.any((a) => a.id == _accountId)
                  ? _accountId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tracks this account',
                helperText: "Progress is that account's live balance",
              ),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickTargetDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _targetDate == null
                    ? 'Target date (optional)'
                    : DateFormat('d MMM yyyy').format(_targetDate!),
              ),
            ),
            if (_targetDate != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _targetDate = null),
                  child: const Text('Clear date'),
                ),
              ),
            const SizedBox(height: 12),
            _fieldLabel(theme, 'Colour'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final c in _presetColors) _colorDot(theme, c)],
            ),
            const SizedBox(height: 24),
            _fieldLabel(theme, 'Icon'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [for (final k in _iconKeys) _iconTile(theme, k)],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(ThemeData theme, String text) {
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _colorDot(ThemeData theme, int value) {
    final selected = _colorValue == value;
    return GestureDetector(
      onTap: () => setState(() => _colorValue = value),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _iconTile(ThemeData theme, String key) {
    final selected = _iconKey == key;
    final color = Color(_colorValue);
    return GestureDetector(
      onTap: () => setState(() => _iconKey = key),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : theme.colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Icon(
          AppIcons.resolve(key),
          color: selected ? color : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Opens the editor for an existing goal — used by the detail screen's Edit
/// action.
void openSavingsGoalEditor(BuildContext context, SavingsGoalRow goal) {
  _openGoalEditor(context, existing: goal);
}
