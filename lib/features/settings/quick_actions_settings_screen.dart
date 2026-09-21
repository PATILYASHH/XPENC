import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Quick Actions — shortcuts that don't fit any other module. Bank-SMS
/// capture and OCR corrections live under General's "Message Capture"
/// section instead; this page is for the home screen widgets picker.
class QuickActionsSettingsScreen extends StatelessWidget {
  const QuickActionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Actions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
        ],
      ),
    );
  }
}
