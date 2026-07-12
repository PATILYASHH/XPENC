import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// Warning tint for the "possible duplicate" banner. Amber is neither money-in
/// nor money-out — it's a caution, so it deliberately sits outside the semantic
/// income/expense palette. Readable on both light and true-black surfaces.
const _amber = Color(0xFFB45309);

/// The review queue for auto-captured bank messages. Everything here was read
/// on-device; nothing posts to the ledger without a tap (except a card the user
/// already taught us to auto-fill, which is shown afterwards so it can be
/// checked and undone).
class ReviewInboxScreen extends ConsumerWidget {
  const ReviewInboxScreen({super.key});

  // The "Scan messages" action lived here until 1.1.0. With SMS capture
  // paused (no source ships in this build) a scan can never find anything, so
  // the button is gone rather than left to no-op.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingAsync = ref.watch(allPendingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Inbox')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Couldn't load the inbox.\n$e",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ),
        data: (all) {
          final needsReview = all
              .where((p) =>
                  p.status == PendingStatus.pending ||
                  p.status == PendingStatus.duplicate)
              .toList();
          final autoFilled = all
              .where((p) => p.status == PendingStatus.autoFilled)
              .toList();

          if (needsReview.isEmpty && autoFilled.isEmpty) {
            return const _EmptyInbox();
          }

          return CustomScrollView(
            slivers: [
              if (needsReview.isNotEmpty) ...[
                _sectionHeader(theme, 'Needs review'),
                SliverList.builder(
                  itemCount: needsReview.length,
                  itemBuilder: (context, i) =>
                      PendingCard(pending: needsReview[i]),
                ),
              ],
              if (autoFilled.isNotEmpty) ...[
                _sectionHeader(theme, 'Recently auto-filled'),
                SliverList.builder(
                  itemCount: autoFilled.length,
                  itemBuilder: (context, i) =>
                      PendingCard(pending: autoFilled[i]),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                  child: Text(
                    'Low-confidence messages never post by themselves.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Shown when there is nothing to review. Doubles as a privacy reassurance —
/// the whole point of on-device capture is that nothing leaves the phone.
class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nothing to review.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bank-SMS auto-capture is coming soon — cards detected by '
                  'earlier versions appear here until then.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One detected transaction. Public and self-contained so the dashboard can
/// drop it straight into its own list.
///
/// Direction is the source of truth for colour and meaning: a `debit` is money
/// leaving (red, arrow out); a `credit` is money arriving (green, arrow in).
class PendingCard extends ConsumerWidget {
  const PendingCard({required this.pending, super.key});

  final PendingTxnRow pending;

  bool get _isOut => pending.parsedDirection == TxDirection.debit;

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(dbProvider).undoPending(pending.id);
    messenger.showSnackBar(
      const SnackBar(content: Text('Undone — transaction reversed')),
    );
  }

  void _dismiss(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    final db = ref.read(dbProvider);
    db.setPendingStatus(pending.id, PendingStatus.dismissed);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Dismissed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              db.setPendingStatus(pending.id, PendingStatus.pending),
        ),
      ),
    );
  }

  void _notDuplicate(WidgetRef ref) {
    ref.read(dbProvider).setPendingStatus(pending.id, PendingStatus.pending);
  }

  void _openApproveSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ApproveSheet(pending: pending),
    );
  }

  /// The third subtitle line: which account this hit, or a hint to pick one.
  String _accountLine(Map<int, AccountRow> accountMap) {
    final matched = pending.matchedAccountId;
    if (matched != null) {
      final name = accountMap[matched]?.name;
      if (name != null) return name;
    }
    final hint = pending.parsedAccountHint;
    if (matched == null && hint != null) {
      return 'Account •••• $hint — tap to pick';
    }
    return 'Account not identified';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accountMap = ref.watch(accountMapProvider);

    final color = _isOut ? AppColors.expense : AppColors.income;
    final icon =
        _isOut ? Icons.north_east_rounded : Icons.south_west_rounded;
    final amount = pending.parsedAmount ?? const Money.zero();
    final merchant = pending.parsedMerchant;
    final mutedSmall =
        theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MoneyText(
                        amount,
                        color: color,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        merchant ?? 'Unknown merchant',
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMM, h:mm a')
                            .format(pending.receivedAt),
                        style: mutedSmall,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _accountLine(accountMap),
                        style: mutedSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _statusStrip(context, ref, theme),
            _MessageDisclosure(pending: pending),
          ],
        ),
      ),
    );
  }

  Widget _statusStrip(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    switch (pending.status) {
      case PendingStatus.autoFilled:
        return _Banner(
          color: AppColors.income,
          icon: Icons.check_circle_outline_rounded,
          text: 'Auto-filled — already added. Tap Undo if this is wrong.',
          action: TextButton(
            onPressed: () => _undo(context, ref),
            child: const Text('Undo'),
          ),
        );
      case PendingStatus.duplicate:
        return _Banner(
          color: _amber,
          icon: Icons.copy_rounded,
          text: 'Looks like a duplicate of another message',
          action: TextButton(
            onPressed: () => _notDuplicate(ref),
            child: const Text('Not a duplicate'),
          ),
        );
      case PendingStatus.pending:
        return Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => _openApproveSheet(context),
                child: const Text('Categorise'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _dismiss(context, ref),
              child: const Text('Dismiss'),
            ),
          ],
        );
      case PendingStatus.approved:
      case PendingStatus.dismissed:
        return const SizedBox.shrink();
    }
  }
}

