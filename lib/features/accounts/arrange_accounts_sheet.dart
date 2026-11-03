import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Arrange accounts (GitHub #190): drag the accounts into the order the
/// Dashboard and Accounts show them in. Opened by holding an account on the
/// Dashboard, or from Customize dashboard. Each drop is saved as it lands;
/// there's nothing to confirm.
Future<void> showArrangeAccountsSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showAppSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ArrangeAccounts(),
  );
}

class _ArrangeAccounts extends ConsumerStatefulWidget {
  const _ArrangeAccounts();

  @override
  ConsumerState<_ArrangeAccounts> createState() => _ArrangeAccountsState();
}

class _ArrangeAccountsState extends ConsumerState<_ArrangeAccounts> {
  /// The order on screen. Kept here so a drop shows the instant it lands,
  /// not a frame later once the database has caught up.
  List<AccountRow> _order = const [];

  void _move(int from, int to) {
    // ReorderableListView reports the slot *before* the item moves out.
    if (to > from) to--;
    if (to == from) return;
    HapticFeedback.selectionClick();
    final order = [..._order];
    order.insert(to, order.removeAt(from));
    setState(() => _order = order);
    ref.read(dbProvider).reorderAccounts([for (final a in order) a.id]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accounts = ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
    // Follow the database whenever the set of accounts — or a balance —
    // changes under the sheet; the order we just set is already its order.
    final byId = {for (final a in accounts) a.id: a};
    final sameSet =
        _order.length == accounts.length &&
        _order.every((a) => byId.containsKey(a.id));
    _order = sameSet ? [for (final a in _order) byId[a.id]!] : accounts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arrange accounts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Drag them into the order you want on the Dashboard and in '
                'Accounts.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _order.length,
            onReorder: _move,
            proxyDecorator: (child, _, animation) => AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) => Transform.scale(
                scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
                child: Material(
                  type: MaterialType.transparency,
                  elevation: 8 * animation.value,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
              ),
            ),
            itemBuilder: (context, i) {
              final account = _order[i];
              final color = Color(account.colorValue);
              // A long press anywhere on the row picks it up too.
              return ReorderableDelayedDragStartListener(
                key: ValueKey(account.id),
                index: i,
                child: AppListTile(
                  contentPadding: const EdgeInsets.fromLTRB(20, 2, 8, 2),
                  leading: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                    ),
                    child: IconWell(
                      AppIcons.resolve(account.iconKey),
                      size: 18,
                      color: color,
                    ),
                  ),
                  title: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: BalanceText(account.currentBalance),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AppIcon(
                        Icons.drag_handle_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
