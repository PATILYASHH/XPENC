import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../data/providers.dart';
import 'currency_picker_sheet.dart';
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
    final notificationsEnabled =
        settingsAsync.valueOrNull?.notificationsEnabled ?? false;
    final preset = ref.watch(themePresetProvider);
    final currency = ref.watch(currencyProvider);
    final showSymbol = ref.watch(showCurrencySymbolProvider);
    final countRepaymentsAsIncome = ref.watch(countRepaymentsAsIncomeProvider);
    final hasPasscode = ref.watch(hasPasscodeProvider);
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final expenseReminder = ref.watch(expenseReminderProvider);

    final trailingStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );

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
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Currency'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currency.symbol} ${currency.code}',
                        style: trailingStyle,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  onTap: () => CurrencyPickerSheet.show(context, ref),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.attach_money_rounded),
                  title: const Text('Show currency symbol'),
                  subtitle: Text(
                    showSymbol
                        ? 'Amounts show ${currency.symbol}'
                        : 'Amounts show plain numbers — use this if your '
                              'currency symbol is missing',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: showSymbol,
                  onChanged: (v) =>
                      ref.read(dbProvider).setShowCurrencySymbol(v),
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

          // ── Persons ────────────────────────────────────────────────────────
          _sectionLabel(context, 'Persons'),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.handshake_outlined),
              title: const Text('Count repayments as income'),
              subtitle: Text(
                'Offers "Mark as repaid" on a person\'s page — a repayment '
                'posts as income under a category you choose, instead of '
                'staying off income/expense like lending normally does.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: countRepaymentsAsIncome,
              onChanged: (v) =>
                  ref.read(dbProvider).setCountRepaymentsAsIncome(v),
            ),
          ),

          // ── Security ───────────────────────────────────────────────────────
          _sectionLabel(context, 'Security'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(hasPasscode ? 'Change passcode' : 'Set passcode'),
                  subtitle: Text(
                    hasPasscode
                        ? 'A PIN is required to open the app'
                        : 'Require a PIN to open the app',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => context.push('/more/settings/passcode'),
                ),
                if (hasPasscode) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Biometric unlock'),
                    subtitle: Text(
                      'Use your fingerprint or face instead of the PIN — the '
                      'PIN always still works',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    value: biometricEnabled,
                    onChanged: (v) =>
                        ref.read(dbProvider).setBiometricEnabled(v),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(Icons.lock_open_outlined, color: cs.error),
                    title: Text(
                      'Remove passcode',
                      style: TextStyle(color: cs.error),
                    ),
                    onTap: () =>
                        context.push('/more/settings/passcode?remove=true'),
                  ),
                ],
              ],
            ),
          ),

          // ── Notifications ──────────────────────────────────────────────────
          _sectionLabel(context, 'Notifications'),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: Text(
                'Budget alerts and payment reminders.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: notificationsEnabled,
              onChanged: (v) => _toggleNotifications(ref, v),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.edit_note_rounded),
                  title: const Text('Daily expense reminder'),
                  subtitle: Text(
                    expenseReminder.enabled
                        ? "A daily nudge at ${_timeLabel(expenseReminder.hour, expenseReminder.minute)} to log today's spending"
                        : "Not tied to any bill — just a nudge to log today's spending",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: expenseReminder.enabled,
                  onChanged: (v) => _setExpenseReminder(
                    ref,
                    enabled: v,
                    hour: expenseReminder.hour,
                    minute: expenseReminder.minute,
                  ),
                ),
                if (expenseReminder.enabled) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Time'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timeLabel(
                            expenseReminder.hour,
                            expenseReminder.minute,
                          ),
                          style: trailingStyle,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () =>
                        _pickExpenseReminderTime(context, ref, expenseReminder),
                  ),
                ],
              ],
            ),
          ),

          // ── Message capture ────────────────────────────────────────────────
          _sectionLabel(context, 'Message Capture'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Bank-SMS auto-capture'),
              subtitle: Text(
                'Coming soon — removed for now so the app installs without a '
                'Play Protect block.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/capture'),
            ),
          ),

          // ── Data ───────────────────────────────────────────────────────────
          _sectionLabel(context, 'Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('Recalculate balances'),
                  subtitle: Text(
                    'Rebuild every balance from the ledger. Safe to run any time.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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
                Divider(height: 1, indent: 60, color: cs.outline),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Icon(Icons.delete_forever_outlined, color: cs.error),
                  title: Text('Clear all data', style: TextStyle(color: cs.error)),
                  subtitle: Text(
                    'Wipe every account, transaction, budget and person, and '
                    'start fresh. A safety backup is saved first.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _clearAllData(context, ref),
                ),
              ],
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
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

  /// A safety backup is taken first — same convention as restoring or
  /// importing a backup elsewhere in this screen's family — so a mistaken
  /// tap is recoverable from Backup & Restore afterward.
  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This wipes every account, transaction, category, budget, person '
          'and everything else on this phone, then starts fresh with the '
          'same defaults a new install gets. A safety backup is saved to '
          'Download/BACKUP XPENC first — restore it from Backup & Restore '
          'if this was a mistake.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(backupServiceProvider).createBackup();
      await ref.read(dbProvider).clearAllData();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('All data cleared. A safety backup was saved.'),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text("Couldn't clear data: $e")));
    }
  }

  Future<void> _toggleNotifications(WidgetRef ref, bool value) async {
    await ref.read(dbProvider).setNotificationsEnabled(value);
    if (value) {
      await ref.read(notificationServiceProvider).requestPermission();
    }
  }

  Future<void> _setExpenseReminder(
    WidgetRef ref, {
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await ref
        .read(dbProvider)
        .setExpenseReminder(enabled: enabled, hour: hour, minute: minute);
    await ref.read(notificationServiceProvider).syncExpenseReminder();
  }

  Future<void> _pickExpenseReminderTime(
    BuildContext context,
    WidgetRef ref,
    ExpenseReminderSettings current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await _setExpenseReminder(
      ref,
      enabled: true,
      hour: picked.hour,
      minute: picked.minute,
    );
  }

  String _timeLabel(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }
}
