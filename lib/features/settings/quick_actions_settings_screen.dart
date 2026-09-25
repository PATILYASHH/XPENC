import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import 'settings_common.dart';

/// Quick Actions — shortcuts that don't fit any other module. Bank-SMS
/// capture and OCR corrections live under General's "Message Capture"
/// section instead; this page is for the home screen widgets picker and the
/// lock screen's own shortcuts (GitHub #138).
class QuickActionsSettingsScreen extends ConsumerWidget {
  const QuickActionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenshotShortcut = ref.watch(lockScreenScreenshotShortcutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Actions')),
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
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Home screen widgets'),
              subtitle: Text(
                'Balance, Budgets, Quick Add or This Month — pick what to '
                'put on your home screen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/settings/widgets'),
            ),
          ),
          settingsSectionLabel(context, 'Lock screen shortcuts'),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.screenshot_monitor_outlined),
              title: const Text('Screenshot blocking'),
              subtitle: Text(
                'Turn screenshot blocking on or off from the lock screen. '
                'On applies right away; off only after you unlock.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: screenshotShortcut,
              onChanged: (v) =>
                  ref.read(dbProvider).setLockScreenScreenshotShortcut(v),
            ),
          ),
        ],
      ),
    );
  }
}
