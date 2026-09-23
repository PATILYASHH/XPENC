import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/amount_keypad_field.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/icon_picker_sheet.dart';
import '../../core/widgets/money_text.dart';
import '../../data/currency_conversion.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../accounts/envelope_outflow.dart';
import '../settings/currency_picker_sheet.dart';
import '../tags/tag_picker_sheet.dart';
import 'date_time_combine.dart';
import 'receipt_storage.dart';

/// One editable row of a split expense: which category, and how much of the
/// total it takes. Holds its own [AmountKeypadController] so its buffer text
/// (and which row is the shared keypad's current target — see
/// [_AddTransactionScreenState._activeAmountCtrl]) keeps its identity across
/// rebuilds.
class _SplitEntry {
  _SplitEntry({this.categoryId, Money? amount})
    : amountCtrl = AmountKeypadController() {
    if (amount != null) amountCtrl.setAmount(amount);
  }

  int? categoryId;
  final AmountKeypadController amountCtrl;

  Money get amount => amountCtrl.amount;

  void dispose() => amountCtrl.dispose();
}

/// One leg of a hybrid/split payment: which account, and how much of the
/// total it covers. Same shape as [_SplitEntry], but an account instead of
/// a category — see GitHub #43.
class _PaymentLegEntry {
  _PaymentLegEntry() : amountCtrl = AmountKeypadController();

  int? accountId;
  final AmountKeypadController amountCtrl;

  Money get amount => amountCtrl.amount;

  void dispose() => amountCtrl.dispose();
}

