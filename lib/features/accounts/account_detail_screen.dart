import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/amount_keypad_field.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/statement_range_picker.dart';
import '../../core/widgets/transaction_history.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import 'credit_card_statement_section.dart';
import 'envelope_section.dart';
import '../../core/widgets/nav_bar_inset.dart';

/// [account]'s own currency — null for the parent currency, matching
/// [AccountRow.currencyCode]'s own convention. A debit/UPI instrument
/// carries no currency of its own, so this follows [AccountRow.linkedAccountId]
/// once to the account that actually holds the money.
Currency? _accountCurrency(
  AccountRow account,
  Map<int, AccountRow> accountMap,
) {
  final code = account.linkedAccountId == null
      ? account.currencyCode
      : accountMap[account.linkedAccountId]?.currencyCode;
  return code == null ? null : currencyForCode(code);
}

/// One account's balance, context and full history.
///
/// The subtle part is *direction*: a transfer is money out when this account
/// (or a debit card that draws on it) is the source, and money in when this
/// account is the destination. History is grouped day-wise like the main
/// transactions list.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountByIdProvider(accountId));

    return accountAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          title: 'Account not found',
          message: "We couldn't open this account.",
          detail: error.toString(),
          onRetry: () => ref.invalidate(accountByIdProvider(accountId)),
        ),
      ),
      data: (account) {
        if (account == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const ErrorView(
              title: 'Account not found',
              message: 'This account may have been archived or removed.',
            ),
          );
        }
        return _AccountDetailView(account: account);
      },
    );
  }
}

