import 'dart:math' as math;

import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/theme/glass.dart' show AppSurface;
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../data/database.dart';
import '../../data/mode_providers.dart';
import '../../data/providers.dart';
import '../../data/tables.dart';
import '../../core/l10n/l10n.dart';

/// The accounts a picker may offer: none excluded by [excludeId] or
/// [excludeIds], goals only when [excludeGoals] is off or the goal is one
/// of [moneyInOutGoals] (#173), only [onlyTypes] when set, and only what a
/// mode allows ([allowed]; empty = no limit). Shared by the account strip
/// and the account picker sheet, so both always agree.
List<AccountRow> eligibleAccounts(
  List<AccountRow> accounts, {
  int? excludeId,
  Set<int> excludeIds = const {},
  bool excludeGoals = false,
  Set<int> moneyInOutGoals = const {},
  Set<AccountType>? onlyTypes,
  Set<int> allowed = const {},
}) => [
  for (final a in accounts)
    if (a.id != excludeId &&
        !excludeIds.contains(a.id) &&
        (!excludeGoals ||
            a.type != AccountType.goal ||
            moneyInOutGoals.contains(a.id)) &&
        (onlyTypes?.contains(a.type) ?? true) &&
        (allowed.isEmpty || allowed.contains(a.id)))
      a,
];

/// How long a card has to be held before the strip turns editable.
const kAccountStripHoldToEdit = Duration(seconds: 1);

/// Add Transaction's account picker: the accounts as cards in a row that
/// swipes sideways, tap one to pay with it. Holding a card for a second
/// makes the strip editable: the cards wiggle, ‹ › move one back or
/// forward (the same order the Dashboard and Accounts use, #190) and ✕
/// takes one off the strip ([AccountRow.showOnAddPage]). Taken-off cards
/// wait at the end, dimmed, with ＋ to put them back. Out of edit mode a
/// "more" card at the end opens every account ([onMore]), so a card taken
/// off never stops an account being picked.
class AccountStrip extends ConsumerStatefulWidget {
  const AccountStrip({
    required this.label,
    required this.selectedId,
    required this.onSelected,
    required this.onMore,
    this.excludeId,
    this.modeId,
    this.excludeGoals = false,
    this.moneyInOut = false,
    super.key,
  });

  /// "Paid via", "Deposit to", "From account", "To account".
  final String label;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  /// Opens every account the strip would offer, taken-off ones included.
  final VoidCallback onMore;

  /// See [eligibleAccounts].
  final int? excludeId;
  final int? modeId;
  final bool excludeGoals;
  final bool moneyInOut;

  static const cardWidth = 148.0;
  static const gap = 10.0;

  @override
  ConsumerState<AccountStrip> createState() => _AccountStripState();
}

