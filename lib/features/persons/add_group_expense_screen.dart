import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/group_split_math.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Logs a shared expense across a group's members — equal, percentage, or
/// manual split. Every number shown here is computed by the same
/// [computeGroupShares] `AppDatabase.addGroupExpense` itself calls, so what
/// you see previewed is exactly what gets saved.
class AddGroupExpenseScreen extends ConsumerStatefulWidget {
  const AddGroupExpenseScreen({required this.groupId, super.key});

  final int groupId;

  @override
  ConsumerState<AddGroupExpenseScreen> createState() =>
      _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState
    extends ConsumerState<AddGroupExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final Map<int?, TextEditingController> _percentControllers = {};
  final Map<int?, TextEditingController> _manualControllers = {};

  DateTime _date = DateTime.now();
  int? _payerId; // null = me
  Set<int?> _participantIds = {};
  GroupSplitMethod _splitMethod = GroupSplitMethod.equal;
  int? _accountId;
  int? _categoryId;
  bool _participantsInitialized = false;
  String? _amountError;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    for (final c in _manualControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _percentController(int? id) =>
      _percentControllers.putIfAbsent(id, TextEditingController.new);

  TextEditingController _manualController(int? id) =>
      _manualControllers.putIfAbsent(id, TextEditingController.new);

  /// Canonical order: me, then members in `groupMembersProvider`'s order —
  /// the same order a rounding remainder is distributed in, so a filtered
  /// (participants-only) view of this order stays consistent everywhere.
  List<int?> _allIdsInOrder(List<PersonRow> members) => [
    null,
    ...members.map((m) => m.id),
  ];

  String _nameFor(int? id, List<PersonRow> members) {
    if (id == null) return 'You';
    return members.firstWhere((m) => m.id == id).name;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Map<int?, Money>? _previewShares(List<PersonRow> members) {
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive || _participantIds.isEmpty) {
      return null;
    }
    final ordered = _allIdsInOrder(
      members,
    ).where(_participantIds.contains).toList();
    try {
      switch (_splitMethod) {
        case GroupSplitMethod.equal:
          return computeGroupShares(
            amount: amount,
            splitMethod: _splitMethod,
            participantIds: ordered,
          );
        case GroupSplitMethod.percentage:
          final bp = <int?, int>{
            for (final id in ordered)
              id: ((double.tryParse(_percentController(id).text) ?? 0) * 100)
                  .round(),
          };
          return computeGroupShares(
            amount: amount,
            splitMethod: _splitMethod,
            participantIds: ordered,
            percentBasisPoints: bp,
          );
        case GroupSplitMethod.manual:
          final amounts = <int?, Money>{
            for (final id in ordered)
              id: Money.tryParse(_manualController(id).text) ?? Money.zero(),
          };
          return computeGroupShares(
            amount: amount,
            splitMethod: _splitMethod,
            participantIds: ordered,
            manualAmounts: amounts,
          );
      }
    } on ArgumentError {
      return null; // doesn't sum right yet — the running-total row shows why
    }
  }

  Future<void> _save(List<PersonRow> members) async {
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || !amount.isPositive) {
      setState(() => _amountError = 'Enter an amount greater than zero');
      return;
    }
    if (_participantIds.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Pick at least one participant')));
      return;
    }
    if (_payerId == null &&
        _participantIds.contains(null) &&
        (_accountId == null || _categoryId == null)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Pick an account and category for your own share'),
          ),
        );
      return;
    }

    final ordered = _allIdsInOrder(
      members,
    ).where(_participantIds.contains).toList();
    final note = _noteController.text.trim();

    Map<int?, int>? percentBasisPoints;
    Map<int?, Money>? manualAmounts;
    if (_splitMethod == GroupSplitMethod.percentage) {
      percentBasisPoints = {
        for (final id in ordered)
          id: ((double.tryParse(_percentController(id).text) ?? 0) * 100)
              .round(),
      };
    } else if (_splitMethod == GroupSplitMethod.manual) {
      manualAmounts = {
        for (final id in ordered)
          id: Money.tryParse(_manualController(id).text) ?? Money.zero(),
      };
    }

    setState(() {
      _amountError = null;
      _saving = true;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(dbProvider)
          .addGroupExpense(
            groupId: widget.groupId,
            amount: amount,
            splitMethod: _splitMethod,
            date: _date,
            note: note.isEmpty ? null : note,
            payerId: _payerId,
            accountId: _accountId,
            categoryId: _categoryId,
            participantIds: _participantIds,
            percentBasisPoints: percentBasisPoints,
            manualAmounts: manualAmounts,
          );
    } on ArgumentError catch (e) {
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.message?.toString() ?? 'Could not save')),
        );
      return;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Expense added')));
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Add group expense')),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Couldn't load members.\n$e")),
        data: (members) {
          if (!_participantsInitialized) {
            _participantIds = _allIdsInOrder(members).toSet();
            _participantsInitialized = true;
          }
          return _buildForm(context, members);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<PersonRow> members) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shares = _previewShares(members);
    final showAccountFields =
        _payerId == null && _participantIds.contains(null);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: MoneyFormat.inputPrefix,
              errorText: _amountError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _payerId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Paid by',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('You')),
              for (final m in members)
                DropdownMenuItem<int?>(value: m.id, child: Text(m.name)),
            ],
            onChanged: (v) => setState(() => _payerId = v),
          ),
          const SizedBox(height: 20),
          Text('Participants', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in _allIdsInOrder(members))
                FilterChip(
                  label: Text(_nameFor(id, members)),
                  selected: _participantIds.contains(id),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _participantIds = {..._participantIds, id};
                    } else {
                      _participantIds = {..._participantIds}..remove(id);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Split', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<GroupSplitMethod>(
            segments: const [
              ButtonSegment(
                value: GroupSplitMethod.equal,
                label: Text('Equal'),
              ),
              ButtonSegment(
                value: GroupSplitMethod.percentage,
                label: Text('Percent'),
              ),
              ButtonSegment(
                value: GroupSplitMethod.manual,
                label: Text('Manual'),
              ),
            ],
            selected: {_splitMethod},
            onSelectionChanged: (v) => setState(() => _splitMethod = v.first),
          ),
          const SizedBox(height: 16),
          if (_participantIds.isEmpty)
            Text(
              'Pick at least one participant.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            )
          else
            ..._buildShareRows(members, shares),
          if (showAccountFields) ...[
            const SizedBox(height: 20),
            _AccountAndCategoryFields(
              accountId: _accountId,
              categoryId: _categoryId,
              onAccountChanged: (v) => setState(() => _accountId = v),
              onCategoryChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(
              '${_date.day}/${_date.month}/${_date.year}',
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : () => _save(members),
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Save expense'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildShareRows(
    List<PersonRow> members,
    Map<int?, Money>? shares,
  ) {
    final ordered = _allIdsInOrder(
      members,
    ).where(_participantIds.contains).toList();

    switch (_splitMethod) {
      case GroupSplitMethod.equal:
        return [
          for (final id in ordered)
            _ShareRow(
              label: _nameFor(id, members),
              trailing: Text(
                shares != null
                    ? MoneyFormat.symbol(shares[id] ?? Money.zero())
                    : '—',
              ),
              tracked: _trackedFor(id),
            ),
        ];
      case GroupSplitMethod.percentage:
        final totalBp = ordered.fold<double>(
          0,
          (sum, id) => sum + (double.tryParse(_percentController(id).text) ?? 0),
        );
        return [
          for (final id in ordered)
            _ShareRow(
              label: _nameFor(id, members),
              tracked: _trackedFor(id),
              trailing: SizedBox(
                width: 84,
                child: TextField(
                  controller: _percentController(id),
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    suffixText: '%',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          _RunningTotal(
            label: 'Total',
            value: '${totalBp.toStringAsFixed(2)}%',
            matches: (totalBp - 100).abs() <= 0.5,
          ),
        ];
      case GroupSplitMethod.manual:
        final amount = Money.tryParse(_amountController.text);
        final totalEntered = ordered.fold<Money>(
          Money.zero(),
          (sum, id) => sum + (Money.tryParse(_manualController(id).text) ?? Money.zero()),
        );
        return [
          for (final id in ordered)
            _ShareRow(
              label: _nameFor(id, members),
              tracked: _trackedFor(id),
              trailing: SizedBox(
                width: 110,
                child: TextField(
                  controller: _manualController(id),
                  textAlign: TextAlign.end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    prefixText: MoneyFormat.inputPrefix,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          _RunningTotal(
            label: 'Total',
            value: MoneyFormat.symbol(totalEntered),
            matches: amount != null && totalEntered == amount,
          ),
        ];
    }
  }

  /// Whether [id]'s share will actually be saved anywhere — see the class
  /// doc on `GroupExpenses` for why a third party's share (when someone
  /// else paid) can't be.
  bool _trackedFor(int? id) {
    if (_payerId == null) return true; // I paid: every share is trackable
    if (id == null) return true; // my own share: "I owe them"
    return false; // the payer's own share, or a third party's
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.trailing,
    required this.tracked,
  });

  final String label;
  final Widget trailing;
  final bool tracked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                if (!tracked)
                  Text(
                    'Not tracked — shown for reference only',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Opacity(opacity: tracked ? 1 : 0.6, child: trailing),
        ],
      ),
    );
  }
}

class _RunningTotal extends StatelessWidget {
  const _RunningTotal({
    required this.label,
    required this.value,
    required this.matches,
  });

  final String label;
  final String value;
  final bool matches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = matches ? AppColors.income : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAndCategoryFields extends ConsumerWidget {
  const _AccountAndCategoryFields({
    required this.accountId,
    required this.categoryId,
    required this.onAccountChanged,
    required this.onCategoryChanged,
  });

  final int? accountId;
  final int? categoryId;
  final ValueChanged<int?> onAccountChanged;
  final ValueChanged<int?> onCategoryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    final categories =
        ref.watch(categoriesProvider(CategoryKind.expense)).valueOrNull ??
        const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your share', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          initialValue: accountId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Account',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final a in accounts)
              DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
          ],
          onChanged: onAccountChanged,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int?>(
          initialValue: categoryId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in categories)
              DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
          ],
          onChanged: onCategoryChanged,
        ),
      ],
    );
  }
}