/// The resolved account. Splits out so the header and history can watch the
/// transaction + lookup providers with a guaranteed non-null [account].
class _AccountDetailView extends ConsumerWidget {
  const _AccountDetailView({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountMap = ref.watch(accountMapProvider);
    final categoryMap = ref.watch(categoryMapProvider);
    final txAsync = ref.watch(accountTransactionsProvider(account.id));

    final isDebitCard = account.linkedAccountId != null;
    final linkedBank = isDebitCard ? accountMap[account.linkedAccountId] : null;

    // Instruments that spend on *this* account: the account itself, plus any
    // debit card that draws from it. Money leaving any of these is money out.
    final ownIds = <int>{account.id};
    for (final a in accountMap.values) {
      if (a.linkedAccountId == account.id) ownIds.add(a.id);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download statement',
            onPressed: () => _downloadStatement(context, ref, account),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeaderCard(
              account: account,
              linkedBank: linkedBank,
              currency: _accountCurrency(account, accountMap),
            ),
          ),
          // A linked instrument (debit card / UPI) holds no balance of its
          // own — there is no money on it to give a job to.
          if (account.linkedAccountId == null)
            SliverToBoxAdapter(child: EnvelopeSection(account: account)),
          if (account.type == AccountType.card &&
              account.cardKind == CardKind.credit)
            SliverToBoxAdapter(
              child: CreditCardStatementSection(account: account),
            ),
          ..._historySlivers(
            context: context,
            txAsync: txAsync,
            accountMap: accountMap,
            categoryMap: categoryMap,
            ownIds: ownIds,
            currency: _accountCurrency(account, accountMap),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        const NavBarInsetSliver(),],
      ),
    );
  }

  List<Widget> _historySlivers({
    required BuildContext context,
    required AsyncValue<List<TransactionRow>> txAsync,
    required Map<int, AccountRow> accountMap,
    required Map<int, CategoryRow> categoryMap,
    required Set<int> ownIds,
    required Currency? currency,
  }) {
    final theme = Theme.of(context);

    return txAsync.when(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
      error: (_, _) => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: InlineErrorView(message: "Couldn't load history"),
          ),
        ),
      ],
      data: (txns) {
        if (txns.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Center(
                  child: Text(
                    'No transactions on this account yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ];
        }

        return [
          SliverList.list(
            children: historyChildren(
              txns: txns,
              accountMap: accountMap,
              categoryMap: categoryMap,
              ownIds: ownIds,
              currency: currency,
            ),
          ),
        ];
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

/// Balance + a one-line story about this account, plus type / bank chips.
class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.account,
    required this.linkedBank,
    required this.currency,
  });

  final AccountRow account;
  final AccountRow? linkedBank;
  final Currency? currency;

  bool get _isDebitCard => account.linkedAccountId != null;
  bool get _isCreditCard =>
      account.type == AccountType.card && account.cardKind == CardKind.credit;
  bool get _isPayLater => account.type == AccountType.payLater;
  bool get _owesLikeCredit => _isCreditCard || _isPayLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // A debit card holds no balance of its own — show the bank it draws on.
    final Money shownBalance = _isDebitCard
        ? (linkedBank?.currentBalance ?? const Money.zero())
        : account.currentBalance;

    final String contextLine;
    final Color contextColor;
    if (_isDebitCard) {
      contextLine =
          'This card has no balance of its own. It spends from '
          '${linkedBank?.name ?? 'its linked bank'}.';
      contextColor = cs.onSurfaceVariant;
    } else if (_owesLikeCredit) {
      if (account.currentBalance.isNegative) {
        contextLine = 'Outstanding — you owe this';
        contextColor = AppColors.expense;
      } else {
        contextLine = 'Paid off';
        contextColor = AppColors.income;
      }
    } else {
      final openingBalanceText = currency == null
          ? MoneyFormat.symbol(account.openingBalance)
          : MoneyFormat.symbolIn(account.openingBalance, currency!);
      contextLine = 'Opening balance $openingBalanceText';
      contextColor = cs.onSurfaceVariant;
    }

    final chips = <Widget>[_InfoChip(label: _typeLabel(account.type))];
    final bankLine = _bankLine(account);
    if (bankLine != null) chips.add(_InfoChip(label: bankLine));

    final minimumBalance = account.minimumBalance;
    final minimumBalanceText = minimumBalance == null
        ? null
        : (currency == null
              ? MoneyFormat.symbol(minimumBalance)
              : MoneyFormat.symbolIn(minimumBalance, currency!));
    if (minimumBalanceText != null) {
      chips.add(_InfoChip(label: 'Min $minimumBalanceText'));
    }
    // A debit card shows its linked bank's own balance above — that
    // account's own detail page is where its minimum-balance floor (if any)
    // is actually meaningful.
    final belowMinimumBalance =
        !_isDebitCard &&
        minimumBalance != null &&
        account.currentBalance < minimumBalance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _isDebitCard ? 'Available balance' : 'Balance',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const AmountVisibilityToggle(),
                  if (!_isDebitCard)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Correct balance',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _correctBalance(context, ref),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: BalanceText(
                  shownBalance,
                  currency: currency,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                contextLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: contextColor,
                ),
              ),
              if (belowMinimumBalance) ...[
                const SizedBox(height: 4),
                Text(
                  'Below your minimum balance of $minimumBalanceText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        ),
      ),
    );
  }

  /// Cards, pay-later and loans hold what's *owed* as a negative balance;
  /// the user types that as a plain positive "outstanding" amount.
  bool get _entersAsOwed => _owesLikeCredit || account.type == AccountType.loan;

  String _fmt(Money m) => currency == null
      ? MoneyFormat.symbol(m)
      : MoneyFormat.symbolIn(m, currency!);

  /// "My cash is really ₹75, the app says ₹100": the user types what the
  /// account actually holds and the difference is posted as one
  /// "Correction" transaction dated today (see
  /// [AppDatabase.correctAccountBalance]) — no fake spend, history left
  /// alone, and it counts against the XPENC Score's Tracking habit.
  Future<void> _correctBalance(BuildContext context, WidgetRef ref) async {
    final label = _entersAsOwed ? 'Actual outstanding' : 'Actual balance';
    final shown = _entersAsOwed
        ? account.currentBalance.abs
        : account.currentBalance;
    // Starts empty: pre-filling the shown balance would propose a
    // correction before the user typed anything (and the keypad has no
    // minus sign, so a negative balance would flip).
    final controller = AmountKeypadController();
    final noteController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    Money? target() {
      final parsed = Money.tryParse(controller.text);
      if (parsed == null) return null;
      return _entersAsOwed ? -parsed.abs : parsed;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Correct balance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'XPENC shows ${_fmt(shown)}${_entersAsOwed ? ' owed' : ''}. '
                  'Enter what ${_entersAsOwed ? 'you really owe' : 'you really have'} '
                  'and the difference is recorded as a Correction.',
                ),
                const SizedBox(height: 16),
                AmountKeypadField(
                  controller: controller,
                  label: label,
                  autofocus: true,
                  yieldTo: const [],
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final t = target();
                    final diff = t == null ? null : t - account.currentBalance;
                    final String text;
                    final Color color;
                    if (diff == null) {
                      text = 'Enter an amount.';
                      color = theme.colorScheme.onSurfaceVariant;
                    } else if (diff.isZero) {
                      text = 'Matches — nothing to correct.';
                      color = theme.colorScheme.onSurfaceVariant;
                    } else {
                      text =
                          'Correction of ${diff.isNegative ? '-' : '+'}'
                          '${_fmt(diff.abs)} will be added today.';
                      color = AppColors.correction;
                    }
                    return Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'e.g. forgot to log small cash spends',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Corrections are never counted as income or spending, but '
                  'they lower your XPENC Score\'s Tracking habit — logging as '
                  'you go keeps the balance right on its own.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (target() == null) {
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount.')),
                    );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    // Deliberately not disposed — see the same note in
    // persons_screen.dart's _createGroup: the dialog's widget tree is still
    // mounted during the pop exit-transition, and a stray tap on the keypad
    // in that window would call notifyListeners() on an already-disposed
    // AmountKeypadController (an assertion failure).
    final actual = target();
    if (confirmed != true || actual == null) return;
    final note = noteController.text.trim();

    final int? id;
    try {
      id = await ref
          .read(dbProvider)
          .correctAccountBalance(
            accountId: account.id,
            actualBalance: actual,
            note: note.isEmpty ? null : note,
          );
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
      return;
    }
    if (!context.mounted) return;
    final diff = actual - account.currentBalance;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            id == null
                ? 'Balance already matches'
                : 'Balance corrected · ${diff.isNegative ? '-' : '+'}'
                      '${_fmt(diff.abs)} recorded as a Correction',
          ),
        ),
      );
  }

  /// "HDFC •••• 1234" — whichever parts are present.
  String? _bankLine(AccountRow a) {
    final parts = <String>[];
    if (a.bankName != null && a.bankName!.isNotEmpty) parts.add(a.bankName!);
    if (a.last4 != null && a.last4!.isNotEmpty) parts.add('•••• ${a.last4}');
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Direction ─────────────────────────────────────────────────────────────

String _typeLabel(AccountType type) => switch (type) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank',
  AccountType.card => 'Card',
  AccountType.payLater => 'Pay later',
  AccountType.prepaidBalance => 'Prepaid Balance',
  AccountType.goal => 'Goal',
  AccountType.loan => 'Loan',
};

// ── Statement download ───────────────────────────────────────────────────────

Future<void> _downloadStatement(
  BuildContext context,
  WidgetRef ref,
  AccountRow account,
) async {
  final range = await pickStatementRange(context);
  if (range == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Generating statement...')));
  try {
    final file = await service.writeAccountStatementPdf(
      account: account,
      start: range.start,
      end: range.end,
    );
    await service.share(file, subject: '${account.name} statement');
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Exported ${file.uri.pathSegments.last}')),
      );
  } catch (e) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text("Couldn't generate statement: $e")),
      );
  }
}