/// A rounded, tinted info strip with a trailing action button.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
    required this.action,
  });

  final Color color;
  final IconData icon;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          action,
        ],
      ),
    );
  }
}

/// A collapsible "Show message" row revealing the raw body + sender. Stateless
/// on purpose (ExpansionTile owns its open/closed state) so [PendingCard] can
/// stay a plain [ConsumerWidget].
class _MessageDisclosure extends StatelessWidget {
  const _MessageDisclosure({required this.pending});

  final PendingTxnRow pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(
        'Show message',
        style: theme.textTheme.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
      children: [
        Text(
          pending.rawBody,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: cs.onSurface,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'From ${pending.sender}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The "Categorise this transaction" sheet. Local state only — the account,
/// category and the "remember" choice — committed atomically by
/// `approvePending`.
class _ApproveSheet extends ConsumerStatefulWidget {
  const _ApproveSheet({required this.pending});

  final PendingTxnRow pending;

  @override
  ConsumerState<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends ConsumerState<_ApproveSheet> {
  int? _accountId;
  int? _categoryId;
  bool _remember = true;

  PendingTxnRow get _p => widget.pending;
  bool get _isOut => _p.parsedDirection == TxDirection.debit;
  String? get _merchant => _p.parsedMerchant;

  @override
  void initState() {
    super.initState();
    _accountId = _p.matchedAccountId;
  }

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final accountId = _accountId;
    final categoryId = _categoryId;

    if (accountId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose an account')),
      );
      return;
    }
    if (categoryId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choose a category')),
      );
      return;
    }

    try {
      await ref.read(dbProvider).approvePending(
            _p.id,
            categoryId: categoryId,
            accountId: accountId,
            learnMerchantRule: _remember && _merchant != null,
          );
    } on ArgumentError catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? 'Could not add transaction'),
        ),
      );
      return;
    }

    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Added')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _isOut ? AppColors.expense : AppColors.income;
    final amount = _p.parsedAmount ?? const Money.zero();
    final kind =
        _isOut ? CategoryKind.expense : CategoryKind.income;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Categorise this transaction',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Coloured amount + direction header.
              Column(
                children: [
                  MoneyText(
                    amount,
                    color: color,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isOut ? 'Money Out' : 'Money In',
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Account',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _accountPicker(theme),
              const SizedBox(height: 20),
              Text(
                'Category',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _categoryGrid(theme, kind),
              if (_merchant != null) ...[
                const SizedBox(height: 12),
                _rememberTile(theme),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _add,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Add transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountPicker(ThemeData theme) {
    final accountsAsync = ref.watch(accountsProvider);
    final accountMap = ref.watch(accountMapProvider);

    return accountsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Could not load accounts.\n$e',
        style: theme.textTheme.bodyMedium,
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return Text(
            'No accounts yet — add one first.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < accounts.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: theme.colorScheme.outline,
                  ),
                _accountTile(theme, accounts[i], accountMap),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _accountTile(
    ThemeData theme,
    AccountRow account,
    Map<int, AccountRow> accountMap,
  ) {
    final selected = _accountId == account.id;
    final isDebitCard = account.linkedAccountId != null;
    final linkedName = account.linkedAccountId == null
        ? null
        : accountMap[account.linkedAccountId]?.name;

    return ListTile(
      leading: _iconCircle(account.iconKey, account.colorValue),
      title: Text(account.name),
      subtitle: isDebitCard
          ? Text('Draws from ${linkedName ?? account.bankName ?? 'linked bank'}')
          : null,
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : const Icon(Icons.circle_outlined),
      onTap: () => setState(() => _accountId = account.id),
    );
  }

  Widget _categoryGrid(ThemeData theme, CategoryKind kind) {
    final catsAsync = ref.watch(categoriesProvider(kind));
    return catsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Could not load categories.\n$e',
        style: theme.textTheme.bodyMedium,
      ),
      data: (cats) {
        if (cats.isEmpty) {
          return Text(
            'No categories yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: cats.length,
          itemBuilder: (context, i) {
            final c = cats[i];
            final selected = _categoryId == c.id;
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _categoryId = c.id),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: _iconCircle(c.iconKey, c.colorValue, size: 48),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      c.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: selected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _rememberTile(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: _remember,
        onChanged: (v) => setState(() => _remember = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('Remember: always categorise "$_merchant" as this'),
        subtitle: Text(
          'Next time this is auto-filled for you. The card still appears so '
          'you can check it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A round badge showing an account/category icon on its own stored colour.
Widget _iconCircle(String iconKey, int colorValue, {double size = 44}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Color(colorValue),
      shape: BoxShape.circle,
    ),
    child: Icon(
      AppIcons.resolve(iconKey),
      color: Colors.white,
      size: size * 0.5,
    ),
  );
}
