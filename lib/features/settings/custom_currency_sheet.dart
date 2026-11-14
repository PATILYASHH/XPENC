import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../core/l10n/l10n.dart';

/// Opens the sheet that makes a currency the app doesn't list — or, with
/// [existing], edits one already made (its code stays). Resolves to the
/// saved currency, or null when dismissed or deleted.
Future<Currency?> showCustomCurrencySheet(
  BuildContext context, {
  Currency? existing,
}) {
  return showAppSheet<Currency>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => CustomCurrencySheet(existing: existing),
  );
}

/// Code, symbol, name and decimal places for a currency of the person's own.
class CustomCurrencySheet extends ConsumerStatefulWidget {
  const CustomCurrencySheet({this.existing, super.key});

  final Currency? existing;

  @override
  ConsumerState<CustomCurrencySheet> createState() =>
      _CustomCurrencySheetState();
}

class _CustomCurrencySheetState extends ConsumerState<CustomCurrencySheet> {
  late final _codeController = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final _symbolController = TextEditingController(
    text: widget.existing?.symbol ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late int _decimals = widget.existing?.decimalDigits ?? 2;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _codeController.dispose();
    _symbolController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final db = ref.read(dbProvider);
    final navigator = Navigator.of(context);
    final code = _isEdit
        ? widget.existing!.code
        : _codeController.text.trim().toUpperCase();
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await db.updateCustomCurrency(
          code: code,
          symbol: _symbolController.text,
          name: _nameController.text,
          decimalDigits: _decimals,
        );
      } else {
        await db.addCustomCurrency(
          code: code,
          symbol: _symbolController.text,
          name: _nameController.text,
          decimalDigits: _decimals,
        );
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.message?.toString() ?? tr("Couldn't save the currency."));
      return;
    }
    navigator.pop(currencyForCode(code));
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete {0}?', [existing.code])),
        content: const Tr(
          'Only works while nothing uses it — not your parent currency, an '
          'account, a transaction or an Auto rule. Its exchange rates go too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Tr('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Tr('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(dbProvider).deleteCustomCurrency(existing.code);
    } on ArgumentError catch (e) {
      _showError(e.message?.toString() ?? tr("Can't delete it."));
      return;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr('{0} deleted', [existing.code]))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
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
              _isEdit ? tr('Edit currency') : tr('Custom currency'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Tr(
              'For a currency XPENC doesn’t list. It works like any other — '
              'as your parent currency, an account’s own, or with an '
              'exchange rate.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              enabled: !_isEdit,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
              ],
              decoration: InputDecoration(
                labelText: tr('Code'),
                hintText: tr('e.g. XYZ'),
                helperText: _isEdit
                    ? tr('The code can’t change — accounts and transactions '
                          'store it.')
                    : tr('Three letters, not one already in the list.'),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _symbolController,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: tr('Symbol'),
                hintText: tr('e.g. ¤ or Tk'),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('Name'),
                hintText: tr('e.g. Island Dollar'),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            Tr(
              'DECIMAL PLACES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('0')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {_decimals},
                onSelectionChanged: (s) => setState(() => _decimals = s.first),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Text(_isEdit ? tr('Save') : tr('Create')),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Tr('Delete currency'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
