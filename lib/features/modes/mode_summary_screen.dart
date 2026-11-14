import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/bar_page_transition.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/modes_db.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../persons/person_avatar.dart';
import '../share/share_flows.dart';
import '../share/share_models.dart';
import 'mode_widgets.dart';
import '../../core/l10n/l10n.dart';

/// A mode (a trip) told back once it's over (`/mode/:id/summary`): what it
/// came to against its budget, where it went, who owes whom, the planned
/// costs, the wallet's leftover — shareable as a PDF or an image.
class ModeSummaryScreen extends ConsumerWidget {
  const ModeSummaryScreen({required this.modeId, super.key});

  final int modeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mode = ref.watch(modeMapProvider)[modeId];
    if (mode == null) {
      return Scaffold(
        appBar: AppTopBar(title: const Tr('Summary')),
        body: Center(
          child: ref.watch(modesProvider).isLoading
              ? const CircularProgressIndicator()
              : const Tr('This mode no longer exists'),
        ),
      );
    }
    final data = buildModeShare(ref, mode);
    final budget = data.budget;
    final over = budget != null && data.spent.paise > budget.paise;
    final people = ref.watch(modePeopleProvider(mode.id));
    final balances = ref.watch(tripBalancesProvider(mode.id));
    final planned = ref.watch(modePlannedCostsProvider(mode.id));
    final categories = ref.watch(categoryMapProvider);
    final summary = ref.watch(modeSummaryProvider(mode.id));

