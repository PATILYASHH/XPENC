import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'add_account_sheet.dart';

/// Total money + per-account balances, grouped Cash · Bank · Cards.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final accountMap = ref.watch(accountMapProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Accounts'),
            expandedHeight: 132,
            actions: [
              IconButton(
                tooltip: 'Add account',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => showAddAccountSheet(context),
              ),
            ],
          ),
          const SliverToBoxAdapter(child: _TotalMoneyCard()),
          ...accountsAsync.when(
            data: (accounts) => _sections(context, ref, accounts, accountMap),
            loading: () => const [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (_, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Could not load your accounts.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    WidgetRef ref,
    List<AccountRow> accounts,
    Map<int, AccountRow> accountMap,
  ) {
    final cash = accounts.where((a) => a.type == AccountType.cash).toList();
    final banks = accounts.where((a) => a.type == AccountType.bank).toList();
    final cards = accounts.where((a) => a.type == AccountType.card).toList();

    final out = <Widget>[];
    void addGroup(String title, List<AccountRow> rows) {
      if (rows.isEmpty) return;
      out
        ..add(_sectionHeader(context, title))
        ..add(_sectionCard(context, ref, rows, accountMap));
    }

    addGroup('Cash', cash);
    addGroup('Bank', banks);
    addGroup('Cards', cards);
    return out;
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context,
    WidgetRef ref,
    List<AccountRow> rows,
    Map<int, AccountRow> accountMap,
  ) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Card(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 70, color: theme.colorScheme.outline),
                _AccountTile(account: rows[i], accountMap: accountMap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Total money" hero card. Reads net worth, which already excludes debit
/// cards so their bank balance is never counted twice.
class _TotalMoneyCard extends ConsumerWidget {
  const _TotalMoneyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final netWorth = ref.watch(netWorthProvider).valueOrNull ?? const Money.zero();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total money',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              BalanceText(
                netWorth,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cash + Bank + Cards',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Debit cards draw from their bank and are not counted twice.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
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
}

/// A single account row. Its shape depends on the kind of account:
/// cash/bank and credit cards show a balance; debit cards show a "Linked" chip.
class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.accountMap});

  final AccountRow account;
  final Map<int, AccountRow> accountMap;

  bool get _isDebitCard => account.linkedAccountId != null;
  bool get _isCreditCard =>
      account.type == AccountType.card && account.cardKind == CardKind.credit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Widget? subtitle;
    Widget? trailing;

    if (_isDebitCard) {
      final bank = accountMap[account.linkedAccountId];
      subtitle = _subtitle(theme, 'Draws from ${bank?.name ?? 'bank'}');
      trailing = _LinkedChip();
    } else if (_isCreditCard) {
      subtitle = _subtitle(
        theme,
        account.currentBalance.isNegative ? 'Outstanding' : 'Paid off',
      );
      trailing = BalanceText(
        account.currentBalance,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    } else {
      final parts = <String>[];
      if (account.bankName != null && account.bankName!.isNotEmpty) {
        parts.add(account.bankName!);
      }
      if (account.last4 != null && account.last4!.isNotEmpty) {
        parts.add('•••• ${account.last4}');
      }
      subtitle = parts.isEmpty ? null : _subtitle(theme, parts.join('   '));
      trailing = BalanceText(
        account.currentBalance,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _leading(),
      title: Text(
        account.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle,
      trailing: trailing,
      onTap: () => context.push('/account/${account.id}'),
      onLongPress: () => _showActions(context, ref),
    );
  }

  Widget _leading() {
    final color = Color(account.colorValue);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(AppIcons.resolve(account.iconKey), color: color, size: 22),
    );
  }

  Widget _subtitle(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Hold-to-act: a sheet offering Archive (reversible, hides it) or Remove
  /// (permanent, only works when nothing points at it).
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final action = await showModalBottomSheet<_AccountAction>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  account.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              subtitle: const Text('Hide it. History stays intact.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.archive),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text('Remove', style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Delete permanently — only if unused.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.remove),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _AccountAction.archive) {
      await _confirmArchive(context, ref);
    } else {
      await _confirmRemove(context, ref);
    }
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive account?'),
        content: Text(
          '"${account.name}" will be hidden from your accounts. '
          'Its history stays intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(dbProvider).archiveAccount(account.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Account archived')));
  }

  /// Unlike archiving, this can't be undone — [AppDatabase.deleteAccount]
  /// refuses (with a clear reason) whenever anything still points at the
  /// account, so this only ever succeeds on one with no history.
  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${account.name}"?'),
        content: const Text(
          "This permanently deletes the account — it can't be undone. It "
          'only works if the account has no transaction history; otherwise '
          'archive it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(dbProvider).deleteAccount(account.id);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e.message?.toString() ?? "Can't remove this account"),
        ));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Account removed')));
  }
}

enum _AccountAction { archive, remove }

/// A small outlined chip marking a debit card as an instrument of its bank.
class _LinkedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: const Text('Linked'),
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: theme.colorScheme.outline),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
