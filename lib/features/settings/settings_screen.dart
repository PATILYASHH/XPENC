import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../data/providers.dart';
import 'theme_picker_sheet.dart';

/// App preferences. Most rows are placeholders for later phases; "Recalculate
/// balances" is real and rebuilds every account balance from the ledger.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final settingsAsync = ref.watch(settingsProvider);
    // Never crash while settings are still loading — fall back to a safe default.
    final autoApprove = settingsAsync.valueOrNull?.autoApprove ?? false;
    final preset = ref.watch(themePresetProvider);

    final trailingStyle =
        theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // ── General ────────────────────────────────────────────────────────
          _sectionLabel(context, 'General'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.currency_rupee_rounded),
                  title: const Text('Currency'),
                  trailing: Text('₹ INR', style: trailingStyle),
                  onTap: () => _soon(context),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(preset.icon),
                  title: const Text('Theme'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset.label, style: trailingStyle),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => ThemePickerSheet.show(context),
                ),
              ],
            ),
          ),

          // ── Message capture ────────────────────────────────────────────────
          _sectionLabel(context, 'Message Capture'),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.auto_mode_outlined),
              title: const Text('Auto-Approve'),
              subtitle: Text(
                "Auto-fill and post transactions from banks you've categorised "
                'before. Cards still appear so you can see what was filled.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              value: autoApprove,
              // Feature lands in a later phase — read-only for now.
              onChanged: null,
            ),
          ),

          // ── Data ───────────────────────────────────────────────────────────
          _sectionLabel(context, 'Data'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Recalculate balances'),
              subtitle: Text(
                'Rebuild every balance from the ledger. Safe to run any time.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(dbProvider).recalculateBalances();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Balances recalculated')),
                  );
              },
            ),
          ),

          // ── About ──────────────────────────────────────────────────────────
          _sectionLabel(context, 'About'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const BrandMark(size: 34),
              title: const Text('${AppInfo.name} · ${AppInfo.version}'),
              subtitle: Text(
                'Developer, links and build info',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/about'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }
}
