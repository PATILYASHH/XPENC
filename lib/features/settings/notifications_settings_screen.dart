import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// Notifications — the master switch, the daily expense reminder, and quick
/// add straight from a notification's reply field.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trailingStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );

    final settingsAsync = ref.watch(settingsProvider);
    // Never crash while settings are still loading — fall back to a safe default.
    final notificationsEnabled =
        settingsAsync.valueOrNull?.notificationsEnabled ?? false;
    final expenseReminder = ref.watch(expenseReminderProvider);
    final notificationQuickAddEnabled = ref.watch(
      notificationQuickAddEnabledProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
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
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.flash_on_outlined),
                  title: const Text('Quick add from notification'),
                  subtitle: Text(
                    notificationsEnabled
                        ? 'Reply to the notification with an amount — it '
                              'posts straight away, uncategorised, with no '
                              'need to open the app.'
                        : 'Turn on Notifications above first.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: notificationQuickAddEnabled,
                  onChanged: notificationsEnabled
                      ? (v) => _toggleQuickAdd(ref, v)
                      : null,
                ),
                if (notificationQuickAddEnabled) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  _QuickAddAccountTile(trailingStyle: trailingStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotifications(WidgetRef ref, bool value) async {
    await ref.read(dbProvider).setNotificationsEnabled(value);
    if (value) {
      await ref.read(notificationServiceProvider).requestPermission();
    }
    // Quick add rides on this master switch — reflect an "off" immediately
    // rather than leaving the shortcut up until the next resume.
    await ref.read(notificationServiceProvider).syncQuickAddNotification();
  }

  Future<void> _toggleQuickAdd(WidgetRef ref, bool value) async {
    await ref.read(dbProvider).setNotificationQuickAddEnabled(value);
    await ref.read(notificationServiceProvider).syncQuickAddNotification();
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

/// Which account a quick-add reply posts to — "First account" (the default,
/// no explicit choice made) or a specific one, picked from the same list
/// [AppDatabase.resolveQuickAddAccountId] falls back to.
class _QuickAddAccountTile extends ConsumerWidget {
  const _QuickAddAccountTile({required this.trailingStyle});

  final TextStyle? trailingStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final accounts = ref.watch(balanceAccountsProvider).valueOrNull ?? const [];
    final chosenId = ref.watch(quickAddAccountIdProvider);
    final chosen = accounts.where((a) => a.id == chosenId).firstOrNull;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: const Text('Posts to'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chosen?.name ?? 'First account', style: trailingStyle),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: () => _pick(context, ref, accounts, chosenId),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<AccountRow> accounts,
    int? chosenId,
  ) async {
    // A record, not a bare `int?`: "First account" is a real pick whose
    // value is null, which a bare `int?` return can't tell apart from the
    // sheet being dismissed with no pick at all (also null) — that
    // ambiguity would silently reset an explicit choice back to "First
    // account" on every accidental dismiss.
    final result = await showModalBottomSheet<({int? accountId})>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Post to',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            RadioListTile<int?>(
              title: const Text('First account'),
              subtitle: const Text('Whichever tops your Accounts list'),
              value: null,
              // ignore: deprecated_member_use
              groupValue: chosenId,
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.of(sheetContext).pop((accountId: v)),
            ),
            for (final a in accounts)
              RadioListTile<int?>(
                title: Text(a.name),
                value: a.id,
                // ignore: deprecated_member_use
                groupValue: chosenId,
                // ignore: deprecated_member_use
                onChanged: (v) =>
                    Navigator.of(sheetContext).pop((accountId: v)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || result == null) return;
    if (result.accountId != chosenId) {
      await ref.read(dbProvider).setQuickAddAccount(result.accountId);
    }
  }
}