/// The ➕ route. Expense / Income / Transfer.
///
/// A transfer is neither income nor expense: it never carries a category and
/// always moves money between two different accounts.
///
/// With a [transactionId] the screen edits that existing transaction instead
/// of creating a new one.
///
/// With a [duplicateFromId] instead, every field is prefilled from that
/// transaction — same as editing — but [transactionId] stays null, so Save
/// creates a brand-new row rather than touching the source (GitHub #92:
/// "publish another one" of an existing transaction). The date resets to
/// today rather than copying the source's, nudging the user to notice this
/// is a separate entry and pick the date it actually happened on; the
/// receipt photo is never copied, since it's evidence of the original
/// purchase, not this new one.
///
/// With a [templateId] instead, fields are prefilled the same way from a
/// saved [TransactionTemplateRow] (GitHub #125) rather than a live
/// transaction — reached by picking a template from the ➕ button's choice
/// sheet. Same as duplicating: the date is always today, and there is no
/// receipt to carry over.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    this.transactionId,
    this.duplicateFromId,
    this.templateId,
    this.initialType,
    this.initialPayee,
    this.initialNote,
    this.initialAmount,
    super.key,
  });

  final int? transactionId;
  final int? duplicateFromId;
  final int? templateId;

  /// Preselects Expense or Income — used by the home-screen widget's "+
  /// Expense" / "+ Income" shortcuts to skip the type-picker step. Ignored
  /// when [transactionId], [duplicateFromId] or [templateId] is set, since
  /// all three load their own type.
  final TxType? initialType;

  /// Prefills the payee/note/amount fields — used by the "Pay without
  /// internet" (*99#) flow to hand off what it already collected instead of
  /// making the user retype it. Ignored (like [initialType]) once
  /// [transactionId], [duplicateFromId] or [templateId] is set, since all
  /// three load their own values. All three are freely editable afterward,
  /// same as any other field on this screen.
  final String? initialPayee;
  final String? initialNote;
  final Money? initialAmount;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late TxType _type;

  /// The main amount's buffer — same [AmountKeypadController] used for every
  /// other money field on this screen, so a prefilled edit value ("15.44")
  /// is replaced wholesale by the first keypad tap instead of appended to
  /// (see GitHub #45; the `freshEntry` contract now lives on the controller).
  final _mainAmountCtrl = AmountKeypadController();

  /// Which money field the single shared keypad (see [_buildKeypad]) is
  /// currently editing — the main amount, a split row, a hybrid leg, or the
  /// foreign/change amount. Tapping any amount field's display box makes it
  /// the target; defaults to the main amount.
  late AmountKeypadController _activeAmountCtrl;

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

  /// Expense only — one expense, several *accounts*, instead of one (see
  /// GitHub #43). Mutually exclusive with [_isSplit] — combining both is a
  /// 2-D matrix this screen doesn't offer. Creation only: editing an
  /// existing hybrid payment's legs together isn't supported here, since
  /// each leg is its own transaction row, not sub-rows of one — see
  /// `AppDatabase.addHybridPaymentTransaction`.
  bool _isHybridPayment = false;
  final List<_PaymentLegEntry> _hybridLegs = [];

  /// Expense only, paid from a cash account — some of the change received
  /// lands in a different account instead of back in the paying one (e.g.
  /// coins into a separate "Coins" account) — see GitHub #55. Mutually
  /// exclusive with [_isSplit] / [_isHybridPayment], same reasoning as those.
  /// Creation only, same reasoning as [_isHybridPayment].
  bool _hasChange = false;
  int? _changeAccountId;
  final _changeAmountCtrl = AmountKeypadController();

  /// Income/expense only — "this was originally paid in another currency"
  /// (GitHub #85), purely informational: [_amount] stays what actually moved
  /// through the account. Unlike hybrid payment/change, this can be edited
  /// after the fact, so it isn't gated on `!_isEditing`. Mutually exclusive
  /// with hybrid payment and change (same toggle group); coexists with
  /// split, since a split doesn't touch the transaction's own amount/currency.
  bool _hasForeignCurrency = false;
  String? _foreignCurrencyCode;
  final _foreignAmountCtrl = AmountKeypadController();

  /// The receipt path that will be saved — an existing one loaded for
  /// editing, a freshly picked one, or null.
  String? _imagePath;

  /// Set only when [_imagePath] was picked *this session* and not yet saved —
  /// so `dispose()` can clean it up if the screen is left without saving,
  /// rather than leaking a copy nothing will ever reference.
  String? _unsavedPickedPath;

  /// A per-transaction visual marker independent of [_categoryId] — see the
  /// doc on `Transactions.customIcon` for its two encodings. Cuts across
  /// category/account/type, same as [_tagIds]; null means none picked.
  String? _customIcon;

  /// True while an existing transaction is being fetched for editing.
  bool _loading = false;

  bool get _isEditing => widget.transactionId != null;

  /// Split only ever applies to an expense — [_isSplit] can be stale after a
  /// type switch (kept around so toggling back doesn't lose entered rows).
  bool get _isSplitting => _type == TxType.expense && _isSplit;

  /// Hybrid payment only ever applies to a brand-new expense — see the doc
  /// on [_isHybridPayment].
  bool get _isHybrid =>
      _type == TxType.expense && !_isEditing && _isHybridPayment;

  /// Change only ever applies to a brand-new cash expense — see the doc on
  /// [_hasChange]. Re-checks the account's type (not just [_hasChange])
  /// so switching "Paid via" away from a cash account hides the editor
  /// along with the toggle, instead of leaving it stranded on screen —
  /// [_hasChange] itself is left untouched, same reasoning as [_isSplitting]
  /// staying stale-but-harmless across a type switch.
  bool get _isChange =>
      _type == TxType.expense &&
      !_isEditing &&
      _hasChange &&
      ref.read(accountMapProvider)[_accountId]?.type == AccountType.cash;

  Money get _changeAmount => _changeAmountCtrl.amount;

  /// Foreign currency only ever applies to an income or expense — a transfer
  /// moves money between the user's own accounts, with nothing "paid" in
  /// another currency.
  bool get _isForeignCurrency =>
      (_type == TxType.income || _type == TxType.expense) &&
      _hasForeignCurrency;

  Money get _foreignAmount => _foreignAmountCtrl.amount;

  /// The custom keypad and the system keyboard must never both be up — they'd
  /// fight over the same strip of screen and hide whatever the user just
  /// typed. Every money field on this screen (main amount, split rows,
  /// hybrid legs, foreign, change) now shares the same in-app keypad instead
  /// of the OS keyboard (see GitHub #135), so the only real `TextField`s left
  /// here are Note and Payee — the keypad only hides while one of those has
  /// focus.
  bool get _textFieldFocused => _noteFocus.hasFocus || _payeeFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _activeAmountCtrl = _mainAmountCtrl;
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
    } else if (widget.duplicateFromId != null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForDuplicate());
    } else if (widget.templateId != null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForTemplate());
    } else {
      if (widget.initialPayee != null) {
        _payeeController.text = widget.initialPayee!;
      }
      if (widget.initialNote != null) {
        _noteController.text = widget.initialNote!;
      }
      if (widget.initialAmount != null) {
        _mainAmountCtrl.setAmount(widget.initialAmount!);
      }
      // Pre-select the last-used account on a brand-new transaction, once the
      // one-shot query resolves. Still freely changeable via "Paid via", and
      // the guard on `_accountId` below means it never overwrites a
      // selection the user already made while this was loading.
      _seedLastUsedAccount();
    }
  }

  Future<void> _seedLastUsedAccount() async {
    final txs = await ref.read(dbProvider).watchTransactions(limit: 1).first;
    if (!mounted || _accountId != null || txs.isEmpty) return;
    setState(() => _accountId = txs.first.accountId);
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
    for (final leg in _hybridLegs) {
      leg.dispose();
    }
    _mainAmountCtrl.dispose();
    _changeAmountCtrl.dispose();
    _foreignAmountCtrl.dispose();
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
      _mainAmountCtrl.setAmount(row.amount);
      _accountId = row.accountId;
      _toAccountId = row.toAccountId;
      _categoryId = row.categoryId;
      _date = row.date;
      _noteController.text = row.note ?? '';
      _payeeController.text = row.payee ?? '';
      _tagIds = tagIds.toSet();
      _imagePath = row.imagePath;
      _customIcon = row.customIcon;
      _isSplit = splits.isNotEmpty;
      for (final s in splits) {
        _splitRows.add(
          _SplitEntry(categoryId: s.categoryId, amount: s.amount),
        );
      }
      _hasForeignCurrency = row.foreignAmount != null;
      _foreignCurrencyCode = row.foreignCurrencyCode;
      if (row.foreignAmount != null) {
        _foreignAmountCtrl.setAmount(row.foreignAmount!);
      }
      _loading = false;
    });
  }

  /// Fetch the transaction being duplicated and prefill every field from it,
  /// same as [_loadForEdit] — except [_date] resets to today instead of
  /// copying the source's, and the receipt (if any) is never carried over.
  /// [widget.transactionId] stays null throughout, so `_save` inserts a new
  /// row instead of updating the source.
  Future<void> _loadForDuplicate() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final db = ref.read(dbProvider);
    final sourceId = widget.duplicateFromId!;
    final row = await db.transactionById(sourceId);
    final tagIds = await db.tagIdsForTransaction(sourceId);
    final splits = await db.splitsForTransaction(sourceId);
    if (!mounted) return;

    if (row == null) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction not found')),
      );
      return;
    }

    // Same restriction as `_loadForEdit`: this screen has no shape for a
    // person movement (or a repayment counted as income), so there is
    // nothing sensible to prefill it into.
    final isPersonLinked =
        row.type.isPersonMovement ||
        (row.type.isIncomeOrExpense &&
            await db.isPersonLinkedTransaction(row.id));
    if (!mounted) return;
    if (isPersonLinked) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text("This can't be duplicated from here.")),
      );
      return;
    }

    setState(() {
      _type = row.type;
      _mainAmountCtrl.setAmount(row.amount);
      _accountId = row.accountId;
      _toAccountId = row.toAccountId;
      _categoryId = row.categoryId;
      _noteController.text = row.note ?? '';
      _payeeController.text = row.payee ?? '';
      _tagIds = tagIds.toSet();
      _customIcon = row.customIcon;
      _isSplit = splits.isNotEmpty;
      for (final s in splits) {
        _splitRows.add(
          _SplitEntry(categoryId: s.categoryId, amount: s.amount),
        );
      }
      _hasForeignCurrency = row.foreignAmount != null;
      _foreignCurrencyCode = row.foreignCurrencyCode;
      if (row.foreignAmount != null) {
        _foreignAmountCtrl.setAmount(row.foreignAmount!);
      }
      _loading = false;
    });
  }

  /// Fetch the saved template and prefill every field it carries — same
  /// shape as [_loadForDuplicate], minus splits and foreign currency, which
  /// no [TransactionTemplateRow] stores (see its own doc comment).
  /// [widget.transactionId] stays null throughout, so `_save` inserts a new
  /// row rather than touching anything.
  Future<void> _loadForTemplate() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final db = ref.read(dbProvider);
    final row = await db.transactionTemplateById(widget.templateId!);
    if (!mounted) return;

    if (row == null) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Template not found')),
      );
      return;
    }

    final tagIds = await db.tagIdsForTemplate(widget.templateId!);
    if (!mounted) return;

    setState(() {
      _type = row.type;
      _mainAmountCtrl.setAmount(row.amount);
      _accountId = row.accountId;
      _toAccountId = row.toAccountId;
      _categoryId = row.categoryId;
      _noteController.text = row.note ?? '';
      _payeeController.text = row.payee ?? '';
      _tagIds = tagIds.toSet();
      _loading = false;
    });
  }

  /// The live main amount. Tolerates a trailing dot while the user is
  /// mid-type.
  Money get _amount => _mainAmountCtrl.amount;

  // ── Keypad ────────────────────────────────────────────────────────────────

  /// Makes [ctrl] the shared keypad's target and brings the keypad back if
  /// Note/Payee had stolen focus — every amount field's display box calls
  /// this on tap.
  void _activateAmountCtrl(AmountKeypadController ctrl) {
    FocusScope.of(context).unfocus();
    setState(() => _activeAmountCtrl = ctrl);
  }

  void _onKey(String k) => setState(() => _activeAmountCtrl.applyKey(k));

  void _onBackspace() => setState(() => _activeAmountCtrl.applyBackspace());

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
        // A goal isn't a spendable account — it's only funded or drawn down
        // by a transfer. Hide it from expense/income pickers entirely.
        excludeGoals: _type != TxType.transfer,
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
      builder: (_) => _CategoryPickerSheet(
        kind: kind,
        envelopeAccountId: _envelopeAccountId,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryId = selected);
  }

  /// The currency [accountId] actually posts in — null for the parent
  /// currency, same "null means parent" convention as
  /// [AccountRow.currencyCode] itself. A debit/UPI instrument has no
  /// currency of its own (see `tables.dart`'s doc on `Accounts.currencyCode`)
  /// so this follows [AccountRow.linkedAccountId] once to the account that
  /// actually holds the money.
  Currency? _currencyForAccount(
    int? accountId,
    Map<int, AccountRow> accountMap,
  ) {
    final account = accountMap[accountId];
    if (account == null) return null;
    final code = account.linkedAccountId == null
        ? account.currencyCode
        : accountMap[account.linkedAccountId]?.currencyCode;
    return code == null ? null : currencyForCode(code);
  }

  /// An informational "≈ X received" line for a transfer between two
  /// accounts that don't share a currency — read-only, purely a preview of
  /// what `AppDatabase.addTransaction` will itself compute and store as
  /// `toAmount` at save time (see its `_resolveTxCurrency`/cross-currency
  /// logic), using whatever rate is current right now. `null` whenever
  /// there's nothing to preview: not a transfer, no destination picked yet,
  /// both legs share a currency, the amount is still zero, or a needed rate
  /// hasn't loaded/been entered yet — the save button itself is the one
  /// source of truth for whether posting will actually succeed.
  Widget? _crossCurrencyTransferPreview(Map<int, AccountRow> accountMap) {
    if (_type != TxType.transfer || _toAccountId == null) return null;
    final sourceCurrency = _currencyForAccount(_accountId, accountMap);
    final destCurrency = _currencyForAccount(_toAccountId, accountMap);
    if (sourceCurrency?.code == destCurrency?.code) return null;

    final amount = _amount;
    if (!amount.isPositive) return null;

    final rates = ref.watch(currencyRatesProvider).valueOrNull;
    if (rates == null) return null;
    final rateFor = {for (final r in rates) r.currencyCode: r.rateToBaseMicros};

    Money sourceBase;
    if (sourceCurrency == null) {
      sourceBase = amount;
    } else {
      final rate = rateFor[sourceCurrency.code];
      if (rate == null) return null;
      sourceBase = convertUsingRate(amount, rate);
    }

    Money destAmount;
    if (destCurrency == null) {
      destAmount = sourceBase;
    } else {
      final rate = rateFor[destCurrency.code];
      if (rate == null) return null;
      destAmount = Money((sourceBase.paise * currencyRateScale) ~/ rate);
    }

    final theme = Theme.of(context);
    final formatted = destCurrency == null
        ? MoneyFormat.symbol(destAmount)
        : MoneyFormat.symbolIn(destAmount, destCurrency);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '≈ $formatted received, at today\'s rate',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// A small note when this expense/transfer would take its source account
  /// below the floor set on [AccountRow.minimumBalance] — purely
  /// informational, never blocks Save (see the doc on that column). Creation
  /// only: an existing transaction's amount has already been applied to
  /// [AccountRow.currentBalance] once, so re-subtracting it here would
  /// double-count and could warn (or fail to warn) wrongly.
  Widget? _minimumBalanceWarning(Map<int, AccountRow> accountMap) {
    if (_isEditing) return null;
    if (_type != TxType.expense && _type != TxType.transfer) return null;
    final account = accountMap[_accountId];
    final minimumBalance = account?.minimumBalance;
    if (account == null || minimumBalance == null) return null;
    final amount = _amount;
    if (!amount.isPositive) return null;

    final projected = account.currentBalance - amount;
    if (!(projected < minimumBalance)) return null;

    final theme = Theme.of(context);
    final currency = _currencyForAccount(_accountId, accountMap);
    final formattedMin = currency == null
        ? MoneyFormat.symbol(minimumBalance)
        : MoneyFormat.symbolIn(minimumBalance, currency);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'This takes ${account.name} below your minimum balance of '
              '$formattedMin.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Non-null only for an expense on an Envelope Mode account — the signal
  /// [_CategoryPickerSheet] uses to show each category's remaining balance
  /// inline instead of just its name.
  int? get _envelopeAccountId {
    if (_type != TxType.expense || _accountId == null) return null;
    final account = ref.read(accountMapProvider)[_accountId];
    return (account?.envelopeMode ?? false) ? _accountId : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _date = combineDateAndTime(picked, TimeOfDay.fromDateTime(_date)),
    );
  }

  /// Optional — most transactions never need this touched at all. Lets
  /// someone correct the exact time when they log an expense later than it
  /// actually happened (GitHub #124), without needing to re-pick the date.
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = combineDateAndTime(_date, picked));
  }

  // ── Custom icon / emoji ──────────────────────────────────────────────────

  /// AppBar shortcut, next to the tags button — filled with the picked
  /// icon/emoji once one is set. Tapping when empty opens the source choice
  /// sheet directly; tapping when set opens a small preview sheet with
  /// change/remove, same shape as [_receiptAction]/[_openReceiptSheet].
  Widget _customIconAction(ThemeData theme) {
    final value = _customIcon;
    return IconButton(
      icon: value == null
          ? Icon(
              Icons.emoji_emotions_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : CustomIconBadge(value: value, size: 26),
      tooltip: value == null ? 'Add an icon or emoji' : 'Icon set',
      onPressed: value == null ? _pickCustomIcon : _openCustomIconSheet,
    );
  }

  Future<void> _pickCustomIcon() async {
    final choice = await showModalBottomSheet<_CustomIconSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('XPENC icon'),
              subtitle: const Text('Pick from the app\'s own icon library'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_CustomIconSource.library),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('Emoji'),
              subtitle: const Text('Type one with your keyboard\'s emoji key'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_CustomIconSource.emoji),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _CustomIconSource.library) {
      final key = await showIconPickerSheet(
        context,
        selected: _customIcon == null
            ? null
            : CustomIconBadge.iconKeyOf(_customIcon!),
      );
      if (key == null || !mounted) return;
      setState(() => _customIcon = CustomIconBadge.encodeIconKey(key));
    } else {
      final emoji = await _pickEmoji();
      if (emoji == null || emoji.isEmpty || !mounted) return;
      setState(() => _customIcon = emoji);
    }
  }

  /// A plain [TextField] rather than a bundled emoji browser — focusing it
  /// brings up the user's own keyboard, emoji key included, so this needs no
  /// extra dependency or maintained emoji data set of its own.
  Future<String?> _pickEmoji() async {
    final current = _customIcon;
    final controller = TextEditingController(
      text: (current != null && !CustomIconBadge.isIconKey(current))
          ? current
          : '',
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom:
              MediaQuery.of(sheetContext).padding.bottom +
              MediaQuery.of(sheetContext).viewInsets.bottom +
              20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Emoji',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              // Room for a multi-codepoint emoji (skin tone / ZWJ sequence),
              // not a limit on typing several separate characters.
              maxLength: 8,
              style: const TextStyle(fontSize: 40),
              decoration: const InputDecoration(
                hintText: '🙂',
                counterText: '',
              ),
              onSubmitted: (v) => Navigator.of(sheetContext).pop(v.trim()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(controller.text.trim()),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    // Deliberately not disposed — see the same note in
    // persons_screen.dart's _createGroup: disposing right after showDialog
    // resolves can crash the TextField mid exit-transition.
    return result;
  }

  Future<void> _openCustomIconSheet() async {
    final value = _customIcon;
    if (value == null) return;
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
              CustomIconBadge(value: value, size: 64),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _pickCustomIcon();
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Change'),
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
                        setState(() => _customIcon = null);
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

  // ── Receipt photo ────────────────────────────────────────────────────────

  /// Two ways onto [_pickReceipt]: the camera (needs the `CAMERA` permission,
  /// see PRIVACY.md) or the existing permission-free gallery/file picker.
  Future<void> _showAttachReceiptSheet() async {
    final source = await showModalBottomSheet<_ReceiptSource>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ReceiptSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ReceiptSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickReceipt(source);
  }

  Future<void> _pickReceipt(_ReceiptSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    String? path;
    try {
      path = source == _ReceiptSource.camera
          ? await ReceiptStorage.pickFromCamera()
          : await ReceiptStorage.pickAndStore();
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't open the camera — check its permission in system "
              'settings.',
            ),
          ),
        );
      return;
    }
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
  /// opens the camera/gallery choice sheet; tapping when attached opens a
  /// small preview sheet with replace/remove, instead of a card buried in
  /// the field list.
  Widget _receiptAction(ThemeData theme) {
    final attached = _imagePath != null;
    return IconButton(
      icon: Icon(
        attached ? Icons.camera_alt_rounded : Icons.camera_alt_outlined,
        color: attached ? theme.colorScheme.primary : null,
      ),
      tooltip: attached ? 'Receipt attached' : 'Attach receipt',
      onPressed: attached ? _openReceiptSheet : _showAttachReceiptSheet,
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
                        _showAttachReceiptSheet();
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
      builder: (_) => _CategoryPickerSheet(
        kind: CategoryKind.expense,
        envelopeAccountId: _envelopeAccountId,
      ),
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
          // Splitting by category and by account at once is a 2-D matrix
          // this screen doesn't offer — turning one on turns the other off.
          if (v) {
            _isHybridPayment = false;
            _hasChange = false;
          }
          while (v && _splitRows.length < 2) {
            _splitRows.add(_SplitEntry());
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

  // ── Hybrid payment ───────────────────────────────────────────────────────

  Future<void> _pickHybridLegAccount(int index) async {
    final excludeIds = {
      for (var i = 0; i < _hybridLegs.length; i++)
        if (i != index && _hybridLegs[i].accountId != null)
          _hybridLegs[i].accountId!,
    };
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountPickerSheet(
        title: 'Account',
        excludeGoals: true,
        excludeIds: excludeIds,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _hybridLegs[index].accountId = selected);
  }

  /// Merges what used to be two separate toggle cards
  /// (`_splitToggleTile` / the old hybrid-payment switch) into one: tap
  /// either label and the knob between them slides to that side and turns
  /// it on; tap the active side again and it slides back to the neutral
  /// middle — the shared default, and the only state where neither
  /// [_isSplit] nor [_isHybridPayment] is set. Creation-only, same as
  /// [_isHybridPayment] itself — [_splitToggleTile] above is what an
  /// existing transaction being edited gets instead, since there's nothing
  /// to merge it with there.
  Widget _splitModeToggleTile() {
    final theme = Theme.of(context);
    final mode = _isSplit
        ? _SplitMode.categories
        : (_isHybridPayment ? _SplitMode.accounts : null);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _splitModeLabel(
                    theme,
                    'Split into categories',
                    active: mode == _SplitMode.categories,
                    onTap: () => _setSplitMode(_SplitMode.categories),
                  ),
                ),
                _SplitModeKnob(mode: mode),
                Expanded(
                  child: _splitModeLabel(
                    theme,
                    'Split into accounts',
                    active: mode == _SplitMode.accounts,
                    onTap: () => _setSplitMode(_SplitMode.accounts),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              switch (mode) {
                null => 'One expense — tap either side to split it up',
                _SplitMode.categories => 'One expense, more than one category',
                _SplitMode.accounts =>
                  'One purchase, paid from more than one account',
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _splitModeLabel(
    ThemeData theme,
    String text, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Tapping the side that's already active turns it off (back to the
  /// neutral middle); tapping the other side — or the middle — turns that
  /// side on instead. The on-path for each side keeps exactly the side
  /// effects its old standalone switch had (see the removed
  /// `_hybridToggleTile` / [_splitToggleTile]'s own `onChanged`): split
  /// turns off hybrid and change; hybrid turns off split, change and
  /// foreign currency.
  void _setSplitMode(_SplitMode side) {
    setState(() {
      final currentlyOn = side == _SplitMode.categories
          ? _isSplit
          : _isHybridPayment;
      if (currentlyOn) {
        if (side == _SplitMode.categories) {
          _isSplit = false;
        } else {
          _isHybridPayment = false;
        }
        return;
      }
      if (side == _SplitMode.categories) {
        _isSplit = true;
        _isHybridPayment = false;
        _hasChange = false;
        while (_splitRows.length < 2) {
          _splitRows.add(_SplitEntry());
        }
      } else {
        _isHybridPayment = true;
        _isSplit = false;
        _hasChange = false;
        _hasForeignCurrency = false;
        while (_hybridLegs.length < 2) {
          _hybridLegs.add(_PaymentLegEntry());
        }
      }
    });
  }

  Widget _hybridEditorCard(Map<int, AccountRow> accountMap) {
    final theme = Theme.of(context);
    final sum = _hybridLegs.fold(const Money.zero(), (s, r) => s + r.amount);
    final remaining = _amount - sum;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _hybridLegs.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _hybridLegTile(i, accountMap),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _hybridLegs.add(_PaymentLegEntry())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add account'),
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

  Widget _hybridLegTile(int index, Map<int, AccountRow> accountMap) {
    final theme = Theme.of(context);
    final row = _hybridLegs[index];
    final account = accountMap[row.accountId];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickHybridLegAccount(index),
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
                  AppIcons.resolve(account?.iconKey ?? 'cash'),
                  size: 18,
                  color: account != null
                      ? Color(account.colorValue)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 84),
                  child: Text(
                    account?.name ?? 'Account',
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
          child: AmountKeypadDisplayBox(
            text: row.amountCtrl.text,
            active: identical(_activeAmountCtrl, row.amountCtrl),
            onTap: () => _activateAmountCtrl(row.amountCtrl),
            hintText: '0.00',
            isDense: true,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: 'Remove',
          onPressed: _hybridLegs.length <= 1
              ? null
              : () => setState(() {
                  final removed = _hybridLegs.removeAt(index);
                  if (identical(_activeAmountCtrl, removed.amountCtrl)) {
                    _activeAmountCtrl = _mainAmountCtrl;
                  }
                  removed.dispose();
                }),
        ),
      ],
    );
  }

  // ── Change ────────────────────────────────────────────────────────────────

  Future<void> _pickChangeAccount() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountPickerSheet(
        title: 'Change to account',
        excludeId: _accountId,
        onlyTypes: const {AccountType.cash},
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _changeAccountId = selected);
  }

  Widget _changeToggleTile() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: _hasChange,
        onChanged: (v) => setState(() {
          _hasChange = v;
          if (v) {
            _isSplit = false;
            _isHybridPayment = false;
            _hasForeignCurrency = false;
          }
        }),
        secondary: Icon(
          Icons.currency_exchange_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('Change went elsewhere'),
        subtitle: _hasChange
            ? null
            : const Text('Part of the change lands in another account'),
      ),
    );
  }

  // ── Foreign currency ─────────────────────────────────────────────────────

  Future<void> _pickForeignCurrency() async {
    final picked = await CurrencyPickerSheet.pick(
      context,
      initialCode: _foreignCurrencyCode ?? MoneyFormat.currency.code,
    );
    if (picked == null || !mounted) return;
    setState(() => _foreignCurrencyCode = picked.code);
  }

  Widget _foreignToggleTile() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: _hasForeignCurrency,
        onChanged: (v) => setState(() {
          _hasForeignCurrency = v;
          if (v) {
            _isHybridPayment = false;
            _hasChange = false;
          }
        }),
        secondary: Icon(
          Icons.public_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('Foreign currency'),
        subtitle: _hasForeignCurrency
            ? null
            : const Text('Record what this cost in another currency'),
      ),
    );
  }

  Widget _foreignCurrencyEditorCard() {
    final theme = Theme.of(context);
    final currency = currencyForCode(_foreignCurrencyCode);
    final foreignAmount = _foreignAmount;
    final rateLine = foreignAmount.isPositive
        ? '1 ${currency.code} ≈ '
              '${MoneyFormat.symbol(Money.fromRupees(_amount.rupees / foreignAmount.rupees))}'
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickForeignCurrency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currency.symbol,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(currency.code, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AmountKeypadDisplayBox(
                    text: _foreignAmountCtrl.text,
                    active: identical(_activeAmountCtrl, _foreignAmountCtrl),
                    onTap: () => _activateAmountCtrl(_foreignAmountCtrl),
                    hintText: '0.00',
                    isDense: true,
                    showPrefix: false,
                  ),
                ),
              ],
            ),
            if (rateLine != null) ...[
              const SizedBox(height: 8),
              Text(
                rateLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _changeEditorCard(Map<int, AccountRow> accountMap) {
    final theme = Theme.of(context);
    final account = accountMap[_changeAccountId];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickChangeAccount,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.resolve(account?.iconKey ?? 'cash'),
                      size: 18,
                      color: account != null
                          ? Color(account.colorValue)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: Text(
                        account?.name ?? 'Account',
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
              child: AmountKeypadDisplayBox(
                text: _changeAmountCtrl.text,
                active: identical(_activeAmountCtrl, _changeAmountCtrl),
                onTap: () => _activateAmountCtrl(_changeAmountCtrl),
                hintText: '0.00',
                isDense: true,
              ),
            ),
          ],
        ),
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
                onPressed: () =>
                    setState(() => _splitRows.add(_SplitEntry())),
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
          child: AmountKeypadDisplayBox(
            text: row.amountCtrl.text,
            active: identical(_activeAmountCtrl, row.amountCtrl),
            onTap: () => _activateAmountCtrl(row.amountCtrl),
            hintText: '0.00',
            isDense: true,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: 'Remove',
          onPressed: _splitRows.length <= 1
              ? null
              : () => setState(() {
                  final removed = _splitRows.removeAt(index);
                  if (identical(_activeAmountCtrl, removed.amountCtrl)) {
                    _activeAmountCtrl = _mainAmountCtrl;
                  }
                  removed.dispose();
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

    // Zero is a legitimate income/expense (GitHub #87) — a free item, a
    // discount that fully covers the price, a promo month that costs
    // nothing. A transfer of ₹0 has no real meaning, so that stays
    // strictly positive.
    final amountValid =
        (_type == TxType.income || _type == TxType.expense) && !_isHybrid
        ? !amount.isNegative
        : amount.isPositive;
    if (!amountValid) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_isHybrid) {
      if (_hybridLegs.any((r) => r.accountId == null)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Choose an account for every leg')),
        );
        return;
      }
      if (_hybridLegs.any((r) => !r.amount.isPositive)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Every leg needs an amount greater than zero'),
          ),
        );
        return;
      }
      final sum = _hybridLegs.fold(const Money.zero(), (s, r) => s + r.amount);
      if (sum != amount) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              sum < amount
                  ? 'Accounts are short by ${MoneyFormat.symbol(amount - sum)}'
                  : 'Accounts are over by ${MoneyFormat.symbol(sum - amount)}',
            ),
          ),
        );
        return;
      }
      // No category requirement here — an uncategorised split payment is a
      // legitimate choice, same as an ordinary uncategorised expense below.
      try {
        final db = ref.read(dbProvider);
        final note = _noteController.text.trim();
        final payeeText = _payeeController.text.trim();
        final ids = await db.addHybridPaymentTransaction(
          legs: [
            for (final leg in _hybridLegs)
              (accountId: leg.accountId!, amount: leg.amount),
          ],
          categoryId: _categoryId,
          date: _date,
          note: note.isEmpty ? null : note,
          payee: payeeText.isEmpty ? null : payeeText,
          imagePath: _imagePath,
          customIcon: _customIcon,
        );
        // The receipt (if any) is now referenced by a saved row — no longer
        // an orphan `dispose()` needs to clean up. Tags apply to the anchor
        // leg only, same reasoning as the receipt.
        _unsavedPickedPath = null;
        await db.setTransactionTags(ids.first, _tagIds);
      } on ArgumentError catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e.message?.toString() ?? 'Could not save transaction',
            ),
          ),
        );
        return;
      }
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
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
    if (_isChange) {
      if (_changeAccountId == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Choose where the change goes')),
        );
        return;
      }
      if (!_changeAmount.isPositive) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter how much change goes there')),
        );
        return;
      }
      // No category requirement here either — see the same note on the
      // hybrid-payment path above.
      try {
        final db = ref.read(dbProvider);
        final note = _noteController.text.trim();
        final payeeText = _payeeController.text.trim();
        final ids = await db.addExpenseWithChange(
          amount: amount,
          accountId: _accountId!,
          categoryId: _categoryId,
          changeAccountId: _changeAccountId!,
          changeAmount: _changeAmount,
          date: _date,
          note: note.isEmpty ? null : note,
          payee: payeeText.isEmpty ? null : payeeText,
          imagePath: _imagePath,
          customIcon: _customIcon,
        );
        _unsavedPickedPath = null;
        await db.setTransactionTags(ids.first, _tagIds);
      } on ArgumentError catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              e.message?.toString() ?? 'Could not save transaction',
            ),
          ),
        );
        return;
      }
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
      return;
    }
    int? envelopeShortfallCategoryId;
    var envelopeShortfall = const Money.zero();
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
      // Only a brand-new transfer — editing one that already resolved its
      // own shortfall would otherwise record a second, duplicate allocation
      // on top of the first.
      if (!_isEditing) {
        envelopeShortfall = envelopeOutflowShortfall(
          ref,
          accountId: _accountId!,
          amount: amount,
        );
        if (envelopeShortfall.isPositive) {
          final picked = await pickEnvelopeShortfallCategory(
            context: context,
            accountId: _accountId!,
            shortfall: envelopeShortfall,
          );
          if (picked == null || !mounted) return;
          envelopeShortfallCategoryId = picked;
        }
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
    }
    // No `else if (_categoryId == null)` branch here — an ordinary income or
    // expense with no category picked is a legitimate, intentional choice:
    // it just posts uncategorised, same as any transaction whose category
    // was later deleted already renders (see `_categoryValue` on the
    // transaction detail screen).
    if (_isForeignCurrency &&
        (_foreignCurrencyCode == null || !_foreignAmount.isPositive)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose a currency and enter its amount')),
      );
      return;
    }

    final note = _noteController.text.trim();
    final payeeText = _payeeController.text.trim();
    final payee =
        (_type == TxType.expense || _type == TxType.income) &&
            payeeText.isNotEmpty
        ? payeeText
        : null;
    // A split expense has no single category of its own — see
    // AppDatabase.setTransactionSplits.
    final categoryId = (_type == TxType.transfer || _isSplitting)
        ? null
        : _categoryId;
    final foreignCurrencyCode = _isForeignCurrency
        ? _foreignCurrencyCode
        : null;
    final foreignAmount = _isForeignCurrency ? _foreignAmount : null;
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
          foreignCurrencyCode: foreignCurrencyCode,
          foreignAmount: foreignAmount,
          customIcon: _customIcon,
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
          foreignCurrencyCode: foreignCurrencyCode,
          foreignAmount: foreignAmount,
          customIcon: _customIcon,
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
      // Written only after the transfer itself is safely saved — a failed
      // transfer must never leave a stray allocation behind with nothing to
      // account for.
      if (envelopeShortfallCategoryId != null) {
        await db.addAllocation(
          accountId: _accountId!,
          categoryId: envelopeShortfallCategoryId,
          amount: -envelopeShortfall,
          date: _date,
          note: 'Drawn for a transfer out of this account',
        );
      }
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
    // Kept warm from the moment this screen opens, not read for the first
    // time inside `_save`: `envelopeOutflowShortfall` needs a real value
    // already in hand the instant Save is tapped, and a provider nothing
    // else here watches only starts loading on its first read.
    ref.watch(allAllocationsProvider);
    final amount = _amount;
    // The amount always debits/credits _accountId — the source account for
    // every type, transfer included — so that's whose currency the hero
    // figure and its keypad are in. Null means the parent currency, which
    // is also what every existing screen already renders (no account
    // selected yet defaults to the same thing it always has).
    final txCurrency = _currencyForAccount(_accountId, accountMap);
    // A mutually-exclusive toggle (split/hybrid/change/foreign) or a type
    // switch can hide the card `_activeAmountCtrl` was pointing into without
    // going through a single call site that could reset it — re-check on
    // every build instead, so the shared keypad never silently keeps editing
    // a field the user can no longer see.
    if (!_isSplitting &&
        _splitRows.any((r) => identical(_activeAmountCtrl, r.amountCtrl))) {
      _activeAmountCtrl = _mainAmountCtrl;
    }
    if (!_isHybrid &&
        _hybridLegs.any((r) => identical(_activeAmountCtrl, r.amountCtrl))) {
      _activeAmountCtrl = _mainAmountCtrl;
    }
    if (!_isChange && identical(_activeAmountCtrl, _changeAmountCtrl)) {
      _activeAmountCtrl = _mainAmountCtrl;
    }
    if (!_isForeignCurrency &&
        identical(_activeAmountCtrl, _foreignAmountCtrl)) {
      _activeAmountCtrl = _mainAmountCtrl;
    }

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
                _customIconAction(theme),
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
                      child: GestureDetector(
                        onTap: () => _activateAmountCtrl(_mainAmountCtrl),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            key: const Key('amountDisplay'),
                            txCurrency == null
                                ? MoneyFormat.symbol(amount)
                                : MoneyFormat.symbolIn(amount, txCurrency),
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorForTxType(_type),
                              fontFeatures: kTabularFigures,
                            ),
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
                    if (!_textFieldFocused)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: AmountKeypadGrid(
                          onDigit: _onKey,
                          onBackspace: _onBackspace,
                        ),
                      ),
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
      final preview = _crossCurrencyTransferPreview(accountMap);
      if (preview != null) {
        tiles.add(const SizedBox(height: 8));
        tiles.add(preview);
      }
      final warning = _minimumBalanceWarning(accountMap);
      if (warning != null) {
        tiles.add(const SizedBox(height: 8));
        tiles.add(warning);
      }
    } else {
      // A hybrid payment has no single "paid via" account of its own — its
      // editor below picks each leg's account instead.
      if (!_isHybrid) {
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
        final warning = _minimumBalanceWarning(accountMap);
        if (warning != null) {
          tiles.add(warning);
          tiles.add(const SizedBox(height: 12));
        }
      }
      // Foreign currency applies to both income and expense (unlike
      // split/hybrid/change, which are expense-only) and stays available
      // while editing. Hidden once the account itself already carries a
      // non-parent currency — the transaction's real amount is already
      // natively foreign then, so a second manual foreign-currency
      // annotation on top would be redundant and confusing.
      if (_currencyForAccount(_accountId, accountMap) == null) {
        tiles.add(_foreignToggleTile());
        tiles.add(const SizedBox(height: 12));
      }
      if (_type == TxType.expense) {
        // Editing an existing hybrid payment's legs together isn't
        // supported here (see the doc on [_isHybridPayment]) — there's
        // nothing to merge the split toggle with while editing, so that
        // case keeps the plain single-purpose switch instead.
        tiles.add(_isEditing ? _splitToggleTile() : _splitModeToggleTile());
        tiles.add(const SizedBox(height: 12));
        if (!_isEditing) {
          // Change only ever makes sense out of a cash account, and only if
          // there's a second cash-type account (e.g. Coins) for it to land
          // in — otherwise the toggle leads nowhere. See GitHub #55.
          final cashAccounts = accountMap.values
              .where((a) => a.type == AccountType.cash)
              .length;
          if (accountMap[_accountId]?.type == AccountType.cash &&
              cashAccounts >= 2) {
            tiles.add(_changeToggleTile());
            tiles.add(const SizedBox(height: 12));
          }
        }
      }
      if (_isHybrid) {
        tiles.add(_hybridEditorCard(accountMap));
        tiles.add(const SizedBox(height: 12));
      }
      if (_isChange) {
        tiles.add(_changeEditorCard(accountMap));
        tiles.add(const SizedBox(height: 12));
      }
      if (_isForeignCurrency) {
        tiles.add(_foreignCurrencyEditorCard());
        tiles.add(const SizedBox(height: 12));
      }
      if (_isSplitting) {
        tiles.add(_splitEditorCard(categoryMap));
      } else {
        // A hybrid payment still carries one shared category — see the doc
        // on [_isHybridPayment] — unlike a category split, which replaces
        // this picker with one category per row instead.
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
    tiles.add(_dateTile());
    if (_type == TxType.expense || _type == TxType.income) {
      tiles.add(const SizedBox(height: 12));
      tiles.add(_payeeCard());
    }
    tiles.add(const SizedBox(height: 12));
    tiles.add(_noteCard());
    return tiles;
  }

  /// Like [_pickerTile], but with a second, independent tap target: the
  /// clock icon opens [_pickTime] without disturbing the date, while the
  /// rest of the card still opens [_pickDate] — same card, two pickers,
  /// so adjusting one never has to go through the other (GitHub #124).
  Widget _dateTile() {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: _pickDate,
        leading: Icon(
          Icons.event_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          'Date',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          DateFormat('d MMM yyyy, h:mm a').format(_date),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: IconButton(
          tooltip: 'Change time',
          icon: Icon(
            Icons.access_time_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: _pickTime,
        ),
      ),
    );
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

  /// Expense or income only (GitHub #62 — a salary needs a payee too, same as
  /// a purchase). Free text with autocomplete drawn from payees used before —
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
                hintText: _type == TxType.income
                    ? 'Payee (optional) — who paid you?'
                    : 'Payee (optional) — who did you pay?',
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
      builder: (_) => TagPickerSheet(initiallySelected: _tagIds),
    );
    if (result == null || !mounted) return;
    setState(() => _tagIds = result);
  }

}

