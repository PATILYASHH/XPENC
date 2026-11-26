import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget_cycle.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import 'app_mode_sheet.dart';
import 'budget_start_day_sheet.dart';
import '../../core/l10n/l10n.dart';

/// Level & Budgeting — which features are switched on (Basic/Medium/Pro) and
/// how the budget cycle and Ready to Assign behave.
class ModeBudgetingSettingsScreen extends ConsumerWidget {
  const ModeBudgetingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final rtaEnabled = ref.watch(rtaEnabledProvider);
    final budgetStartDay = ref.watch(budgetStartDayProvider);
    final appMode = ref.watch(appModeProvider);

    return Scaffold(
      appBar: AppTopBar(title: const Tr('Level & Budgeting')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const AppIcon(Icons.tune_outlined),
                  title: const Tr('App level'),
                  subtitle: Text(
                    switch (appMode) {
                      AppMode.basic => tr('Basic — transactions & persons only'),
                      AppMode.medium =>
                        tr('Medium — adds accounts, budgets, net worth'),
                      AppMode.pro =>
                        tr('Pro — adds envelope mode & rollover budgets'),
                    },
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const AppIcon(Icons.chevron_right_rounded),
                  onTap: () => AppModeSheet.show(context),
                ),
                // Basic has no budgets at all.
                if (appMode != AppMode.basic) ...[
                  Divider(height: 1, indent: 60),
                  AppListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const AppIcon(Icons.event_repeat_outlined),
                    title: const Tr('Budget cycle start day'),
                    subtitle: Text(
                      switch (budgetStartDay) {
                        1 => tr('1st of the month — an ordinary calendar month'),
                        kLastWorkingDay =>
                          tr('Last working day of the month — a payday-anchored '
                              'cycle'),
                        _ =>
                          tr('{0} of the month, '
                              'e.g. a payday-anchored cycle', [ordinalDay(budgetStartDay)]),
                      },
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const AppIcon(Icons.chevron_right_rounded),
                    onTap: () => BudgetStartDaySheet.show(context),
                  ),
                ],
                // Envelope mode / Ready to Assign is Pro-only (see AppMode)
                // — Medium has budgets without it.
                if (appMode == AppMode.pro) ...[
                  Divider(height: 1, indent: 60),
                  AppSwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const AppIcon(Icons.savings_outlined),
                    title: const Tr('Ready to Assign'),
                    subtitle: Tr(
                      'Budget (a spending ceiling per category) is always '
                      'on. Ready to Assign adds an optional layer on top: '
                      'assign the money you actually have into categories '
                      'first, pooled across every on-budget account. '
                      'Turning this on enrolls every account at once — opt '
                      'individual ones out from their own Account Detail '
                      'screen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    value: rtaEnabled,
                    onChanged: (v) => _onRtaToggle(context, ref, v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Turning Ready to Assign on is a bulk action — every account joins the
  /// shared pool at once — so it gets the same confirm-on-enable treatment
  /// as the per-account on-budget toggle; turning it off needs no
  /// confirmation, same as there.
  Future<void> _onRtaToggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Tr('Turn on Ready to Assign?'),
          content: const Tr(
            'Every account joins the shared pool right away. You can opt '
            'individual accounts back out afterward from their own Account '
            'Detail screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Tr('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Tr('Turn on'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(dbProvider).setRtaEnabled(enabled);
  }
}
