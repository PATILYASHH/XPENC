import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/tables.dart' show UnlockMethod;
import 'lock_screen_style_sheet.dart';
import 'master_phrase_attempts_sheet.dart';
import 'pin_timeout_sheet.dart';
import 'settings_common.dart';

/// Security & Privacy — the app's unlock methods (PIN, master recovery
/// phrase, authenticator app) plus screenshot handling. Two sections:
/// "Security" (getting into the app) and "Privacy" (what's visible once
/// you're in it).
class SecurityPrivacySettingsScreen extends ConsumerWidget {
  const SecurityPrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final trailingStyle = settingsTrailingStyle(context);

    final hasPasscode = ref.watch(hasPasscodeProvider);
    final pinUnlockEnabled = ref.watch(pinUnlockEnabledProvider);
    final masterPhraseUnlockEnabled = ref.watch(
      masterPhraseUnlockEnabledProvider,
    );
    final totpUnlockEnabled = ref.watch(totpUnlockEnabledProvider);
    final hasTotp = ref.watch(hasTotpProvider);
    final hasUnlockCredential = ref.watch(hasUnlockCredentialProvider);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Security & Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          settingsSectionLabel(context, 'Security'),
          Card(
            child: Column(
              children: [
                // ── Unlock methods — independent on/off toggles. Turn on
                // more than one and any of them unlocks the app (OR, not
                // AND) — "try another method" on the lock screen switches
                // between whichever are ready. Each method's own credential
                // still manages independently below, toggled on or not.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Turn on more than one and any of them unlocks the app — '
                    'switch between them from "Try another method" on the '
                    'lock screen.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.pin_outlined),
                  title: const Text('PIN'),
                  subtitle: Text(
                    !hasPasscode
                        ? 'Tap to set up a PIN'
                        : pinUnlockEnabled
                        ? 'A PIN can unlock the app'
                        : 'Set up, but turned off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: hasPasscode && pinUnlockEnabled,
                  onChanged: (v) => _toggleUnlockMethod(
                    context,
                    ref,
                    UnlockMethod.pin,
                    v,
                    configured: hasPasscode,
                  ),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.key_outlined),
                  title: const Text('Master password'),
                  subtitle: Text(
                    !hasMasterPhrase
                        ? 'Tap to set up a recovery phrase'
                        : masterPhraseUnlockEnabled
                        ? 'Your recovery phrase can unlock the app'
                        : 'Set up, but turned off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: hasMasterPhrase && masterPhraseUnlockEnabled,
                  onChanged: (v) => _toggleUnlockMethod(
                    context,
                    ref,
                    UnlockMethod.masterPhrase,
                    v,
                    configured: hasMasterPhrase,
                  ),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: const Icon(Icons.qr_code_2_rounded),
                  title: const Text('Authenticator app'),
                  subtitle: Text(
                    !hasTotp
                        ? 'Tap to set up an authenticator app'
                        : totpUnlockEnabled
                        ? 'A 6-digit code can unlock the app'
                        : 'Set up, but turned off',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  value: hasTotp && totpUnlockEnabled,
                  onChanged: (v) => _toggleUnlockMethod(
                    context,
                    ref,
                    UnlockMethod.totp,
                    v,
                    configured: hasTotp,
                  ),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),

                // ── PIN management — visible whether or not PIN is active ──
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
                      'PIN always still works. Only applies while PIN unlock '
                      'is turned on.',
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
                Divider(height: 1, indent: 60, color: cs.outline),

                // ── Master recovery phrase management — visible whether or
                // not it's active ──────────────────────────────────────────
                if (hasMasterPhrase) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Master recovery phrase'),
                    subtitle: Text(
                      'Set — also used as a fallback after too many wrong '
                      'attempts at whichever method is active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('Require after'),
                    subtitle: Text(
                      'How many wrong attempts before the recovery phrase is '
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Set up master recovery phrase'),
                    subtitle: Text(
                      'A 10-word backup that can unlock XPENC if the active '
                      'method is entered wrong too many times',
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
                Divider(height: 1, indent: 60, color: cs.outline),

                // ── Authenticator app (TOTP) management — visible whether
                // or not it's active ──────────────────────────────────────
                if (hasTotp) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.qr_code_2_rounded),
                    title: const Text('Authenticator app'),
                    subtitle: Text(
                      'Set up',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(Icons.qr_code_2_rounded, color: cs.error),
                    title: Text(
                      'Turn off authenticator app',
                      style: TextStyle(color: cs.error),
                    ),
                    onTap: () => context.push('/more/settings/totp/disable'),
                  ),
                ] else
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.qr_code_2_rounded),
                    title: const Text('Set up authenticator app'),
                    subtitle: Text(
                      'Use Google Authenticator, Authy or similar to unlock '
                      'XPENC with a 6-digit code',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                    onTap: () => context.push('/more/settings/totp/setup'),
                  ),

                // ── Shared lock behavior — applies regardless of which
                // method is active, so it's keyed on any credential existing
                // at all, not on PIN specifically ────────────────────────
                if (hasUnlockCredential) ...[
                  Divider(height: 1, indent: 60, color: cs.outline),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Lock after'),
                    subtitle: Text(
                      'How long XPENC may sit in the background before it '
                      'locks again',
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
                      'How the PIN/code pad looks',
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
                ],
              ],
            ),
          ),

          settingsSectionLabel(context, 'Privacy'),
          Card(
            child: Column(
              children: [
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
        ],
      ),
    );
  }

  /// Handles a tap on one of the "Unlock methods" switches — independent
  /// on/off toggles, OR semantics: any turned-on-and-configured method
  /// unlocks the app. Turning on a method with no credential yet routes to
  /// its setup flow instead; that flow's own save both stores the
  /// credential and turns the toggle on (see [AppDatabase.setupTotp]/
  /// [AppDatabase.setMasterPhrase]/[AppDatabase.setPasscode]), so there's
  /// nothing left to do here in that case. Turning off the last remaining
  /// ready method is refused by [AppDatabase.setUnlockMethodEnabled] — the
  /// toggles alone must never leave the app with no way back in.
  Future<void> _toggleUnlockMethod(
    BuildContext context,
    WidgetRef ref,
    UnlockMethod method,
    bool turnOn, {
    required bool configured,
  }) async {
    if (turnOn && !configured) {
      context.push(switch (method) {
        UnlockMethod.pin => '/more/settings/passcode',
        UnlockMethod.masterPhrase => '/more/settings/master-phrase/setup',
        UnlockMethod.totp => '/more/settings/totp/setup',
      });
      return;
    }
    final ok = await ref
        .read(dbProvider)
        .setUnlockMethodEnabled(method, turnOn);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('At least one unlock method must stay on'),
          ),
        );
    }
  }
}