enum _ReceiptSource { camera, gallery }

enum _CustomIconSource { library, emoji }

enum _SplitMode { categories, accounts }

/// The knob in [_AddTransactionScreenState._splitModeToggleTile] — a small
/// pill track whose filled circle animates to the left, right, or neutral
/// middle as [mode] changes, so picking a side visibly "moves" the button
/// the way a physical slider would, without needing a raw drag gesture.
class _SplitModeKnob extends StatelessWidget {
  const _SplitModeKnob({required this.mode});

  final _SplitMode? mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = switch (mode) {
      _SplitMode.categories => Alignment.centerLeft,
      _SplitMode.accounts => Alignment.centerRight,
      null => Alignment.center,
    };
    final knobColor = mode == null
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.primary;
    final knobIcon = switch (mode) {
      _SplitMode.categories => Icons.call_split_rounded,
      _SplitMode.accounts => Icons.account_balance_wallet_outlined,
      null => Icons.remove_rounded,
    };

    return Container(
      width: 64,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: alignment,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: knobColor, shape: BoxShape.circle),
          child: Icon(knobIcon, size: 14, color: theme.colorScheme.surface),
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
  const _AccountPickerSheet({
    required this.title,
    this.excludeId,
    this.excludeIds = const {},
    this.excludeGoals = false,
    this.onlyTypes,
  });

