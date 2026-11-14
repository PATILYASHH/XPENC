import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'account_look_fields.dart';
import '../../core/l10n/l10n.dart';

/// Whether [account]'s page offers Transfer in / out at all. A debit card
/// moves its bank's money, so that's done from the bank; goals and loans
/// have their own pages with their own buttons.
bool hasTransferShortcuts(AccountRow account) =>
    account.linkedAccountId == null &&
    !account.isArchived &&
    account.type != AccountType.goal &&
    account.type != AccountType.loan;

/// Opens the "edit account" bottom sheet (GitHub #158).
Future<void> showEditAccountSheet(BuildContext context, AccountRow account) {
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => EditAccountSheet(account: account),
  );
}

/// Name, colour and icon of an existing account — the only details that can
/// change after creation (see [AppDatabase.updateAccountDetails]). Two
/// accounts that look alike were otherwise stuck that way, or deleted and
/// re-created along with their history. Plus which Transfer shortcuts its
/// page shows (GitHub #199).
class EditAccountSheet extends ConsumerStatefulWidget {
  const EditAccountSheet({required this.account, super.key});

  final AccountRow account;

  @override
  ConsumerState<EditAccountSheet> createState() => _EditAccountSheetState();
}

class _EditAccountSheetState extends ConsumerState<EditAccountSheet> {
  late final _nameController = TextEditingController(text: widget.account.name);
  late int _colorValue = widget.account.colorValue;
  late String _iconKey = widget.account.iconKey;
  late bool _showTransferIn = widget.account.showTransferIn;
  late bool _showTransferOut = widget.account.showTransferOut;
  bool _submitting = false;

  /// The page only offers Transfer in / out where [hasTransferShortcuts]
  /// says so, so the switches only appear there too.
  bool get _hasShortcuts => hasTransferShortcuts(widget.account);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError(tr('Give the account a name.'));
      return;
    }
    final account = widget.account;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final detailsChanged =
        name != account.name ||
        _iconKey != account.iconKey ||
        _colorValue != account.colorValue;
    final shortcutsChanged =
        _showTransferIn != account.showTransferIn ||
        _showTransferOut != account.showTransferOut;
    if (!detailsChanged && !shortcutsChanged) {
      navigator.pop();
      return;
    }

    setState(() => _submitting = true);
    try {
      final db = ref.read(dbProvider);
      if (detailsChanged) {
        await db.updateAccountDetails(
          account.id,
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
        );
      }
      if (shortcutsChanged) {
        await db.setAccountTransferShortcuts(
          account.id,
          transferIn: _showTransferIn,
          transferOut: _showTransferOut,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(tr('Could not save the account.'));
      return;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Tr('Account updated')));
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
            Tr(
              'Edit account',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: tr('Name')),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),

            _fieldLabel(theme, tr('Colour')),
            const SizedBox(height: 12),
            AccountColorPicker(
              selected: _colorValue,
              onChanged: (c) => setState(() => _colorValue = c),
            ),
            const SizedBox(height: 24),

            _fieldLabel(theme, tr('Icon')),
            const SizedBox(height: 12),
            AccountIconField(
              iconKey: _iconKey,
              colorValue: _colorValue,
              onChanged: (k) => setState(() => _iconKey = k),
            ),
            const SizedBox(height: 28),

            if (_hasShortcuts) ...[
              _fieldLabel(theme, tr('Shortcuts on its page')),
              const SizedBox(height: 4),
              AppSwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _showTransferIn,
                onChanged: (v) => setState(() => _showTransferIn = v),
                title: const Tr('Transfer in'),
              ),
              AppSwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _showTransferOut,
                onChanged: (v) => setState(() => _showTransferOut = v),
                title: const Tr('Transfer out'),
                subtitle: const Tr(
                  'Turn off for money that can\'t leave, like a prepaid '
                  'balance',
                ),
              ),
              const SizedBox(height: 20),
            ],

            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Tr('Save'),
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
}
