import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'currency_picker_sheet.dart';
import 'lock_screen_style_sheet.dart';
import 'master_phrase_attempts_sheet.dart';
import 'pin_timeout_sheet.dart';
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
    final myUpiId = ref.watch(myUpiIdProvider);
    final myUpiName = ref.watch(myUpiNameProvider);
    final myPaypal = ref.watch(myPaypalProvider);
    final myVenmo = ref.watch(myVenmoProvider);
    final myCashapp = ref.watch(myCashappProvider);
    final myRevolut = ref.watch(myRevolutProvider);
    final upiEnabled = ref.watch(upiEnabledProvider);
    final paypalEnabled = ref.watch(paypalEnabledProvider);
    final venmoEnabled = ref.watch(venmoEnabledProvider);
    final cashappEnabled = ref.watch(cashappEnabledProvider);
    final revolutEnabled = ref.watch(revolutEnabledProvider);
    final hasPasscode = ref.watch(hasPasscodeProvider);
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final pinTimeoutMinutes = ref.watch(pinTimeoutMinutesProvider);
    final lockScreenStyle = ref.watch(lockScreenStyleProvider);
    final hasMasterPhrase = ref.watch(hasMasterPhraseProvider);
    final masterPhraseAttemptThreshold = ref.watch(
      masterPhraseAttemptThresholdProvider,
    );
    final preventScreenshots = ref.watch(preventScreenshotsProvider);
    final screenshotReminderEnabled = ref.watch(
      screenshotReminderEnabledProvider,
    );
    final showCalendarDayTotals = ref.watch(showCalendarDayTotalsProvider);
    final expenseReminder = ref.watch(expenseReminderProvider);
    final notificationQuickAddEnabled = ref.watch(
      notificationQuickAddEnabledProvider,
    );

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
                Divider(height: 1, indent: 60, color: cs.outline),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.text_fields_rounded),
                  title: const Text('Font'),
                  subtitle: Text(
                    'Text size, boldness and font family',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () => context.push('/more/settings/font'),
                ),
              ],
            ),
          ),

          // ── Dashboard ──────────────────────────────────────────────────────
          _sectionLabel(context, 'Dashboard'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Customize dashboard'),
              subtitle: Text(
                'Choose which accounts count toward Net Worth.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/more/settings/dashboard'),
            ),
          ),

          // ── Calendar ───────────────────────────────────────────────────────
          _sectionLabel(context, 'Calendar'),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: const Icon(Icons.calendar_month_outlined),
              title: const Text('Show day totals'),
              subtitle: Text(
                'Selecting a day on the calendar shows its money in/out '
                'totals.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              value: showCalendarDayTotals,
              onChanged: (v) =>
                  ref.read(dbProvider).setShowCalendarDayTotals(v),
            ),
          ),

          // ── Persons ────────────────────────────────────────────────────────
          _sectionLabel(context, 'Persons'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
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
                if (upiEnabled) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    leading: const Icon(Icons.qr_code_outlined),
                    title: const Text('My UPI ID'),
                    subtitle: Text(
                      (myUpiId?.isNotEmpty ?? false)
                          ? myUpiId!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyUpiDialog(
                      context,
                      ref,
                      currentId: myUpiId,
                      currentName: myUpiName,
                    ),
                  ),
                ],
                if (paypalEnabled) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My PayPal.me ID'),
                    subtitle: Text(
                      (myPaypal?.isNotEmpty ?? false)
                          ? myPaypal!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My PayPal.me ID',
                      hintText: 'e.g. yourname',
                      currentId: myPaypal,
                      onSave: (id) => ref.read(dbProvider).setMyPaypal(id),
                    ),
                  ),
                ],
                if (venmoEnabled) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My Venmo username'),
                    subtitle: Text(
                      (myVenmo?.isNotEmpty ?? false)
                          ? myVenmo!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you (US)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My Venmo username',
                      hintText: 'e.g. rahul',
                      currentId: myVenmo,
                      onSave: (id) => ref.read(dbProvider).setMyVenmo(id),
                    ),
                  ),
                ],
                if (cashappEnabled) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My Cash App cashtag'),
                    subtitle: Text(
                      (myCashapp?.isNotEmpty ?? false)
                          ? myCashapp!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you (US)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My Cash App cashtag',
                      hintText: r'e.g. $rahul',
                      currentId: myCashapp,
                      onSave: (id) => ref.read(dbProvider).setMyCashapp(id),
                    ),
                  ),
                ],
                if (revolutEnabled) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    leading: const Icon(Icons.attach_money_rounded),
                    title: const Text('My Revolut.me username'),
                    subtitle: Text(
                      (myRevolut?.isNotEmpty ?? false)
                          ? myRevolut!
                          : 'Needed for the Beta "Request" button on a '
                                'person who owes you (Europe)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showMyIdDialog(
                      context,
                      ref,
                      title: 'My Revolut.me username',
                      hintText: 'e.g. rahul',
                      currentId: myRevolut,
                      onSave: (id) => ref.read(dbProvider).setMyRevolut(id),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Payment support ────────────────────────────────────────────────
          _sectionLabel(context, 'Payment Support'),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Turn off any method not used or supported where you '
                    'are — it disappears from person pages and Settings '
                    'instead of sitting there disabled.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('UPI'),
                  subtitle: const Text('India'),
                  value: upiEnabled,
                  onChanged: (v) => ref.read(dbProvider).setUpiEnabled(v),
                ),
                Divider(height: 1, indent: 16, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('PayPal'),
                  subtitle: const Text('Worldwide'),
                  value: paypalEnabled,
                  onChanged: (v) => ref.read(dbProvider).setPaypalEnabled(v),
                ),
                Divider(height: 1, indent: 16, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Venmo'),
                  subtitle: const Text('US'),
                  value: venmoEnabled,
                  onChanged: (v) => ref.read(dbProvider).setVenmoEnabled(v),
                ),
                Divider(height: 1, indent: 16, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Cash App'),
                  subtitle: const Text('US'),
                  value: cashappEnabled,
                  onChanged: (v) => ref.read(dbProvider).setCashappEnabled(v),
                ),
                Divider(height: 1, indent: 16, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: const Text('Revolut'),
                  subtitle: const Text('Europe'),
                  value: revolutEnabled,
                  onChanged: (v) => ref.read(dbProvider).setRevolutEnabled(v),
                ),
              ],
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
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Lock after'),
                    subtitle: Text(
                      'How long XPENC may sit in the background before it '
                      'asks for your PIN again',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          PinTimeoutSheet.label(pinTimeoutMinutes),
                          style: trailingStyle,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () => PinTimeoutSheet.show(context),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.dialpad_outlined),
                    title: const Text('Lock screen style'),
                    subtitle: Text(
                      'How the PIN pad looks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LockScreenStyleSheet.label(lockScreenStyle),
                          style: trailingStyle,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                    onTap: () => LockScreenStyleSheet.show(context),
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
                  Divider(height: 1, indent: 60, color: cs.outline),
                  if (hasMasterPhrase) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: const Icon(Icons.key_outlined),
                      title: const Text('Master recovery phrase'),
                      subtitle: Text(
                        'Set — required after too many wrong PIN attempts',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: cs.outline),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: const Icon(Icons.pin_outlined),
                      title: const Text('Require after'),
                      subtitle: Text(
                        'How many wrong PINs before the recovery phrase is '
                        'asked for instead',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            MasterPhraseAttemptsSheet.label(
                              masterPhraseAttemptThreshold,
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
                      onTap: () => MasterPhraseAttemptsSheet.show(context),
                    ),
                    Divider(height: 1, indent: 60, color: cs.outline),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: Icon(Icons.key_off_outlined, color: cs.error),
                      title: Text(
                        'Turn off recovery phrase',
                        style: TextStyle(color: cs.error),
                      ),
                      onTap: () =>
                          context.push('/more/settings/master-phrase/disable'),
                    ),
                  ] else
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: const Icon(Icons.key_outlined),
                      title: const Text('Set up master recovery phrase'),
                      subtitle: Text(
                        'A 10-word backup that unlocks XPENC if the PIN is '
                        'entered wrong too many times',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      onTap: () =>
                          context.push('/more/settings/master-phrase/setup'),
                    ),
                ],
                Divider(height: 1, indent: 60, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.screenshot_outlined),
                  title: const Text('Block screenshots'),
                  subtitle: Text(
                    'Hides XPENC from screenshots, screen recording and the '
                    'recent-apps thumbnail',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: preventScreenshots,
                  onChanged: (v) =>
                      ref.read(dbProvider).setPreventScreenshots(v),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.visibility_outlined),
                  title: const Text('Remind when screenshots are allowed'),
                  subtitle: Text(
                    'A small tag in the corner whenever "Block screenshots" '
                    "is off — easy to forget it's still off. Off by default, "
                    "so leaving it off on purpose isn't disturbed.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: screenshotReminderEnabled,
                  onChanged: (v) =>
                      ref.read(dbProvider).setScreenshotReminderEnabled(v),
                ),
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

          // ── Message capture ────────────────────────────────────────────────
          _sectionLabel(context, 'Message Capture'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('Bank-SMS auto-capture'),
                  subtitle: Text(
                    'Coming soon — removed for now so the app installs '
                    'without a Play Protect block.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/more/capture'),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.rate_review_outlined),
                  title: const Text('OCR corrections'),
                  subtitle: Text(
                    'Optional — test a payment screenshot and help improve '
                    'OCR by sharing what you find, entirely on your terms.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/more/capture/ocr-feedback'),
                ),
              ],
            ),
          ),

          // ── Data ───────────────────────────────────────────────────────────
          _sectionLabel(context, 'Widgets'),
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
                  title: Text(
                    'Clear all data',
                    style: TextStyle(color: cs.error),
                  ),
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

  Future<void> _showMyUpiDialog(
    BuildContext context,
    WidgetRef ref, {
    required String? currentId,
    required String? currentName,
  }) async {
    final result = await showDialog<({String id, String name})>(
      context: context,
      builder: (_) =>
          _MyUpiDialog(currentId: currentId, currentName: currentName),
    );
    if (result == null) return;

    final db = ref.read(dbProvider);
    await db.setMyUpiId(result.id.trim().isEmpty ? null : result.id.trim());
    await db.setMyUpiName(
      result.name.trim().isEmpty ? null : result.name.trim(),
    );
  }

  /// Shared single-field "my own payment id" dialog, used by every method
  /// after UPI (which also needs a display name, so keeps its own dialog).
  Future<void> _showMyIdDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String hintText,
    required String? currentId,
    required Future<void> Function(String? id) onSave,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _MyIdDialog(title: title, hintText: hintText, currentId: currentId),
    );
    if (result == null) return;

    final id = result.trim();
    await onSave(id.isEmpty ? null : id);
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