  final String title;
  final int? excludeId;

  /// Every other hybrid-payment leg's already-chosen account — see GitHub
  /// #43. Not a replacement for [excludeId]; both apply together.
  final Set<int> excludeIds;

  /// A goal is a savings store, not a spendable account — only a transfer
  /// may fund or draw it down. Set for expense/income pickers.
  final bool excludeGoals;

  /// Restricts the list to these account types when set — e.g. change from
  /// a cash payment only ever lands in another cash-type account, never a
  /// card or bank one (see GitHub #55).
  final Set<AccountType>? onlyTypes;

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
                      .where((a) => !excludeIds.contains(a.id))
                      .where((a) => !excludeGoals || a.type != AccountType.goal)
                      .where((a) => onlyTypes?.contains(a.type) ?? true)
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
  const _CategoryPickerSheet({required this.kind, this.envelopeAccountId});

  final CategoryKind kind;

  /// Set only for an expense on an Envelope Mode account — shows each
  /// category's remaining envelope balance under its name instead of just
  /// the name.
  final int? envelopeAccountId;

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
            categoryId: c.id,
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
          categoryId: drillParent.id,
          iconKey: drillParent.iconKey,
          colorValue: drillParent.colorValue,
          label: 'All ${drillParent.name}',
          onTap: () => Navigator.of(context).pop(drillParent.id),
        ),
        for (final c in childrenByParent[drillParent.id] ?? const [])
          _cell(
            theme,
            categoryId: c.id,
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
            // A little shorter when an envelope-balance line is also
            // rendered under the label, so it never clips.
            childAspectRatio: widget.envelopeAccountId == null ? 0.78 : 0.64,
            children: cells,
          ),
        ),
      ],
    );
  }

  /// One tappable category chip. A small dot marks a parent that opens into
  /// subcategories rather than being picked directly. When [categoryId]
  /// names a category and the sheet was opened for an Envelope Mode account,
  /// a second line shows that category's remaining balance in this account.
  Widget _cell(
    ThemeData theme, {
    required int categoryId,
    required String iconKey,
    required int colorValue,
    required String label,
    required VoidCallback onTap,
    bool hasChildren = false,
  }) {
    final envelopeAccountId = widget.envelopeAccountId;
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
          if (envelopeAccountId != null)
            Consumer(
              builder: (context, ref, _) {
                final balance = ref.watch(categoryBalanceProvider(categoryId));
                return Text(
                  '${MoneyFormat.symbol(balance)} left',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: balance.isNegative
                        ? AppColors.expense
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
