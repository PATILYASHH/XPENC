import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../core/widgets/custom_icon_badge.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/nav_bar_inset.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../dashboard/dashboard_layout.dart';
import 'settings_common.dart';

/// Settings ▸ Customize dashboard: which widgets the Dashboard shows and in
/// what order — drag to reorder, − to take one off, + to add one back — and
/// which accounts count toward Net Worth, shown wherever that figure appears
/// (Dashboard, Accounts screen total, More screen subtitle).
class DashboardSettingsScreen extends ConsumerStatefulWidget {
  const DashboardSettingsScreen({super.key});

  @override
  ConsumerState<DashboardSettingsScreen> createState() =>
      _DashboardSettingsScreenState();
}

class _DashboardSettingsScreenState
    extends ConsumerState<DashboardSettingsScreen> {
  /// Held here as well as in the database, so a drag lands where it was
  /// dropped this frame rather than snapping back until the write echoes.
  late List<DashboardSlot> _slots = ref.read(dashboardLayoutProvider);

  void _apply(List<DashboardSlot> next) {
    setState(() => _slots = next);
    ref.read(dbProvider).setDashboardLayout(encodeDashboardLayout(next));
  }

  @override
  Widget build(BuildContext context) {
    // A restore, or the first settings load, can change it underneath us.
    ref.listen(dashboardLayoutProvider, (_, next) {
      setState(() => _slots = next);
    });
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mode = ref.watch(appModeProvider);
    final rtaOn = ref.watch(rtaEnabledProvider);
    final shown = [
      for (final s in _slots)
        if (s.visible) s.widget,
    ];
    final hidden = [
      for (final s in _slots)
        if (!s.visible) s.widget,
    ];
    final isDefault =
        encodeDashboardLayout(_slots) ==
        encodeDashboardLayout(defaultDashboardLayout);
    const side = EdgeInsets.symmetric(horizontal: 20);

    String? noteFor(DashboardWidget w) =>
        w.unavailableNote(mode: mode, rtaOn: rtaOn);

    return Scaffold(
      appBar: AppTopBar(title: const Text('Customize dashboard')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: side,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  settingsSectionLabel(context, 'On your dashboard'),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Nothing yet — add a widget below.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Text(
                        'Hold a widget, or drag its handle, to move it. The '
                        'top of this list is the top of your dashboard.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: side,
            sliver: SliverReorderableList(
              itemCount: shown.length,
              onReorder: (from, to) {
                HapticFeedback.selectionClick();
                _apply(reorderDashboardWidgets(_slots, from, to));
              },
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                child: child,
                builder: (context, child) => Transform.scale(
                  scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
                  child: Material(
                    type: MaterialType.transparency,
                    elevation: 8 * animation.value,
                    shadowColor: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: child,
                  ),
                ),
              ),
              itemBuilder: (context, i) {
                final w = shown[i];
                return Padding(
                  key: ValueKey(w),
                  padding: const EdgeInsets.only(bottom: 8),
                  // A long press anywhere on the row picks it up too.
                  child: ReorderableDelayedDragStartListener(
                    index: i,
                    child: AppCard(
                      margin: EdgeInsets.zero,
                      child: _WidgetRow(
                        widget: w,
                        note: noteFor(w),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: AppIcon(
                              Icons.drag_handle_rounded,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        action: IconButton(
                          tooltip: 'Remove ${w.title}',
                          icon: const AppIcon(
                            Icons.remove_circle_rounded,
                            color: AppColors.expense,
                          ),
                          onPressed: () => _apply(
                            setDashboardWidgetVisible(
                              _slots,
                              w,
                              visible: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: side,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  settingsSectionLabel(context, 'Add widgets'),
                  if (hidden.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: Text(
                        'Every widget is on your dashboard.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    AppCard(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < hidden.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, indent: 60, color: cs.outline),
                            _WidgetRow(
                              widget: hidden[i],
                              note: noteFor(hidden[i]),
                              action: IconButton(
                                tooltip: 'Add ${hidden[i].title}',
                                icon: const AppIcon(
                                  Icons.add_circle_rounded,
                                  color: AppColors.income,
                                ),
                                onPressed: () => _apply(
                                  setDashboardWidgetVisible(
                                    _slots,
                                    hidden[i],
                                    visible: true,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (!isDefault)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => _apply(defaultDashboardLayout),
                          icon: const AppIcon(Icons.restart_alt_rounded),
                          label: const Text('Reset to default'),
                        ),
                      ),
                    ),
                  settingsSectionLabel(context, 'Included in Net Worth'),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              32,
            ).plusNavBar(context),
            sliver: const SliverToBoxAdapter(child: _NetWorthAccounts()),
          ),
        ],
      ),
    );
  }
}

/// One widget in either list: its icon and name, what it shows (or why the
/// current mode won't show it), a drag handle when it's on the dashboard,
/// and the button that adds or removes it.
class _WidgetRow extends StatelessWidget {
  const _WidgetRow({
    required this.widget,
    required this.action,
    this.note,
    this.leading,
  });

  final DashboardWidget widget;
  final Widget action;
  final String? note;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(leading == null ? 16 : 4, 8, 4, 8),
      child: Row(
        children: [
          ?leading,
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.secondary.withValues(alpha: 0.12),
            ),
            child: AppIcon(widget.icon, size: 18, color: cs.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  note ?? widget.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: note == null
                        ? cs.onSurfaceVariant
                        // Amber reads on dark; on light it needs depth.
                        : theme.brightness == Brightness.dark
                        ? Colors.amber
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}

/// Which accounts count toward Net Worth. Turn one off here (a savings goal
/// you're not counting as spendable, a second bank account you track
/// separately) and its balance stops adding to that number, while it keeps
/// showing everywhere else exactly as before.
class _NetWorthAccounts extends ConsumerWidget {
  const _NetWorthAccounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ref
        .watch(balanceAccountsProvider)
        .when(
          data: (accounts) => accounts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Add an account to see it here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              : AppCard(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < accounts.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, indent: 60, color: cs.outline),
                        _AccountToggleTile(account: accounts[i]),
                      ],
                    ],
                  ),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'Could not load your accounts.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        );
  }
}

class _AccountToggleTile extends ConsumerWidget {
  const _AccountToggleTile({required this.account});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(account.colorValue);
    return AppSwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: IconWell(
          AppIcons.resolve(account.iconKey),
          color: color,
          size: 20,
        ),
      ),
      title: Text(account.name),
      subtitle: BalanceText(
        account.currentBalance,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: account.includeInNetWorth,
      onChanged: (v) =>
          ref.read(dbProvider).setAccountIncludeInNetWorth(account.id, v),
    );
  }
}
