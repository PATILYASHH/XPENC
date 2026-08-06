import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'receipt_storage.dart';

/// One editable row of a split expense: which category, and how much of the
/// total it takes. Holds its own controller so [TextField]s keep their
/// identity (and cursor position) across rebuilds.
class _SplitEntry {
  _SplitEntry({
    this.categoryId,
    String amountText = '',
    VoidCallback? onFocusChange,
  }) : amountController = TextEditingController(text: amountText),
       focusNode = FocusNode() {
    if (onFocusChange != null) focusNode.addListener(onFocusChange);
  }

  int? categoryId;
  final TextEditingController amountController;

  /// Tracked so the on-screen keypad hides while this row's system keyboard
  /// is up — see [_AddTransactionScreenState._textFieldFocused]. Without
  /// this, focusing a split amount brought up the system keyboard *on top
  /// of* the still-visible custom keypad.
  final FocusNode focusNode;

  Money get amount =>
      Money.tryParse(amountController.text) ?? const Money.zero();

  void dispose() {
    amountController.dispose();
    focusNode.dispose();
  }
}

/// The ➕ route. Expense / Income / Transfer.
///
/// A transfer is neither income nor expense: it never carries a category and
/// always moves money between two different accounts.
///
/// With a [transactionId] the screen edits that existing transaction instead
/// of creating a new one.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({this.transactionId, this.initialType, super.key});

  final int? transactionId;

  /// Preselects Expense or Income — used by the home-screen widget's "+
  /// Expense" / "+ Income" shortcuts to skip the type-picker step. Ignored
  /// when [transactionId] is set, since editing loads its own type.
  final TxType? initialType;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TxType _type;

  /// Raw rupee text as typed on the keypad: digits + at most one '.'.
  String _buffer = '';

  int? _accountId; // expense/income: account. transfer: FROM account.
  int? _toAccountId; // transfer: TO account.
  int? _categoryId; // income/expense only.
  DateTime _date = DateTime.now();

  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  /// Expense only — who got paid. Free text with autocomplete, never read for
  /// any other transaction type.
  final _payeeController = TextEditingController();
  final _payeeFocus = FocusNode();

  /// Cuts across category/account — any transaction type can carry tags.
  Set<int> _tagIds = {};

  /// Expense only — one expense, several categories, instead of one.
  bool _isSplit = false;
  final List<_SplitEntry> _splitRows = [];

  /// The receipt path that will be saved — an existing one loaded for
  /// editing, a freshly picked one, or null.
  String? _imagePath;

  /// Set only when [_imagePath] was picked *this session* and not yet saved —
  /// so `dispose()` can clean it up if the screen is left without saving,
  /// rather than leaking a copy nothing will ever reference.
  String? _unsavedPickedPath;

  /// True while an existing transaction is being fetched for editing.
  bool _loading = false;

  bool get _isEditing => widget.transactionId != null;

  /// Split only ever applies to an expense — [_isSplit] can be stale after a
  /// type switch (kept around so toggling back doesn't lose entered rows).
  bool get _isSplitting => _type == TxType.expense && _isSplit;

  /// The on-screen keypad and the system keyboard must never both be up —
  /// they'd fight over the same strip of screen and hide whatever the user
  /// just typed. The keypad only shows while no text field has focus,
  /// including a split row's amount field.
  bool get _textFieldFocused =>
      _noteFocus.hasFocus ||
      _payeeFocus.hasFocus ||
      _splitRows.any((r) => r.focusNode.hasFocus);

  @override
  void initState() {
    super.initState();
    // Only expense/income are ever meaningful here — anything else (or
    // nothing) falls back to the screen's own default.
    final initial = widget.initialType;
    _type =
        (!_isEditing && (initial == TxType.expense || initial == TxType.income))
        ? initial!
        : TxType.expense;
    _noteFocus.addListener(_onFieldFocusChanged);
    _payeeFocus.addListener(_onFieldFocusChanged);
    if (_isEditing) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  void _onFieldFocusChanged() => setState(() {});

  static void _deleteQuietly(String path) {
    File(path).delete().ignore();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    _payeeController.dispose();
    _payeeFocus.dispose();
    for (final row in _splitRows) {
      row.dispose();
    }
    // Best-effort: leaving without saving shouldn't leak the copy made on
    // pick. Fire-and-forget — nothing in this widget survives to await it.
    if (_unsavedPickedPath != null) _deleteQuietly(_unsavedPickedPath!);
    super.dispose();
  }

  /// Fetch the row being edited and prefill every field from it.
  Future<void> _loadForEdit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final db = ref.read(dbProvider);
    final row = await db.transactionById(widget.transactionId!);
    final tagIds = await db.tagIdsForTransaction(widget.transactionId!);
    final splits = await db.splitsForTransaction(widget.transactionId!);
    if (!mounted) return;

    if (row == null) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction not found')),
      );
      return;
    }

    // This screen only offers Expense / Income / Transfer. A person movement
    // has no segment, and `SegmentedButton` asserts that its selected value is
    // one of its segments — assigning it here would crash the screen. A
    // repayment marked to count as income reads as ordinary `TxType.income`,
    // so it needs its own check — see `isPersonLinkedTransaction`.
    final isPersonLinked =
        row.type.isPersonMovement ||
        (row.type.isIncomeOrExpense &&
            await db.isPersonLinkedTransaction(row.id));
    if (!mounted) return;
    if (isPersonLinked) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Edit this from the person\'s page.')),
      );
      return;
    }

    setState(() {
      _type = row.type;
      _buffer = _bufferFromMoney(row.amount);
      _accountId = row.accountId;
      _toAccountId = row.toAccountId;
      _categoryId = row.categoryId;
      _date = row.date;
      _noteController.text = row.note ?? '';
      _payeeController.text = row.payee ?? '';
      _tagIds = tagIds.toSet();
      _imagePath = row.imagePath;
      _isSplit = splits.isNotEmpty;
      for (final s in splits) {
        _splitRows.add(
          _SplitEntry(
            categoryId: s.categoryId,
            amountText: _bufferFromMoney(s.amount),
            onFocusChange: _onFieldFocusChanged,
          ),
        );
      }
      _loading = false;
    });
  }

  /// Render a stored amount back into the keypad buffer: plain rupees with up
  /// to two decimals, dropping a trailing `.00` / `.X0`. `1500` paise -> "15",
  /// `1550` -> "15.5", `1555` -> "15.55".
  static String _bufferFromMoney(Money amount) {
    final paise = amount.abs.paise;
    final rupees = paise ~/ 100;
    final fraction = paise % 100;
    if (fraction == 0) return '$rupees';
    if (fraction % 10 == 0) return '$rupees.${fraction ~/ 10}';
    return '$rupees.${fraction.toString().padLeft(2, '0')}';
  }

  /// The live amount. Tolerates a trailing dot while the user is mid-type.
  Money get _amount {
    var b = _buffer;
    if (b.endsWith('.')) b = b.substring(0, b.length - 1);
    return Money.tryParse(b) ?? const Money.zero();
  }

  // ── Keypad ────────────────────────────────────────────────────────────────

  void _onKey(String k) {
    setState(() {
      if (k == '.') {
        if (!_buffer.contains('.')) {
          _buffer = _buffer.isEmpty ? '0.' : '$_buffer.';
        }
        return;
      }
      final dot = _buffer.indexOf('.');
      if (dot != -1 && _buffer.length - dot - 1 >= 2) {
        return; // already two decimal places
      }
      if (_buffer == '0') {
        _buffer = k; // replace a lone leading zero
      } else {
        if (_buffer.replaceAll('.', '').length >= 12) return; // sane cap
        _buffer = '$_buffer$k';
      }
    });
  }

  void _onBackspace() {
    if (_buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickAccount({required bool isFrom}) async {
    final forTo = _type == TxType.transfer && !isFrom;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountPickerSheet(
        title: forTo
            ? 'To account'
            : (_type == TxType.transfer ? 'From account' : 'Account'),
        excludeId: forTo ? _accountId : null,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (forTo) {
        _toAccountId = selected;
      } else {
        _accountId = selected;
        if (_toAccountId == selected) _toAccountId = null;
      }
    });
  }

  Future<void> _pickCategory() async {
    final kind = _type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CategoryPickerSheet(kind: kind),
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryId = selected);
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

  // ── Receipt photo ────────────────────────────────────────────────────────

  Future<void> _pickReceipt() async {
    final path = await ReceiptStorage.pickAndStore();
    if (path == null || !mounted) return;
    // Replacing an already-picked-this-session file before ever saving —
    // that earlier copy is now unreferenced.
    final previous = _unsavedPickedPath;
    setState(() {
      _imagePath = path;
      _unsavedPickedPath = path;
    });
    if (previous != null) _deleteQuietly(previous);
  }

  void _removeReceipt() {
    final previous = _unsavedPickedPath;
    setState(() {
      _imagePath = null;
      _unsavedPickedPath = null;
    });
    if (previous != null) _deleteQuietly(previous);
  }

  /// AppBar shortcut — filled once a receipt is attached. Tapping when empty
  /// opens the picker directly; tapping when attached opens a small preview
  /// sheet with replace/remove, instead of a card buried in the field list.
  Widget _receiptAction(ThemeData theme) {
    final attached = _imagePath != null;
    return IconButton(
      icon: Icon(
        attached ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
        color: attached ? theme.colorScheme.primary : null,
      ),
      tooltip: attached ? 'Receipt attached' : 'Attach receipt',
      onPressed: attached ? _openReceiptSheet : _pickReceipt,
    );
  }

  Future<void> _openReceiptSheet() async {
    final path = _imagePath;
    if (path == null) return;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(path),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 220,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _pickReceipt();
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Replace'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _removeReceipt();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Split expenses ────────────────────────────────────────────────────────

  Future<void> _pickSplitCategory(int index) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CategoryPickerSheet(kind: CategoryKind.expense),
    );
    if (selected == null || !mounted) return;
    setState(() => _splitRows[index].categoryId = selected);
  }

  Widget _splitToggleTile() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: _isSplit,
        onChanged: (v) => setState(() {
          _isSplit = v;
          while (v && _splitRows.length < 2) {
            _splitRows.add(_SplitEntry(onFocusChange: _onFieldFocusChanged));
          }
        }),
        secondary: Icon(
          Icons.call_split_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('Split into categories'),
        subtitle: _isSplit
            ? null
            : const Text('One expense, more than one category'),
      ),
    );
  }

  Widget _splitEditorCard(Map<int, CategoryRow> categoryMap) {
    final theme = Theme.of(context);
    final sum = _splitRows.fold(const Money.zero(), (s, r) => s + r.amount);
    final remaining = _amount - sum;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _splitRows.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _splitRowTile(i, categoryMap),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _splitRows.add(
                    _SplitEntry(onFocusChange: _onFieldFocusChanged),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add category'),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Remaining',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                MoneyText(
                  remaining,
                  signed: true,
                  color: remaining.isZero
                      ? AppColors.income
                      : AppColors.expense,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitRowTile(int index, Map<int, CategoryRow> categoryMap) {
    final theme = Theme.of(context);
    final row = _splitRows[index];
    final cat = categoryMap[row.categoryId];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickSplitCategory(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.resolve(cat?.iconKey ?? 'other'),
                  size: 18,
                  color: cat != null
                      ? Color(cat.colorValue)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 84),
                  child: Text(
                    cat?.name ?? 'Category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: row.amountController,
            focusNode: row.focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              isDense: true,
              prefixText: MoneyFormat.inputPrefix,
              hintText: '0.00',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: 'Remove',
          onPressed: _splitRows.length <= 1
              ? null
              : () => setState(() {
                  _splitRows.removeAt(index).dispose();
                }),
        ),
      ],
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final amount = _amount;

    if (!amount.isPositive) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }
    if (_accountId == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _type == TxType.transfer
                ? 'Choose the account to transfer from'
                : 'Choose an account',
          ),
        ),
      );
      return;
    }
    if (_type == TxType.transfer) {
      if (_toAccountId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Choose the account to transfer to')),
        );
        return;
      }
      if (_toAccountId == _accountId) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Transfer must be between two different accounts'),
          ),
        );
        return;
      }
    } else if (_isSplitting) {
      if (_splitRows.any((r) => r.categoryId == null)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Choose a category for every split')),
        );
        return;
      }
      if (_splitRows.any((r) => !r.amount.isPositive)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Every split needs an amount greater than zero'),
          ),
        );
        return;
      }
      final sum = _splitRows.fold(const Money.zero(), (s, r) => s + r.amount);
      if (sum != amount) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              sum < amount
                  ? 'Splits are short by ${MoneyFormat.symbol(amount - sum)}'
                  : 'Splits are over by ${MoneyFormat.symbol(sum - amount)}',
            ),
          ),
        );
        return;
      }
    } else if (_categoryId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose a category')),
      );
      return;
    }

    final note = _noteController.text.trim();
    final payeeText = _payeeController.text.trim();
    final payee = _type == TxType.expense && payeeText.isNotEmpty
        ? payeeText
        : null;
    // A split expense has no single category of its own — see
    // AppDatabase.setTransactionSplits.
    final categoryId = (_type == TxType.transfer || _isSplitting)
        ? null
        : _categoryId;
    try {
      final db = ref.read(dbProvider);
      int id;
      if (_isEditing) {
        id = widget.transactionId!;
        await db.updateTransaction(
          id: id,
          type: _type,
          amount: amount,
          accountId: _accountId!,
          toAccountId: _type == TxType.transfer ? _toAccountId : null,
          categoryId: categoryId,
          date: _date,
          note: note.isEmpty ? null : note,
          payee: payee,
          imagePath: _imagePath,
        );
      } else {
        id = await db.addTransaction(
          type: _type,
          amount: amount,
          accountId: _accountId!,
          toAccountId: _type == TxType.transfer ? _toAccountId : null,
          categoryId: categoryId,
          date: _date,
          note: note.isEmpty ? null : note,
          payee: payee,
          imagePath: _imagePath,
        );
      }
      // The receipt (if any) is now referenced by a saved row — no longer an
      // orphan `dispose()` needs to clean up.
      _unsavedPickedPath = null;
      await db.setTransactionTags(id, _tagIds);
      await db.setTransactionSplits(
        id,
        _isSplitting
            ? [
                for (final r in _splitRows)
                  (categoryId: r.categoryId!, amount: r.amount),
              ]
            : const [],
      );
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? 'Could not save transaction'),
        ),
      );
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Updated' : 'Saved')),
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    // Capture before the first await — never touch `context` across the gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text('The amount will be added back to your balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(dbProvider).deleteTransaction(widget.transactionId!);
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message?.toString() ?? 'Could not delete')),
      );
      return;
    }
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Transaction deleted')),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountMap = ref.watch(accountMapProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final amount = _amount;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_isEditing ? 'Edit' : 'Add'),
        // Tags and receipt live here, not buried at the bottom of the
        // scrollable field list, so they stay reachable in one tap no matter
        // how far the user has scrolled or whether the keypad is covering
        // the rest of the screen.
        actions: _loading
            ? null
            : [
                _tagsAction(theme),
                _receiptAction(theme),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: _confirmDelete,
                  ),
                TextButton(onPressed: _save, child: const Text('Save')),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: GestureDetector(
                // Tapping anywhere that isn't Note/Payee drops their focus, so
                // the system keyboard closes and the amount keypad returns —
                // the two must never be on screen at once (see _textFieldFocused).
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<TxType>(
                          segments: const [
                            ButtonSegment(
                              value: TxType.expense,
                              label: Text('Expense'),
                            ),
                            ButtonSegment(
                              value: TxType.income,
                              label: Text('Income'),
                            ),
                            ButtonSegment(
                              value: TxType.transfer,
                              label: Text('Transfer'),
                            ),
                          ],
                          selected: {_type},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => setState(() {
                            _type = s.first;
                            // category is meaningless on type change
                            _categoryId = null;
                            if (_type != TxType.transfer) _toAccountId = null;
                            // Split is expense-only.
                            if (_type != TxType.expense) {
                              _isSplit = false;
                            }
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          MoneyFormat.symbol(amount),
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorForTxType(_type),
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ),
                    ),
                    _selectedTagsChips(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildPickers(accountMap, categoryMap),
                        ),
                      ),
                    ),
                    if (!_textFieldFocused) _buildKeypad(theme),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildPickers(
    Map<int, AccountRow> accountMap,
    Map<int, CategoryRow> categoryMap,
  ) {
    final tiles = <Widget>[];

    if (_type == TxType.transfer) {
      tiles.add(
        _pickerTile(
          icon: AppIcons.resolve('bank'),
          label: 'From account',
          value: accountMap[_accountId]?.name ?? 'Select account',
          selected: _accountId != null,
          onTap: () => _pickAccount(isFrom: true),
        ),
      );
      tiles.add(const SizedBox(height: 12));
      tiles.add(
        _pickerTile(
          icon: AppIcons.resolve('transfer'),
          label: 'To account',
          value: accountMap[_toAccountId]?.name ?? 'Select account',
          selected: _toAccountId != null,
          onTap: () => _pickAccount(isFrom: false),
        ),
      );
    } else {
      tiles.add(
        _pickerTile(
          icon: AppIcons.resolve('wallet'),
          label: _type == TxType.income ? 'Deposit to' : 'Paid via',
          value: accountMap[_accountId]?.name ?? 'Select account',
          selected: _accountId != null,
          onTap: () => _pickAccount(isFrom: true),
        ),
      );
      tiles.add(const SizedBox(height: 12));
      if (_type == TxType.expense) {
        tiles.add(_splitToggleTile());
        tiles.add(const SizedBox(height: 12));
      }
      if (_isSplitting) {
        tiles.add(_splitEditorCard(categoryMap));
      } else {
        final cat = categoryMap[_categoryId];
        final parent = cat?.parentId == null
            ? null
            : categoryMap[cat!.parentId];
        tiles.add(
          _pickerTile(
            icon: AppIcons.resolve(cat?.iconKey ?? 'other'),
            label: 'Category',
            value: cat == null
                ? 'Select category'
                : parent == null
                ? cat.name
                : '${parent.name} › ${cat.name}',
            selected: _categoryId != null,
            onTap: _pickCategory,
          ),
        );
      }
    }

    tiles.add(const SizedBox(height: 12));
    tiles.add(
      _pickerTile(
        icon: Icons.event_outlined,
        label: 'Date',
        value: DateFormat('d MMM yyyy').format(_date),
        selected: true,
        onTap: _pickDate,
      ),
    );
    if (_type == TxType.expense) {
      tiles.add(const SizedBox(height: 12));
      tiles.add(_payeeCard());
    }
    tiles.add(const SizedBox(height: 12));
    tiles.add(_noteCard());
    return tiles;
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _noteCard() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _noteController,
          focusNode: _noteFocus,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Note (optional)',
            border: InputBorder.none,
            icon: Icon(
              Icons.notes_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// Expense only. Free text with autocomplete drawn from payees used before —
  /// optional, so leaving it blank is a normal, unremarkable choice.
  Widget _payeeCard() {
    final theme = Theme.of(context);
    final suggestions = ref.watch(payeeSuggestionsProvider);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Autocomplete<String>(
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
              decoration: InputDecoration(
                hintText: 'Payee (optional) — who did you pay?',
                border: InputBorder.none,
                icon: Icon(
                  Icons.storefront_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// AppBar shortcut — badged with the count once any tag is picked. Cuts
  /// across category/account and opens the same multi-select sheet as before.
  Widget _tagsAction(ThemeData theme) {
    final count = _tagIds.length;
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: Icon(count > 0 ? Icons.sell_rounded : Icons.sell_outlined),
      ),
      tooltip: 'Tags',
      onPressed: _pickTags,
    );
  }

  /// Picked tags shown as chips right under the amount — visible at a glance
  /// without opening the picker sheet again, and without eating space in the
  /// scrollable field list below.
  Widget _selectedTagsChips() {
    final tagMap = ref.watch(tagMapProvider);
    final selected = [
      for (final id in _tagIds)
        if (tagMap[id] != null) tagMap[id]!,
    ]..sort((a, b) => a.name.compareTo(b.name));
    if (selected.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in selected)
            InkWell(
              onTap: _pickTags,
              borderRadius: BorderRadius.circular(20),
              child: Chip(
                label: Text(tag.name),
                backgroundColor: Color(tag.colorValue).withValues(alpha: 0.15),
                labelStyle: TextStyle(color: Color(tag.colorValue)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide.none,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickTags() async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagPickerSheet(initiallySelected: _tagIds),
    );
    if (result == null || !mounted) return;
    setState(() => _tagIds = result);
  }

  Widget _buildKeypad(ThemeData theme) {
    const keys = <String>[
      '1', '2', '3', //
      '4', '5', '6', //
      '7', '8', '9', //
      '.', '0', '<', //
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 4; r++)
            Row(
              children: [
                for (var c = 0; c < 3; c++)
                  Expanded(child: _keypadButton(theme, keys[r * 3 + c])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _keypadButton(ThemeData theme, String k) {
    final isBackspace = k == '<';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => isBackspace ? _onBackspace() : _onKey(k),
        child: SizedBox(
          height: 56,
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: theme.colorScheme.onSurface,
                  )
                : Text(k, style: theme.textTheme.titleLarge),
          ),
        ),
      ),
    );
  }
}

/// A round badge showing an account/category icon on its own stored colour.
Widget _iconCircle(String iconKey, int colorValue, {double size = 40}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Color(colorValue), shape: BoxShape.circle),
    child: Icon(
      AppIcons.resolve(iconKey),
      color: Colors.white,
      size: size * 0.5,
    ),
  );
}

/// Bottom sheet: pick an account (or a debit-card instrument) to pay/receive
/// with. Debit cards are selectable but show the bank they draw from instead of
/// a balance.
class _AccountPickerSheet extends ConsumerWidget {
  const _AccountPickerSheet({required this.title, this.excludeId});

  final String title;
  final int? excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsProvider);
    final accountMap = ref.watch(accountMapProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            Flexible(
              child: accountsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load accounts.\n$e',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (accounts) {
                  final list = accounts
                      .where((a) => a.id != excludeId)
                      .toList();
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No accounts available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final a = list[i];
                      final isDebitCard = a.linkedAccountId != null;
                      final linkedName = a.linkedAccountId == null
                          ? null
                          : accountMap[a.linkedAccountId]?.name;
                      return ListTile(
                        leading: _iconCircle(a.iconKey, a.colorValue),
                        title: Text(a.name),
                        subtitle: isDebitCard
                            ? Text('Draws from ${linkedName ?? 'linked bank'}')
                            : null,
                        trailing: isDebitCard
                            ? null
                            : BalanceText(a.currentBalance),
                        onTap: () => Navigator.of(context).pop(a.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a category, as a grid of coloured chips. Only shown for
/// income/expense — a transfer has no category.
///
/// Two levels deep: the first grid is the top-level categories. Tapping one that
/// has subcategories drills into a second grid of its children (with a "Use
/// [parent]" chip to pick the parent directly); a childless one is picked on the
/// spot. Popping returns the chosen category id.
class _CategoryPickerSheet extends ConsumerStatefulWidget {
  const _CategoryPickerSheet({required this.kind});

  final CategoryKind kind;

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  /// Non-null while drilled into a parent's subcategories.
  int? _drillParentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catsAsync = ref.watch(categoriesProvider(widget.kind));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: catsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Could not load categories.\n$e',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          data: (cats) => _content(theme, cats),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme, List<CategoryRow> cats) {
    if (cats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No categories yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final childrenByParent = <int, List<CategoryRow>>{};
    for (final c in cats) {
      if (c.parentId != null) {
        (childrenByParent[c.parentId!] ??= []).add(c);
      }
    }

    final drillParent = _drillParentId == null
        ? null
        : cats.where((c) => c.id == _drillParentId).firstOrNull;

    // The list of cells to render, and the header, depend on the level.
    final Widget header;
    final List<Widget> cells;
    if (drillParent == null) {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Text(
          widget.kind == CategoryKind.income ? 'Income category' : 'Category',
          style: theme.textTheme.titleLarge,
        ),
      );
      cells = [
        for (final c in cats.where((c) => c.parentId == null))
          _cell(
            theme,
            iconKey: c.iconKey,
            colorValue: c.colorValue,
            label: c.name,
            hasChildren: (childrenByParent[c.id]?.isNotEmpty) ?? false,
            onTap: () {
              if ((childrenByParent[c.id]?.isNotEmpty) ?? false) {
                setState(() => _drillParentId = c.id);
              } else {
                Navigator.of(context).pop(c.id);
              }
            },
          ),
      ];
    } else {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 20, 12),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'All categories',
              onPressed: () => setState(() => _drillParentId = null),
            ),
            Expanded(
              child: Text(
                drillParent.name,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      cells = [
        // Pick the parent itself, not one of its children.
        _cell(
          theme,
          iconKey: drillParent.iconKey,
          colorValue: drillParent.colorValue,
          label: 'All ${drillParent.name}',
          onTap: () => Navigator.of(context).pop(drillParent.id),
        ),
        for (final c in childrenByParent[drillParent.id] ?? const [])
          _cell(
            theme,
            iconKey: c.iconKey,
            colorValue: c.colorValue,
            label: c.name,
            onTap: () => Navigator.of(context).pop(c.id),
          ),
      ];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Flexible(
          child: GridView.count(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
            children: cells,
          ),
        ),
      ],
    );
  }

  /// One tappable category chip. A small dot marks a parent that opens into
  /// subcategories rather than being picked directly.
  Widget _cell(
    ThemeData theme, {
    required String iconKey,
    required int colorValue,
    required String label,
    required VoidCallback onTap,
    bool hasChildren = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _iconCircle(iconKey, colorValue, size: 52),
              if (hasChildren)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet: pick any number of tags as toggleable filter chips. New tags
/// are created from **More → Tags**, not from here — this sheet only selects.
class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.initiallySelected});

  final Set<int> initiallySelected;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(tagsProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Tags', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: tagsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load tags.\n$e',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                data: (tags) {
                  if (tags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No tags yet — add one from More → Tags.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            label: Text(tag.name),
                            selected: _selected.contains(tag.id),
                            selectedColor: Color(
                              tag.colorValue,
                            ).withValues(alpha: 0.22),
                            checkmarkColor: Color(tag.colorValue),
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selected.add(tag.id);
                              } else {
                                _selected.remove(tag.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
