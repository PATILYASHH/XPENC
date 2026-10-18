import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_icons.dart';
import '../../core/money.dart';
import '../../core/security/nct.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/modes_db.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';

/// A mode's icon on its colour, in a circle.
class ModeBadge extends StatelessWidget {
  const ModeBadge(this.mode, {this.size = 40, super.key});

  final ModeRow mode;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Color(mode.colorValue),
      shape: BoxShape.circle,
    ),
    child: KeyIcon(mode.iconKey, color: Colors.white, size: size * 0.5),
  );
}

/// "🧳 Goa trip" — marks a transaction that's in a mode, wherever it's
/// listed outside that mode. Taps through to the mode's page.
class ModeChip extends ConsumerWidget {
  const ModeChip(this.modeId, {super.key});

  final int modeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(modeMapProvider)[modeId];
    if (mode == null) return const SizedBox.shrink();
    final color = Color(mode.colorValue);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/mode/${mode.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyIcon(mode.iconKey, color: color, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                mode.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "12–18 Oct", "From 12 Oct", or null when the mode has no dates at all.
/// Prefers when it actually ran over what was planned.
String? modeDateRange(ModeRow mode) {
  final start = mode.startedAt ?? mode.startDate;
  final end = mode.status == ModeStatus.ended
      ? (mode.endedAt ?? mode.endDate)
      : mode.endDate;
  if (start == null) return null;
  final day = DateFormat('d MMM');
  if (end == null) return 'From ${day.format(start)}';
  if (start.year == end.year && start.month == end.month) {
    if (start.day == end.day) return day.format(start);
    return '${start.day}–${day.format(end)}';
  }
  return '${day.format(start)} – ${day.format(end)}';
}

/// What a mode is doing right now, in a few words.
String modeStatusLine(ModeRow mode, DateTime now) {
  final range = modeDateRange(mode);
  switch (mode.status) {
    case ModeStatus.active:
      final day = modeDayNumber(mode, now);
      return ['ON', if (day != null) 'Day $day', ?range].join(' · ');
    case ModeStatus.planned:
      return range == null ? 'Not started' : 'Planned · $range';
    case ModeStatus.ended:
      return range == null ? 'Ended' : 'Ended · $range';
  }
}

/// Starts [mode], confirming first when another one is ON (it ends).
Future<void> startModeWithConfirm(
  BuildContext context,
  WidgetRef ref,
  ModeRow mode,
) async {
  final db = ref.read(dbProvider);
  final active = ref.read(activeModeProvider);
  if (active != null && active.id != mode.id) {
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${mode.name}?'),
        content: Text(
          '${active.name} is ON. Only one mode runs at a time, so it ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  await db.startMode(mode.id);
  ref.read(modeFullAppProvider.notifier).state = false;
}

/// Asks before ending [mode]; true = end it.
Future<bool> confirmEndMode(BuildContext context, ModeRow mode) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End ${mode.name}?'),
        content: const Text(
          'New spends stop joining it and the app goes back to everyday. '
          'You can start it again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End'),
          ),
        ],
      ),
    ) ==
    true;

/// Ends [mode] after a confirm, then shows its summary.
Future<void> endModeWithConfirm(
  BuildContext context,
  WidgetRef ref,
  ModeRow mode,
) async {
  if (!await confirmEndMode(context, mode) || !context.mounted) return;
  final router = GoRouter.of(context);
  await ref.read(dbProvider).endMode(mode.id);
  ref.read(modeFullAppProvider.notifier).state = false;
  // The trip, told back: what it came to and who owes whom.
  await router.push('/mode/${mode.id}/summary');
}

/// ON / OFF for one mode — the same switch on its card and its page. On
/// ends whichever other mode was ON (after asking); off asks first, then
/// shows the mode's summary.
class ModeSwitch extends ConsumerWidget {
  const ModeSwitch(this.mode, {super.key});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = mode.status == ModeStatus.active;
    return Switch(
      value: on,
      onChanged: (v) => v
          ? startModeWithConfirm(context, ref, mode)
          : endModeWithConfirm(context, ref, mode),
    );
  }
}

