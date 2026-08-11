import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/home_widget/home_widget_service.dart';
import '../../data/providers.dart';

/// Home-screen widgets — three presets, not a from-scratch designer (Android's
/// RemoteViews format has hard limits on what a widget can even be: no
/// free-form layouts, no real text entry, so "design your own" here means
/// "pick one of these", not a canvas). Each card can prompt the launcher to
/// pin it directly; where that isn't supported, the fallback is the
/// system's own "long-press home screen → Widgets" picker.
class WidgetsScreen extends ConsumerWidget {
  const WidgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPin = ref.watch(_canRequestPinProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Widgets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _IntroCard(canPin: canPin),
          const SizedBox(height: 20),
          _WidgetCard(
            widget: HomeScreenWidget.balance,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Balance',
            description:
                'Your total balance, plus "+ Expense" / "+ Income" '
                'shortcuts.',
            canPin: canPin,
          ),
          const SizedBox(height: 12),
          _WidgetCard(
            widget: HomeScreenWidget.budgets,
            icon: Icons.pie_chart_outline_rounded,
            title: 'Budgets',
            description:
                'Your top budgets, closest to their limit first — up to '
                '${HomeWidgetService.maxBudgetLines}.',
            canPin: canPin,
          ),
          const SizedBox(height: 12),
          _WidgetCard(
            widget: HomeScreenWidget.quickAdd,
            icon: Icons.flash_on_outlined,
            title: 'Quick Add',
            description:
                'Just the "+ Expense" / "+ Income" shortcuts, enlarged — '
                'for a dedicated one-tap-to-log tile.',
            canPin: canPin,
          ),
        ],
      ),
    );
  }
}

final _canRequestPinProvider = FutureProvider<bool>(
  (ref) => ref.read(homeWidgetServiceProvider).canRequestPin(),
);

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.canPin});

  final bool canPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.widgets_outlined, color: cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                canPin
                    ? 'Tap "Add to home screen" on any of these, or add '
                          'them the usual way: long-press your home screen '
                          '→ Widgets → XPENC.'
                    : 'Add any of these the usual way: long-press your '
                          'home screen → Widgets → XPENC — your launcher '
                          "doesn't support adding widgets from inside an "
                          'app.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetCard extends ConsumerWidget {
  const _WidgetCard({
    required this.widget,
    required this.icon,
    required this.title,
    required this.description,
    required this.canPin,
  });

  final HomeScreenWidget widget;
  final IconData icon;
  final String title;
  final String description;
  final bool canPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: cs.onSurface, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (canPin) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () =>
                    ref.read(homeWidgetServiceProvider).requestPin(widget),
                child: const Text('Add to home screen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