class _AccountStripState extends ConsumerState<AccountStrip>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  bool _editing = false;

  // What edit mode changed, shown at once rather than a frame later when
  // the database stream catches up. Cleared on leaving edit mode.
  List<int>? _order;
  final Map<int, bool> _shown = {};

  // Made in initState, never lazily: a `late` controller first touched in
  // dispose() would create its ticker on a deactivated element, which
  // Flutter 3.38 (CI's) asserts on.
  late final AnimationController _wiggle;

  @override
  void didUpdateWidget(AccountStrip old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) _revealSelectedLater();
  }

  @override
  void initState() {
    super.initState();
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _revealSelectedLater(animate: false);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  bool _isShown(AccountRow a) => _shown[a.id] ?? a.showOnAddPage;

  /// The cards out of edit mode, in order: every shown account, plus the
  /// picked one even if it was taken off (it's what this entry uses).
  List<AccountRow> _visible(List<AccountRow> eligible) => [
    for (final a in eligible)
      if (_isShown(a) || a.id == widget.selectedId) a,
  ];

  List<AccountRow> _ordered(List<AccountRow> list) {
    final order = _order;
    if (order == null) return list;
    int rank(AccountRow a) {
      final i = order.indexOf(a.id);
      return i == -1 ? order.length : i;
    }

    return [...list]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// Scrolls the picked card to the middle of the row (just the row — the
  /// page itself doesn't move).
  void _revealSelectedLater({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _editing) return;
      final eligible = _eligible();
      final cards = _ordered(_visible(eligible));
      final index = cards.indexWhere((a) => a.id == widget.selectedId);
      if (index < 0) return;
      final position = _scroll.position;
      const step = AccountStrip.cardWidth + AccountStrip.gap;
      final target =
          (20 +
                  index * step -
                  (position.viewportDimension - AccountStrip.cardWidth) / 2)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((target - position.pixels).abs() < 1) return;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  List<AccountRow> _eligible() {
    final accounts = ref.read(accountsProvider).valueOrNull ?? const [];
    return eligibleAccounts(
      accounts,
      excludeId: widget.excludeId,
      excludeGoals: widget.excludeGoals,
      moneyInOutGoals: widget.moneyInOut
          ? ref.read(moneyInOutGoalIdsProvider)
          : const {},
      allowed: widget.modeId == null
          ? const {}
          : ref.read(modeConfigProvider(widget.modeId!)).accountIds,
    );
  }

  void _startEditing() {
    if (_editing) return;
    HapticFeedback.heavyImpact();
    setState(() => _editing = true);
    if (!MediaQuery.disableAnimationsOf(context)) _wiggle.repeat();
  }

  void _stopEditing() {
    HapticFeedback.selectionClick();
    _wiggle
      ..stop()
      ..value = 0;
    setState(() {
      _editing = false;
      _order = null;
      _shown.clear();
    });
    _revealSelectedLater();
  }

  /// Moves [cards]\[index\] one place back (-1) or forward (+1), and saves
  /// the new order of the shown cards.
  void _move(List<AccountRow> cards, int index, int by) {
    final to = index + by;
    if (to < 0 || to >= cards.length) return;
    HapticFeedback.selectionClick();
    final ids = [for (final a in cards) a.id];
    final id = ids.removeAt(index);
    ids.insert(to, id);
    setState(
      () => _order = [...ids, ...?_order?.where((i) => !ids.contains(i))],
    );
    ref.read(dbProvider).reorderAccounts(ids);
  }

  void _setShown(AccountRow a, bool shown) {
    HapticFeedback.selectionClick();
    setState(() => _shown[a.id] = shown);
    ref.read(dbProvider).setAccountShownOnAddPage(a.id, shown);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accounts = ref.watch(accountsProvider).valueOrNull;
    final moneyInOutGoals = widget.moneyInOut
        ? ref.watch(moneyInOutGoalIdsProvider)
        : const <int>{};
    final allowed = widget.modeId == null
        ? const <int>{}
        : ref.watch(modeConfigProvider(widget.modeId!)).accountIds;
    final eligible = eligibleAccounts(
      accounts ?? const [],
      excludeId: widget.excludeId,
      excludeGoals: widget.excludeGoals,
      moneyInOutGoals: moneyInOutGoals,
      allowed: allowed,
    );
    final accountMap = ref.watch(accountMapProvider);

    final List<AccountRow> cards;
    final List<AccountRow> removed;
    if (_editing) {
      cards = _ordered([
        for (final a in eligible)
          if (_isShown(a)) a,
      ]);
      removed = [
        for (final a in eligible)
          if (!_isShown(a)) a,
      ];
    } else {
      cards = _ordered(_visible(eligible));
      removed = const [];
    }
    final hiddenCount = _editing ? 0 : eligible.length - cards.length;

    final textScale = MediaQuery.textScalerOf(context).scale(40);
    final cardHeight = 70 + textScale;
    final height = cardHeight + (_editing ? 44 : 0);

    return PopScope(
      // Back leaves edit mode before it leaves the page.
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _stopEditing();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      _editing ? tr('Arrange accounts') : widget.label,
                      key: ValueKey(_editing),
                      style: _editing
                          ? theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            )
                          : theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                    ),
                  ),
                ),
                // Nothing picked yet: say so, and offer the full list.
                if (!_editing && widget.selectedId == null)
                  TextButton(
                    onPressed: widget.onMore,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Tr('Select account'),
                  ),
                if (_editing)
                  FilledButton.tonal(
                    key: const Key('accountStripDone'),
                    onPressed: _stopEditing,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Tr('Done'),
                  )
                else if (eligible.length > 1)
                  IconButton(
                    key: const Key('accountStripEdit'),
                    tooltip: tr('Arrange accounts'),
                    visualDensity: VisualDensity.compact,
                    onPressed: _startEditing,
                    icon: AppIcon(
                      Icons.tune_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tr(
                'Move a card with ‹ ›. ✕ takes it off this row; ＋ puts '
                'it back.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          if (accounts != null && eligible.isEmpty)
            AppCard(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Tr(
                  'No accounts available',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: height,
              // Edge to edge: the row runs under the page's side padding,
              // so cards slide in from the screen's edge, not a margin.
              child: LayoutBuilder(
                builder: (context, box) => OverflowBox(
                  maxWidth: box.maxWidth + 40,
                  minWidth: box.maxWidth + 40,
                  child: ListView(
                    key: const Key('accountStrip'),
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    clipBehavior: AppSurface.of(context).isGlass
                        ? Clip.none
                        : Clip.hardEdge,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: AccountStrip.gap),
                        _wiggling(
                          i,
                          _AccountCard(
                            key: ValueKey('accountCard:${cards[i].id}'),
                            account: cards[i],
                            linkedName:
                                accountMap[cards[i].linkedAccountId]?.name,
                            height: cardHeight,
                            selected: cards[i].id == widget.selectedId,
                            editing: _editing,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onSelected(cards[i].id);
                            },
                            onHold: _startEditing,
                            onRemove: () => _setShown(cards[i], false),
                            onBack: i == 0 ? null : () => _move(cards, i, -1),
                            onForward: i == cards.length - 1
                                ? null
                                : () => _move(cards, i, 1),
                          ),
                        ),
                      ],
                      for (final a in removed) ...[
                        const SizedBox(width: AccountStrip.gap),
                        _AccountCard(
                          key: ValueKey('accountCard:${a.id}'),
                          account: a,
                          linkedName: accountMap[a.linkedAccountId]?.name,
                          height: cardHeight,
                          selected: false,
                          editing: true,
                          removed: true,
                          onTap: () {},
                          onHold: () {},
                          onAddBack: () => _setShown(a, true),
                        ),
                      ],
                      if (hiddenCount > 0) ...[
                        const SizedBox(width: AccountStrip.gap),
                        _MoreCard(
                          count: hiddenCount,
                          height: cardHeight,
                          onTap: widget.onMore,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// In edit mode each card rocks a little, out of step with its
  /// neighbours, the way a home screen says "these can be moved".
  Widget _wiggling(int i, Widget child) {
    if (!_editing) return child;
    return AnimatedBuilder(
      animation: _wiggle,
      child: child,
      builder: (context, child) => Transform.rotate(
        angle: math.sin((_wiggle.value + i * 0.37) * 2 * math.pi) * 0.012,
        child: child,
      ),
    );
  }
}

/// One account as a card: its icon, name and balance (or, for a debit card,
/// the bank it draws from). The picked one is outlined in its own colour
/// and ticked. Holding it for [kAccountStripHoldToEdit] calls [onHold] — it
/// swells a little as it charges, so the wait never feels stuck.
class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.account,
    required this.linkedName,
    required this.height,
    required this.selected,
    required this.editing,
    required this.onTap,
    required this.onHold,
    this.removed = false,
    this.onRemove,
    this.onBack,
    this.onForward,
    this.onAddBack,
    super.key,
  });

  final AccountRow account;
  final String? linkedName;
  final double height;
  final bool selected;
  final bool editing;

  /// Taken off the strip — shown only in edit mode, dimmed, with ＋.
  final bool removed;
  final VoidCallback onTap;
  final VoidCallback onHold;
  final VoidCallback? onRemove;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback? onAddBack;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard>
    with SingleTickerProviderStateMixin {
  // In initState, not lazily — see `_AccountStripState._wiggle`. A card
  // shown only in edit mode never builds the hold that would touch it.
  late final AnimationController _charge;

  @override
  void initState() {
    super.initState();
    _charge = AnimationController(
      vsync: this,
      duration: kAccountStripHoldToEdit,
    );
  }

  @override
  void dispose() {
    _charge.dispose();
    super.dispose();
  }

  void _down() => _charge.forward(from: 0);

  void _cancel() => _charge.animateBack(
    0,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );

  void _fire() {
    widget.onHold();
    _charge.animateBack(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final a = widget.account;
    final color = Color(a.colorValue);
    final selected = widget.selected && !widget.editing;
    final isDebit = a.linkedAccountId != null;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
            ),
            child: IconWell(
              AppIcons.resolve(a.iconKey),
              size: 18,
              color: color,
            ),
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                if (isDebit)
                  Text(
                    tr('Draws from {0}', [
                      widget.linkedName ?? tr('linked bank'),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: BalanceText(
                      a.currentBalance,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget card = AppCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected
          ? Color.alphaBlend(color.withValues(alpha: 0.10), cs.surface)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? color : color.withValues(alpha: 0.28),
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(onTap: widget.editing ? null : widget.onTap, child: body),
    );

    // Badges sit inside the card's own corner, so the row never clips them.
    final badge = widget.removed
        ? _CornerButton(
            key: ValueKey('accountAddBack:${a.id}'),
            icon: Icons.add_rounded,
            color: cs.secondary,
            label: tr('Put {0} back', [a.name]),
            onTap: widget.onAddBack,
          )
        : widget.editing
        ? _CornerButton(
            key: ValueKey('accountRemove:${a.id}'),
            icon: Icons.close_rounded,
            color: cs.error,
            label: tr('Take {0} off this row', [a.name]),
            onTap: widget.onRemove,
          )
        : selected
        ? Container(
            key: ValueKey('accountPicked:${a.id}'),
            width: 20,
            height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: const AppIcon(
              Icons.check_rounded,
              size: 14,
              color: Colors.white,
            ),
          )
        : null;

    card = Stack(
      children: [
        Positioned.fill(child: card),
        if (badge != null) PositionedDirectional(top: 8, end: 8, child: badge),
      ],
    );

    if (!widget.editing) {
      card = RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: kAccountStripHoldToEdit,
                ),
                (r) => r
                  ..onLongPressDown = ((_) => _down())
                  ..onLongPressCancel = _cancel
                  ..onLongPress = _fire,
              ),
        },
        child: AnimatedBuilder(
          animation: _charge,
          child: card,
          builder: (context, child) {
            // Nothing for the first fifth, so a tap never wobbles.
            final v = Curves.easeInCubic.transform(
              ((_charge.value - 0.2) / 0.8).clamp(0.0, 1.0),
            );
            return Transform.scale(scale: 1 + 0.05 * v, child: child);
          },
        ),
      );
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      selected: selected,
      button: !widget.editing,
      label: a.name,
      child: SizedBox(
        width: AccountStrip.cardWidth,
        child: Column(
          children: [
            SizedBox(
              height: widget.height,
              child: Opacity(opacity: widget.removed ? 0.45 : 1, child: card),
            ),
            if (widget.editing)
              // Clipped: the row grows into edit mode on a short animation,
              // and the buttons mustn't overflow while it does.
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: 44,
                    child: widget.removed
                        ? Center(
                            child: Tr(
                              'Off this row',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StepButton(
                                key: ValueKey('accountBack:${a.id}'),
                                icon: rtl
                                    ? Icons.chevron_right_rounded
                                    : Icons.chevron_left_rounded,
                                label: tr('Move {0} back', [a.name]),
                                onTap: widget.onBack,
                              ),
                              _StepButton(
                                key: ValueKey('accountForward:${a.id}'),
                                icon: rtl
                                    ? Icons.chevron_left_rounded
                                    : Icons.chevron_right_rounded,
                                label: tr('Move {0} forward', [a.name]),
                                onTap: widget.onForward,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The last card when some accounts are off the row: how many, and a tap
/// opens them all.
class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.count,
    required this.height,
    required this.onTap,
  });

  final int count;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SizedBox(
      width: 104,
      height: height,
      child: AppCard(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('accountStripMore'),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(Icons.more_horiz_rounded, color: cs.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                tr('{0} more', [count]),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✕ or ＋ in a card's corner while editing.
class _CornerButton extends StatelessWidget {
  const _CornerButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 26,
            height: 26,
            child: AppIcon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// ‹ or › under a card while editing; null [onTap] = it's already at that
/// end.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled
            ? cs.surfaceContainerHighest
            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: AppIcon(
              icon,
              size: 20,
              color: enabled
                  ? cs.onSurface
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