/// The mode that's ON, as one floating circle in the top-left corner of the
/// tabs: filled in its colour while the app is the mode, a ring once you've
/// stepped out to the full app. Tap it for the mode's name and day, Full
/// app / Back, its page and End.
class ModeOrb extends ConsumerWidget {
  const ModeOrb({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(activeModeProvider);
    if (mode == null) return const SizedBox.shrink();
    final fullApp = ref.watch(modeFullAppProvider);
    final color = Color(mode.colorValue);
    return Tooltip(
      message: fullApp ? '${mode.name} is ON' : mode.name,
      child: Semantics(
        button: true,
        label: '${mode.name} mode',
        child: GestureDetector(
          key: const ValueKey('modeOrb'),
          onTap: () => showModeOrbSheet(context, mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fullApp ? color.withValues(alpha: 0.12) : color,
              border: Border.all(color: color, width: fullApp ? 2 : 0),
              boxShadow: fullApp
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: KeyIcon(
              mode.iconKey,
              color: fullApp ? color : Colors.white,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

enum _OrbAction { open, toggle, end }

/// The orb's sheet. Everything it does runs after the sheet has closed,
/// through what was captured before — under Glass a sheet can take its
/// opener out of the tree.
Future<void> showModeOrbSheet(BuildContext context, ModeRow mode) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final router = GoRouter.of(context);
  final fullApp = container.read(modeFullAppProvider);
  final day = modeDayNumber(mode, DateTime.now());
  final action = await showAppSheet<_OrbAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppListTile(
            leading: ModeBadge(mode, size: 44),
            title: Text(
              mode.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                fullApp ? 'ON · showing the full app' : 'ON',
                if (day != null) 'Day $day',
              ].join(' · '),
            ),
          ),
          const Divider(height: 1),
          AppListTile(
            leading: const AppIcon(Icons.open_in_new_rounded),
            title: Text('Open ${mode.name}'),
            subtitle: const Text('Its page — spent, people, every transaction'),
            onTap: () => Navigator.of(context).pop(_OrbAction.open),
          ),
          AppListTile(
            leading: AppIcon(
              fullApp ? Icons.filter_center_focus_rounded : Icons.apps_rounded,
            ),
            title: Text(fullApp ? 'Back to ${mode.name}' : 'Full app'),
            subtitle: Text(
              fullApp
                  ? 'Show only the mode again'
                  : 'Everything, for now — the mode stays ON',
            ),
            onTap: () => Navigator.of(context).pop(_OrbAction.toggle),
          ),
          AppListTile(
            leading: const AppIcon(Icons.stop_circle_outlined),
            title: Text('End ${mode.name}'),
            subtitle: const Text('See its summary'),
            onTap: () => Navigator.of(context).pop(_OrbAction.end),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  switch (action) {
    case null:
      return;
    case _OrbAction.open:
      await router.push('/mode/${mode.id}');
    case _OrbAction.toggle:
      container.read(modeFullAppProvider.notifier).state = !fullApp;
    case _OrbAction.end:
      final dialogContext = router.routerDelegate.navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) return;
      if (!await confirmEndMode(dialogContext, mode)) return;
      await container.read(dbProvider).endMode(mode.id);
      container.read(modeFullAppProvider.notifier).state = false;
      await router.push('/mode/${mode.id}/summary');
  }
}

/// Spent so far, against the budget if there is one, with the per-day
/// average — the top of a mode's page and of its home.
class ModeSpendCard extends StatelessWidget {
  const ModeSpendCard({
    required this.mode,
    required this.summary,
    this.currencyNote,
    super.key,
  });

  final ModeRow mode;
  final ModeSummary summary;
  final String? currencyNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final budget = mode.budget;
    final days = modeDaysElapsed(mode, DateTime.now());
    final perDay = Money(summary.spent.paise ~/ days);
    final share = budget == null || budget.paise == 0
        ? 0.0
        : summary.spent.paise / budget.paise;
    final over = budget != null && summary.spent.paise > budget.paise;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spent',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(
                summary.spent,
                color: AppColors.expense,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (budget != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: share.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: over ? AppColors.expense : Color(mode.colorValue),
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                over
                    ? 'Over the ${MoneyFormat.symbol(budget)} budget by '
                          '${MoneyFormat.symbol(summary.spent - budget)}'
                    : '${MoneyFormat.symbol(budget - summary.spent)} left of '
                          '${MoneyFormat.symbol(budget)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: over ? AppColors.expense : cs.onSurfaceVariant,
                  fontWeight: over ? FontWeight.w600 : null,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _Fact(label: 'Per day', value: MoneyFormat.symbol(perDay)),
                _Fact(label: 'Days', value: '$days'),
                _Fact(label: 'Spends', value: '${summary.count}'),
                if (currencyNote != null)
                  _Fact(label: 'Currency', value: currencyNote!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// One slice of a mode's spending (a category, an account) with a bar for
/// its share.
class ModeShareRow extends StatelessWidget {
  const ModeShareRow({
    required this.iconKey,
    required this.colorValue,
    required this.label,
    required this.amount,
    required this.total,
    this.onTap,
    super.key,
  });

  final String iconKey;
  final int colorValue;
  final String label;
  final Money amount;
  final Money total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(colorValue);
    final share = total.paise == 0 ? 0.0 : amount.paise / total.paise;
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: IconWell.forKey(iconKey, color: color, size: 18),
      ),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 4,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      trailing: MoneyText(
        amount,
        color: AppColors.expense,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A transaction on a mode's page or home: signed from the person's side —
/// money out negative, money in positive, a transfer plain.
class ModeTxRow extends ConsumerWidget {
  const ModeTxRow(this.tx, {super.key});

  final TransactionRow tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final persons = ref.watch(allPersonsByIdProvider);
    final category = tx.categoryId == null ? null : categories[tx.categoryId];
    final isTransfer = tx.type == TxType.transfer;
    final accent = txIconColor(
      tx.type,
      isTransfer
          ? AppColors.transfer
          : (category != null
                ? Color(category.colorValue)
                : theme.colorScheme.onSurfaceVariant),
    );
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : tx.type.isPersonMovement || tx.type.isCorrection
        ? iconForTxType(tx.type)
        : AppIcons.resolve(category?.iconKey ?? 'other');
    final payee = tx.payee?.trim();
    final note = tx.note?.trim();
    final title = (payee != null && payee.isNotEmpty)
        ? payee
        : tx.type.isPersonMovement
        ? (persons[tx.personId]?.name ?? 'Person')
        : isTransfer
        ? 'Transfer'
        : (note != null && note.isNotEmpty)
        ? note
        : (category?.name ?? 'Uncategorised');
    final subtitle = [
      DateFormat('d MMM').format(tx.date),
      if (category != null && title != category.name) category.name,
      if (isTransfer)
        '${accounts[tx.accountId]?.name ?? '?'} → '
            '${accounts[tx.toAccountId]?.name ?? '?'}'
      else
        ?accounts[tx.accountId]?.name,
    ].join(' · ');
    final signed = switch (tx.type) {
      TxType.expense || TxType.personOut || TxType.correctionOut => -tx.amount,
      _ => tx.amount,
    };

    return NctVeil(
      active: tx.isNct,
      child: AppListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onTap: () => context.push('/transaction/${tx.id}'),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.14),
          child: transactionRowIcon(
            customIcon:
                tx.customIcon ??
                (isTransfer ? null : AppIcons.emojiOf(category?.iconKey)),
            fallback: icon,
            size: 20,
            color: accent,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: MoneyText(
          signed,
          signed: !isTransfer,
          color: colorForTxType(tx.type),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Small uppercase section heading, as on every detail page.
Widget modeSectionLabel(ThemeData theme, String text) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
  child: Text(
    text,
    style: theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  ),
);

/// Ask, then put [txId] in a mode (or none). Returns whether it changed.
Future<bool> pickModeForTransaction(
  BuildContext context,
  WidgetRef ref,
  int txId,
) async {
  final modes = ref.read(modesProvider).valueOrNull ?? const [];
  if (modes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No modes yet — make one in More → Modes')),
    );
    return false;
  }
  final picked = await showAppSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Add to a mode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in modes)
                    AppListTile(
                      leading: ModeBadge(m, size: 36),
                      title: Text(m.name),
                      subtitle: Text(modeStatusLine(m, DateTime.now())),
                      onTap: () => Navigator.of(context).pop(m.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return false;
  await ref.read(dbProvider).setTransactionMode(txId, picked);
  return true;
}

/// A mode's planned costs: paid ones ticked (tap opens the payment),
/// unpaid ones open Add filled in to pay them.
class ModePlannedCostsCard extends ConsumerWidget {
  const ModePlannedCostsCard({
    required this.mode,
    required this.costs,
    super.key,
  });

  final ModeRow mode;
  final List<ModePlannedCostRow> costs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cats = ref.watch(categoryMapProvider);
    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, c) in costs.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
            AppListTile(
              onTap: () => c.transactionId != null
                  ? context.push('/transaction/${c.transactionId}')
                  : context.push('/add?type=expense&plannedCost=${c.id}'),
              leading: AppIcon(
                c.transactionId != null
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: c.transactionId != null
                    ? AppColors.income
                    : cs.onSurfaceVariant,
              ),
              title: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: c.transactionId != null
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: cs.onSurfaceVariant,
                      )
                    : null,
              ),
              subtitle: Text(
                [
                  c.transactionId != null ? 'Paid' : 'Tap to pay',
                  ?cats[c.categoryId]?.name,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: MoneyText(
                c.amount,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The hero: what's left to spend — budget minus spent minus the planned
/// costs still to pay — or, with no budget, what's been spent.
class ModeLeftToSpendCard extends ConsumerWidget {
  const ModeLeftToSpendCard({required this.mode, super.key});

  final ModeRow mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final b = ref.watch(modeBudgetProvider(mode.id));
    final color = Color(mode.colorValue);
    final budget = b.budget;
    final left = b.left;
    final over = left != null && left.isNegative;
    final used = budget == null || budget.paise == 0
        ? 0.0
        : (b.spent + b.planned).paise / budget.paise;

    return AppCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ModeBadge(mode, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    modeStatusLine(mode, DateTime.now()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              left == null
                  ? 'Spent'
                  : over
                  ? 'Over budget by'
                  : 'Left to spend',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(
                left == null ? b.spent : left.abs,
                color: left == null || over ? AppColors.expense : null,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (budget != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: used.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: over ? AppColors.expense : color,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  '${MoneyFormat.symbol(b.spent)} spent',
                  if (b.planned.isPositive)
                    '${MoneyFormat.symbol(b.planned)} planned',
                  'of ${MoneyFormat.symbol(budget)}',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Set a budget (or account allocations) to see what’s left.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ModeLimitsCard extends ConsumerWidget {
  const ModeLimitsCard({required this.lines, super.key});

  final List<ModeLimitLine> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cats = ref.watch(categoryMapProvider);
    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, l) in lines.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
            Builder(
              builder: (context) {
                final cat = cats[l.categoryId];
                final color = cat == null
                    ? cs.onSurfaceVariant
                    : Color(cat.colorValue);
                final over = l.spent.paise > l.limit.paise;
                final share = l.limit.paise == 0
                    ? 0.0
                    : l.spent.paise / l.limit.paise;
                return AppListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconWell.forKey(
                      cat?.iconKey ?? 'other',
                      color: color,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    cat?.name ?? 'Category',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 4,
                        color: over ? AppColors.expense : color,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  trailing: Text(
                    over
                        ? '${MoneyFormat.compact(l.spent - l.limit)} over'
                        : '${MoneyFormat.compact(l.limit - l.spent)} left',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: over ? AppColors.expense : null,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The mode's accounts — what's left of each allocation, or the real
/// balance where none was set.
class ModeAccountsCard extends ConsumerWidget {
  const ModeAccountsCard({required this.balances, super.key});

  final Map<int, ModeAccountBalance> balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accounts = ref.watch(accountMapProvider);
    final entries = balances.entries.toList();
    return AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: cs.outline),
            AppListTile(
              onTap: () => context.push('/account/${e.key}'),
              leading: CircleAvatar(
                backgroundColor: Color(
                  accounts[e.key]?.colorValue ?? cs.primary.toARGB32(),
                ).withValues(alpha: 0.15),
                child: AppIcon(
                  AppIcons.resolve(accounts[e.key]?.iconKey ?? 'bank'),
                  size: 18,
                  color: Color(
                    accounts[e.key]?.colorValue ?? cs.primary.toARGB32(),
                  ),
                ),
              ),
              title: Text(
                accounts[e.key]?.name ?? 'Account',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                e.value.allocation == null
                    ? 'Real balance'
                    : 'Of ${MoneyFormat.symbol(e.value.allocation!)} for the trip',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: BalanceText(e.value.balance),
            ),
          ],
        ],
      ),
    );
  }
}
