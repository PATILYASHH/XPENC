import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Preset colours for an account. Plain ints — colour here is decorative,
/// not a money-direction signal.
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

const _iconKeys = <String>['cash', 'bank', 'card', 'wallet', 'savings'];

/// Opens the "add account" bottom sheet.
Future<void> showAddAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const AddAccountSheet(),
  );
}

/// Create a Cash / Bank / Card account. A credit card holds its own (negative)
/// balance; a debit card is only an instrument linked to a bank.
class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _last4Controller = TextEditingController();
  final _amountController = TextEditingController();

  AccountType _type = AccountType.cash;
  CardKind _cardKind = CardKind.credit;
  int? _linkedAccountId;
  int _colorValue = _presetColors.first;
  String _iconKey = 'cash';
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _last4Controller.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isCard => _type == AccountType.card;
  bool get _isDebitCard => _isCard && _cardKind == CardKind.debit;
  bool get _isCreditCard => _isCard && _cardKind == CardKind.credit;

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Give the account a name.');
      return;
    }

    // Last 4 digits: only relevant for banks and debit cards, and must be
    // exactly four digits when provided (the DB enforces this).
    String? last4;
    if (_type == AccountType.bank || _isDebitCard) {
      final raw = _last4Controller.text.trim();
      if (raw.isNotEmpty) {
        if (raw.length != 4) {
          _showError('Last 4 digits must be exactly four digits.');
          return;
        }
        last4 = raw;
      }
    }

    String? bankName;
    if (_type == AccountType.bank) {
      final raw = _bankNameController.text.trim();
      if (raw.isNotEmpty) bankName = raw;
    }

    int? linkedAccountId;
    if (_isDebitCard) {
      if (_linkedAccountId == null) {
        _showError('Pick the bank this debit card draws from.');
        return;
      }
      linkedAccountId = _linkedAccountId;
    }

    // Opening balance. Debit cards hold none. A credit card's "outstanding" is
    // money you owe, so it is stored negative.
    Money openingBalance;
    if (_isDebitCard) {
      openingBalance = const Money.zero();
    } else if (_isCreditCard) {
      final parsed = Money.tryParse(_amountController.text) ?? const Money.zero();
      openingBalance = -parsed.abs;
    } else {
      openingBalance = Money.tryParse(_amountController.text) ?? const Money.zero();
    }

    setState(() => _submitting = true);
    try {
      await ref.read(dbProvider).addAccount(
            name: name,
            type: _type,
            cardKind: _isCard ? _cardKind : null,
            linkedAccountId: linkedAccountId,
            bankName: bankName,
            last4: last4,
            colorValue: _colorValue,
            iconKey: _iconKey,
            openingBalance: openingBalance,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(e.message?.toString() ?? 'Could not add the account.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Could not add the account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banks = (ref.watch(accountsProvider).valueOrNull ?? [])
        .where((a) => a.type == AccountType.bank)
        .toList();

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
              'Add account',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Wallet, IPPB Savings',
              ),
            ),
            const SizedBox(height: 20),

            _fieldLabel(theme, 'Type'),
            const SizedBox(height: 8),
            SegmentedButton<AccountType>(
              segments: const [
                ButtonSegment(value: AccountType.cash, label: Text('Cash')),
                ButtonSegment(value: AccountType.bank, label: Text('Bank')),
                ButtonSegment(value: AccountType.card, label: Text('Card')),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _iconKey = switch (_type) {
                  AccountType.cash => 'cash',
                  AccountType.bank => 'bank',
                  AccountType.card => 'card',
                };
              }),
            ),
            const SizedBox(height: 20),

            ..._typeSpecificFields(theme, banks),

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
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Add account'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _typeSpecificFields(ThemeData theme, List<AccountRow> banks) {
    switch (_type) {
      case AccountType.cash:
        return [
          _amountField(label: 'Opening balance'),
          const SizedBox(height: 20),
        ];

      case AccountType.bank:
        return [
          TextField(
            controller: _bankNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Bank name',
              hintText: 'e.g. India Post Payments Bank (IPPB)',
            ),
          ),
          const SizedBox(height: 16),
          _last4Field(),
          const SizedBox(height: 16),
          _amountField(label: 'Opening balance'),
          const SizedBox(height: 20),
        ];

      case AccountType.card:
        return [
          _fieldLabel(theme, 'Card type'),
          const SizedBox(height: 8),
          SegmentedButton<CardKind>(
            segments: const [
              ButtonSegment(value: CardKind.credit, label: Text('Credit')),
              ButtonSegment(value: CardKind.debit, label: Text('Debit')),
            ],
            selected: {_cardKind},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _cardKind = s.first),
          ),
          const SizedBox(height: 16),
          if (_isCreditCard) ..._creditCardFields(theme),
          if (_isDebitCard) ..._debitCardFields(theme, banks),
          const SizedBox(height: 4),
        ];
    }
  }

  List<Widget> _creditCardFields(ThemeData theme) {
    return [
      _infoTile(
        theme,
        'A credit card holds its own balance. Spending makes it negative (what '
        'you owe). Paying the bill is a Transfer from your bank.',
      ),
      const SizedBox(height: 16),
      _amountField(label: 'Outstanding (optional)'),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _debitCardFields(ThemeData theme, List<AccountRow> banks) {
    return [
      _infoTile(
        theme,
        'A debit card spends your bank money. It holds no balance of its own — '
        'payments post to the linked bank.',
      ),
      const SizedBox(height: 16),
      if (banks.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Add a bank account first, then link the debit card to it.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<int>(
            initialValue: _linkedAccountId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Linked bank account'),
            items: [
              for (final b in banks)
                DropdownMenuItem(value: b.id, child: Text(b.name)),
            ],
            onChanged: (v) => setState(() => _linkedAccountId = v),
          ),
        ),
      _last4Field(),
      const SizedBox(height: 16),
    ];
  }

  Widget _amountField({required String label}) {
    return TextField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₹ ',
        hintText: '0.00',
      ),
    );
  }

  Widget _last4Field() {
    return TextField(
      controller: _last4Controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Last 4 digits (optional)',
        counterText: '',
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

  Widget _infoTile(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: () => setState(() => _iconKey = key),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.onSurface : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.colorScheme.onSurface : theme.colorScheme.outline,
          ),
        ),
        child: Icon(
          AppIcons.resolve(key),
          color: selected ? theme.colorScheme.surface : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