/// A `StatefulWidget`, not bare controllers disposed right after
/// `showDialog` resolves — that races the dialog's own closing animation:
/// the route pops (resolving the `Future`) before the still-visible
/// `TextField`s finish their exit transition, so controllers disposed
/// immediately can be torn down while still attached to them. Owning them
/// in `State.dispose()` ties their lifetime to the framework's own unmount
/// timing instead, which is always correct.
class _MyUpiDialog extends StatefulWidget {
  const _MyUpiDialog({required this.currentId, required this.currentName});

  final String? currentId;
  final String? currentName;

  @override
  State<_MyUpiDialog> createState() => _MyUpiDialogState();
}

class _MyUpiDialogState extends State<_MyUpiDialog> {
  late final _idController = TextEditingController(
    text: widget.currentId ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.currentName ?? '',
  );

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('My UPI ID'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _idController,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'e.g. you@okhdfcbank',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              hintText: 'Shown to whoever pays your request',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((id: _idController.text, name: _nameController.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Same disposal-timing fix as [_MyUpiDialog], for the shared single-field
/// "my own payment id" dialog every method after UPI uses.
class _MyIdDialog extends StatefulWidget {
  const _MyIdDialog({
    required this.title,
    required this.hintText,
    required this.currentId,
  });

  final String title;
  final String hintText;
  final String? currentId;

  @override
  State<_MyIdDialog> createState() => _MyIdDialogState();
}

class _MyIdDialogState extends State<_MyIdDialog> {
  late final _controller = TextEditingController(
    text: widget.currentId ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: widget.title,
          hintText: widget.hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
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
