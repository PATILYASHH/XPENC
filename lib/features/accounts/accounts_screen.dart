import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_icons.dart';
import '../../core/currency.dart';
import '../../core/layout/desktop.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/amount_keypad_field.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/module_shortcuts.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/statement_range_picker.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'add_account_sheet.dart';
import 'edit_account_sheet.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../modes/mode_sandbox_views.dart';
import '../../core/l10n/l10n.dart';

/// Total money + per-account balances, grouped Cash · Bank · Cards.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/accounts` exactly as it was.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A mode (a trip) that's the focus shows only its own accounts.
    final mode = ref.watch(focusedModeProvider);
    if (mode != null &&
        ref.watch(modeAllocationsProvider(mode.id)).isNotEmpty) {
      return ModeAccountsView(mode: mode, embedded: embedded);
    }
    final accountsAsync = ref.watch(accountsProvider);
    final accountMap = ref.watch(accountMapProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (embedded) const TopBarInsetSliver(),
          if (!embedded)
            SliverAppBar(
              pinned: true,
              flexibleSpace: const GlassScrollEdge(),
              automaticallyImplyLeading: impliesBackArrow(context),
              title: const Tr('Accounts'),
              actions: [
                GlassActionGroup(
                  children: [
                    IconButton(
                      tooltip: tr('Statement'),
                      icon: const AppIcon(Icons.picture_as_pdf_outlined),
                      onPressed: () => _downloadCombinedStatement(context, ref),
                    ),
                    IconButton(
                      tooltip: tr('Archived accounts'),
                      icon: const AppIcon(Icons.inventory_2_outlined),
                      onPressed: () => context.push('/more/accounts/archived'),
                    ),
                    IconButton(
                      tooltip: tr('Add account'),
                      icon: const AppIcon(Icons.add_rounded),
                      onPressed: () => showAddAccountSheet(context),
                    ),
                  ],
                ),
              ],
            ),
          const SliverToBoxAdapter(child: _TotalMoneyCard()),
          SliverToBoxAdapter(
            child: ModuleShortcuts([
              ModuleShortcut(
                Icons.currency_exchange_rounded,
                tr('Currency'),
                '/more/settings/currency',
              ),
              // The tab has no top-bar button for it; the page does.
              if (embedded)
                ModuleShortcut(
                  Icons.inventory_2_outlined,
                  tr('Archived'),
                  '/more/accounts/archived',
                ),
              ModuleShortcut(
                Icons.account_balance_outlined,
                tr('Account reports'),
                '/more/account-reports',
              ),
              ModuleShortcut(
                Icons.savings_outlined,
                tr('Goals & Loans'),
                '/more/goals',
              ),
              ModuleShortcut(
                Icons.tune_rounded,
                tr('Available balance'),
                '/more/settings/dashboard',
              ),
            ]),
          ),
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
                  child: Tr(
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
        const NavBarInsetSliver(),],
      ),
    );
  }

  Future<void> _downloadCombinedStatement(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final range = await pickStatementRange(context);
    if (range == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(backupServiceProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Tr('Generating statement...')));
    try {
      final file = await service.writeCombinedStatementPdf(
        start: range.start,
        end: range.end,
      );
      await service.share(file, subject: tr('Combined statement'));
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('Exported {0}', [file.name]))));
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(tr("Couldn't generate statement: {0}", [e]))),
        );
    }
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
    final payLater = accounts
        .where((a) => a.type == AccountType.payLater)
        .toList();
    final prepaidBalance = accounts
        .where((a) => a.type == AccountType.prepaidBalance)
        .toList();

    final out = <Widget>[];
    void addGroup(String title, List<AccountRow> rows) {
      if (rows.isEmpty) return;
      out
        ..add(_sectionHeader(context, title))
        ..add(_sectionCard(context, ref, rows, accountMap));
    }

    addGroup(tr('Cash'), cash);
    addGroup(tr('Bank'), banks);
    addGroup(tr('Cards'), cards);
    addGroup(tr('Pay later'), payLater);
    addGroup(tr('Prepaid Balance'), prepaidBalance);
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
        child: AppCard(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 70,
                    color: theme.colorScheme.outline,
                  ),
                _AccountTile(account: rows[i], accountMap: accountMap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Total money" hero card — every account (GitHub #198), debit cards
/// left out so their bank balance is never counted twice — with Available
/// balance beneath it once some account isn't counted as spendable.
class _TotalMoneyCard extends ConsumerWidget {
  const _TotalMoneyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final netWorth =
        ref.watch(netWorthProvider).valueOrNull ?? const Money.zero();
    final available = ref.watch(availableBalanceProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tr(
                    'Total money',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const AmountVisibilityToggle(),
                ],
              ),
              const SizedBox(height: 6),
              BalanceText(
                netWorth,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Tr(
                'Every account, goals and loans included',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (available != null && available != netWorth) ...[
                const SizedBox(height: 12),
                InkWell(
                  key: const Key('accounts-available-balance'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push('/more/settings/dashboard'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Tr(
                          'Available balance',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      BalanceText(
                        available,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AppIcon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const _OwnOweRow(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tr(
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

/// What Total money is made of (GitHub #183): what you own — every account
/// in credit — beside what you owe — card bills, loans, anything in debt.
/// The two always net to the total above them.
class _OwnOweRow extends ConsumerWidget {
  const _OwnOweRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parts = ref.watch(assetsAndLiabilitiesProvider).valueOrNull;
    if (parts == null) return const SizedBox.shrink();

    Widget cell(String label, Money amount, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        // A lakh-sized figure shrinks rather than wrapping into its neighbour.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(
            amount,
            color: color,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      child: Row(
        children: [
          Expanded(child: cell(tr('You own'), parts.assets, cs.onSurface)),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: cs.outlineVariant,
          ),
          Expanded(
            child: cell(
              tr('You owe'),
              parts.liabilities,
              parts.liabilities.isPositive ? AppColors.expense : cs.onSurface,
            ),
          ),
        ],
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
  bool get _isPayLater => account.type == AccountType.payLater;
  bool get _owesLikeCredit => _isCreditCard || _isPayLater;

  /// Null = parent currency, matching every existing account before this
  /// feature — [BalanceText] then renders exactly as it always has.
  Currency? get _currency =>
      account.currencyCode == null ? null : currencyForCode(account.currencyCode!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Widget? subtitle;
    Widget? trailing;

    if (_isDebitCard) {
      final bank = accountMap[account.linkedAccountId];
      subtitle = _subtitle(theme, tr('Draws from {0}', [bank?.name ?? 'bank']));
      trailing = _LinkedChip();
    } else if (_owesLikeCredit) {
      subtitle = _subtitle(
        theme,
        account.currentBalance.isNegative ? tr('Outstanding') : tr('Paid off'),
      );
      trailing = BalanceText(
        account.currentBalance,
        currency: _currency,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
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
        currency: _currency,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _leading(),
      title: Text(
        account.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle,
      trailing: trailing,
      onTap: () => pushZoom(context, '/account/${account.id}'),
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
      child: IconWell(AppIcons.resolve(account.iconKey), color: color, size: 22),
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

  /// Hold-to-act: Edit (name, colour, icon), Archive (reversible, hides it)
  /// or Remove (permanent, only works when nothing points at it).
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final action = await showAppSheet<_AccountAction>(
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            AppListTile(
              leading: const AppIcon(Icons.edit_outlined),
              title: const Tr('Edit'),
              subtitle: const Tr('Name, colour and icon'),
              onTap: () => Navigator.of(sheetContext).pop(_AccountAction.edit),
            ),
            // A debit card/UPI instrument holds no balance of its own (see
            // Accounts.linkedAccountId) — there's nothing to warn about.
            if (account.linkedAccountId == null)
              AppListTile(
                leading: const AppIcon(Icons.savings_outlined),
                title: const Tr('Minimum balance'),
                subtitle: Text(
                  account.minimumBalance == null
                      ? tr('Get a note when spending takes this below a floor')
                      : tr('Currently {0}', [MoneyFormat.symbol(account.minimumBalance!)]),
                ),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_AccountAction.minimumBalance),
              ),
            AppListTile(
              leading: const AppIcon(Icons.archive_outlined),
              title: const Tr('Archive'),
              subtitle: const Tr('Hide it. History stays intact.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.archive),
            ),
            AppListTile(
              leading: AppIcon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Tr(
                'Remove',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Tr('Delete permanently — only if unused.'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.remove),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _AccountAction.edit:
        await showEditAccountSheet(context, account);
      case _AccountAction.minimumBalance:
        await _confirmMinimumBalance(context, ref);
      case _AccountAction.archive:
        await _confirmArchive(context, ref);
      case _AccountAction.remove:
        await _confirmRemove(context, ref);
    }
  }

  /// Purely informational floor (see the doc on [Accounts.minimumBalance]) —
  /// `null` from the dialog clears it, same "empty means remove" convention
  /// as every other optional-field editor in this app.
  Future<void> _confirmMinimumBalance(BuildContext context, WidgetRef ref) async {
    final result = await showAppDialog<_MinimumBalanceResult>(
      context: context,
      builder: (ctx) =>
          _MinimumBalanceDialog(currentValue: account.minimumBalance),
    );
    if (result == null) return;

    await ref
        .read(dbProvider)
        .setAccountMinimumBalance(account.id, result.value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.value == null
                ? tr('Minimum balance cleared')
                : tr('Minimum balance updated'),
          ),
        ),
      );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tr('Archive account?'),
        content: Text(
          tr('"{0}" will be hidden from your accounts. '
          'Its history stays intact.', [account.name]),
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
            child: const Tr('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(dbProvider).archiveAccount(account.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Tr('Account archived')));
  }

  /// Unlike archiving, this can't be undone — [AppDatabase.deleteAccount]
  /// refuses (with a clear reason) whenever anything still points at the
  /// account, so this only ever succeeds on one with no history.
  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Remove "{0}"?', [account.name])),
        content: const Tr(
          "This permanently deletes the account — it can't be undone. It "
          'only works if the account has no transaction history; otherwise '
          'archive it instead.',
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
            child: const Tr('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    bool rtaAutoDisabled;
    try {
      rtaAutoDisabled = await ref.read(dbProvider).deleteAccount(account.id);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message?.toString() ?? tr("Can't remove this account")),
          ),
        );
      return;
    } catch (e) {
      // Anything else (a database error) must still say so — a delete that
      // silently does nothing reads as a dead button.
      debugPrint('delete account failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(tr("Can't remove this account"))),
        );
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            rtaAutoDisabled
                ? tr('Account removed. Ready to Assign turned off — no '
                      'accounts left in the pool.')
                : tr('Account removed'),
          ),
        ),
      );
  }
}

enum _AccountAction { edit, minimumBalance, archive, remove }

/// Wraps the picked value so "Clear" (value: null) is distinguishable from
/// "Cancel" (the dialog's Future itself resolves null).
class _MinimumBalanceResult {
  const _MinimumBalanceResult(this.value);

  final Money? value;
}

/// A `StatefulWidget`, not a bare controller disposed right after
/// `showDialog` resolves — that races the dialog's own closing animation:
/// the route pops (resolving the `Future`) before the still-visible
/// `TextField` finishes its exit transition, so a controller disposed
/// immediately can be torn down while that `TextField` is still attached
/// to it. Owning the controller in `State.dispose()` ties its lifetime to
/// the framework's own unmount timing instead, which is always correct.
class _MinimumBalanceDialog extends StatefulWidget {
  const _MinimumBalanceDialog({required this.currentValue});

  final Money? currentValue;

  @override
  State<_MinimumBalanceDialog> createState() => _MinimumBalanceDialogState();
}

class _MinimumBalanceDialogState extends State<_MinimumBalanceDialog> {
  late final _controller = AmountKeypadController()
    ..setAmount(widget.currentValue ?? const Money.zero());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Tr('Minimum balance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tr(
            "A note when spending would take this account's balance below "
            'the amount you set here. Nothing is ever blocked.',
          ),
          const SizedBox(height: 16),
          AmountKeypadField(
            controller: _controller,
            label: tr('Minimum balance'),
            autofocus: true,
            yieldTo: const [],
          ),
        ],
      ),
      actions: [
        if (widget.currentValue != null)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const _MinimumBalanceResult(null)),
            child: const Tr('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Tr('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = Money.tryParse(_controller.text);
            if (parsed == null || !parsed.isPositive) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Tr('Enter an amount above zero.')),
                );
              return;
            }
            Navigator.of(context).pop(_MinimumBalanceResult(parsed));
          },
          child: const Tr('Save'),
        ),
      ],
    );
  }
}

/// A small outlined chip marking a debit card as an instrument of its bank.
class _LinkedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: const Tr('Linked'),
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
