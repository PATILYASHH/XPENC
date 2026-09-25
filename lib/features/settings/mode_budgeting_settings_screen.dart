import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/budget_cycle.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show AppMode;
import 'app_mode_sheet.dart';
import 'budget_start_day_sheet.dart';

/// Mode & Budgeting — which features are switched on (Basic/Medium/Pro) and
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
      appBar: AppBar(title: const Text('Mode & Budgeting')),
      body: ListView(
        // Explicit padding drops ListView's nav-bar inset; re-add it (#137).
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          32 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('App mode'),
                  subtitle: Text(
                    switch (appMode) {
                      AppMode.basic => 'Basic — transactions & persons only',
                      AppMode.medium =>
                        'Medium — adds accounts, budgets, net worth',
                      AppMode.pro =>
                        'Pro — adds envelope mode & rollover budgets',
                    },
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => AppModeSheet.show(context),
                ),
                // Basic has no budgets at all.
                if (appMode != AppMode.basic) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.event_repeat_outlined),
                    title: const Text('Budget cycle start day'),
                    subtitle: Text(
                      budgetStartDay == 1
                          ? '1st of the month — an ordinary calendar month'
                          : '${ordinalDay(budgetStartDay)} of the month, '
                                'e.g. a payday-anchored cycle',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => BudgetStartDaySheet.show(context),
                  ),
                ],
                // Envelope mode / Ready to Assign is Pro-only (see AppMode)
                // — Medium has budgets without it.
                if (appMode == AppMode.pro) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const Icon(Icons.savings_outlined),
                    title: const Text('Ready to Assign'),
                    subtitle: Text(
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Turn on Ready to Assign?'),
          content: const Text(
            'Every account joins the shared pool right away. You can opt '
            'individual accounts back out afterward from their own Account '
            'Detail screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(dbProvider).setRtaEnabled(enabled);
  }
}