    return Scaffold(
      appBar: AppTopBar(
        title: Text(mode.name),
        actions: [
          IconButton(
            tooltip: tr('Share'),
            icon: const AppIcon(Icons.ios_share_rounded),
            onPressed: () => shareMode(context, data),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32).plusNavBar(context),
        children: [
          AppCard(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ModeBadge(mode, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          [
                            ?data.dates,
                            plural(data.days, '1 day', '{0} days'),
                          ].join(' · '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Tr(
                    'It came to',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: MoneyText(
                      data.spent,
                      color: AppColors.expense,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (budget != null)
                        over
                            ? tr(
                                '{0} over '
                                'the {1} budget',
                                [
                                  MoneyFormat.symbol(data.spent - budget),
                                  MoneyFormat.symbol(budget),
                                ],
                              )
                            : tr(
                                '{0} '
                                'under the {1} '
                                'budget',
                                [
                                  MoneyFormat.symbol(budget - data.spent),
                                  MoneyFormat.symbol(budget),
                                ],
                              ),
                      tr('{0} a day', [MoneyFormat.symbol(data.perDay)]),
                      data.count == 1
                          ? tr('1 transaction')
                          : tr('{0} transactions', [data.count]),
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: over ? AppColors.expense : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _WalletLeftover(mode: mode),
          if (summary.byCategory.isNotEmpty) ...[
            modeSectionLabel(theme, tr('WHERE IT WENT')),
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, c) in data.categories.indexed) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 60, color: cs.outline),
                    ModeShareRow(
                      iconKey:
                          categories.values
                              .where((x) => x.name == c.name)
                              .firstOrNull
                              ?.iconKey ??
                          'other',
                      colorValue: c.colorValue,
                      label: c.name,
                      amount: c.amount,
                      total: data.spent,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (people.isNotEmpty) ...[
            modeSectionLabel(theme, tr('WHO OWES WHOM')),
            AppCard(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, p) in people.indexed) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 60, color: cs.outline),
                    Builder(
                      builder: (context) {
                        final bal = balances[p.id] ?? const Money.zero();
                        return AppListTile(
                          onTap: () => pushZoom(context, '/person/${p.id}'),
                          leading: PersonAvatar(
                            name: p.name,
                            photoPath: p.photoPath,
                            radius: 18,
                            glow: false,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            bal.isZero
                                ? tr('Even')
                                : bal.isPositive
                                ? tr('Owes you')
                                : tr('You owe'),
                          ),
                          trailing: bal.isZero
                              ? null
                              : MoneyText(
                                  bal.abs,
                                  color: bal.isPositive
                                      ? AppColors.income
                                      : AppColors.expense,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (planned.isNotEmpty) ...[
            modeSectionLabel(theme, tr('PLANNED COSTS')),
            ModePlannedCostsCard(mode: mode, costs: planned),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => shareMode(context, data),
            icon: const AppIcon(Icons.ios_share_rounded),
            label: const Tr('Share the summary'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push('/mode/${mode.id}'),
            child: const Tr('Every transaction'),
          ),
        ],
      ),
    );
  }
}

/// "₹1,200 left in the Goa trip wallet — move it back to HDFC".
class _WalletLeftover extends ConsumerWidget {
  const _WalletLeftover({required this.mode});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletId = mode.walletAccountId;
    if (walletId == null) return const SizedBox.shrink();
    final accounts = ref.watch(accountMapProvider);
    final wallet = accounts[walletId];
    // Archived once its leftover went back.
    if (wallet == null) return const SizedBox.shrink();
    final source = accounts[mode.walletSourceAccountId];
    final left = wallet.currentBalance;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                left.isPositive
                    ? tr('{0} left in {1}', [
                        MoneyFormat.symbol(left),
                        wallet.name,
                      ])
                    : tr('{0} is empty', [wallet.name]),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final back = await ref
                      .read(dbProvider)
                      .returnWalletLeftover(mode.id);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        back.isPositive
                            ? tr(
                                'Moved {0} back to '
                                '{1}',
                                [
                                  MoneyFormat.symbol(back),
                                  source?.name ?? tr('its account'),
                                ],
                              )
                            : tr('Wallet closed'),
                      ),
                    ),
                  );
                },
                child: Text(
                  left.isPositive && source != null
                      ? tr('Move it back to {0}', [source.name])
                      : tr('Close the wallet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [mode]'s summary as share data — what its summary screen, card and PDF
/// all show.
ModeShare buildModeShare(WidgetRef ref, ModeRow mode) {
  final summary = ref.watch(modeSummaryProvider(mode.id));
  final b = ref.watch(modeBudgetProvider(mode.id));
  final txs = ref.watch(modeTransactionsProvider(mode.id));
  final cats = ref.watch(categoryMapProvider);
  final accounts = ref.watch(accountMapProvider);
  final people = ref.watch(modePeopleProvider(mode.id));
  final balances = ref.watch(tripBalancesProvider(mode.id));
  final persons = ref.watch(allPersonsByIdProvider);
  final days = modeDaysElapsed(mode, DateTime.now());
  final byCategory = summary.byCategory.entries.toList()
    ..sort((a, b) => b.value.paise.compareTo(a.value.paise));
  final byAccount = summary.byAccount.entries.toList()
    ..sort((a, b) => b.value.paise.compareTo(a.value.paise));
  return ModeShare(
    name: mode.name,
    colorValue: mode.colorValue,
    dates: modeDateRange(mode),
    spent: summary.spent,
    budget: b.budget,
    planned: b.planned,
    days: days,
    perDay: Money(summary.spent.paise ~/ days),
    count: summary.count,
    categories: [
      for (final e in byCategory)
        (
          name: cats[e.key]?.name ?? tr('Uncategorised'),
          colorValue: cats[e.key]?.colorValue ?? 0xFF78716C,
          amount: e.value,
        ),
    ],
    accounts: [
      for (final e in byAccount)
        (name: accounts[e.key]?.name ?? tr('Account'), amount: e.value),
    ],
    people: [
      for (final p in people)
        (name: p.name, balance: balances[p.id] ?? const Money.zero()),
    ],
    plannedCosts: [
      for (final c in ref.watch(modePlannedCostsProvider(mode.id)))
        (name: c.name, amount: c.amount, paid: c.transactionId != null),
    ],
    lines: [
      for (final t in txs)
        (
          date: t.date,
          title: (t.payee?.trim().isNotEmpty ?? false)
              ? t.payee!.trim()
              : t.type.isPersonMovement
              ? (persons[t.personId]?.name ?? tr('Person'))
              : t.type == TxType.transfer
              ? 'Transfer'
              : (t.note?.trim().isNotEmpty ?? false)
              ? t.note!.trim()
              : (cats[t.categoryId]?.name ?? tr('Uncategorised')),
          detail: [
            ?cats[t.categoryId]?.name,
            if (t.type == TxType.transfer)
              '${accounts[t.accountId]?.name ?? '?'} → '
                  '${accounts[t.toAccountId]?.name ?? '?'}'
            else
              ?accounts[t.accountId]?.name,
          ].join(' · '),
          amount: switch (t.type) {
            TxType.income || TxType.personIn || TxType.correctionIn => t.amount,
            _ => -t.amount,
          },
        ),
    ],
  );
}
