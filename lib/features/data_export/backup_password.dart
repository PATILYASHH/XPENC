import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/routing/app_router.dart';
import '../../core/security/master_phrase_field.dart';
import '../../core/widgets/app_surfaces.dart';
import 'backup_crypto.dart';
import 'backup_service.dart';

/// [BackupService]'s password prompt for an encrypted backup it has no key
/// for (GitHub #41) — from Restore, Import from file, onboarding or
/// Connector alike, so it shows over whatever is on screen. The dialog stays
/// up while each password is tried, and says so when one is wrong. A
/// backup locked with the recovery phrase (GitHub #210) asks for its words.
Future<bool> askBackupPassword(
  BackupPasswordAttempt attempt,
  BackupSecret secret,
) async {
  final context = appRouter.routerDelegate.navigatorKey.currentContext;
  if (context == null) return false;
  final unlocked = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => secret == BackupSecret.recoveryPhrase
        ? _UnlockWithPhraseDialog(attempt: attempt)
        : _UnlockBackupDialog(attempt: attempt),
  );
  return unlocked == true;
}

/// The recovery-phrase version of [_UnlockBackupDialog] (GitHub #210).
class _UnlockWithPhraseDialog extends StatefulWidget {
  const _UnlockWithPhraseDialog({required this.attempt});

  final BackupPasswordAttempt attempt;

  @override
  State<_UnlockWithPhraseDialog> createState() =>
      _UnlockWithPhraseDialogState();
}

class _UnlockWithPhraseDialogState extends State<_UnlockWithPhraseDialog> {
  bool _busy = false;
  bool _wrong = false;

  Future<void> _submit(List<String> words) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _wrong = false;
    });
    bool ok;
    try {
      ok = await widget.attempt(BackupCrypto.phrasePassword(words));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _wrong = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Tr('Encrypted backup'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Tr(
              'This backup is locked with a 10-word recovery phrase. Enter '
              'the words in order.',
            ),
            const SizedBox(height: 16),
            MasterPhraseField(
              key: const Key('backup-unlock-phrase'),
              submitLabel: tr('Unlock'),
              busy: _busy,
              error: _wrong ? tr('Wrong phrase. Try again.') : null,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Tr('Cancel'),
        ),
      ],
    );
  }
}

class _UnlockBackupDialog extends StatefulWidget {
  const _UnlockBackupDialog({required this.attempt});

  final BackupPasswordAttempt attempt;

  @override
  State<_UnlockBackupDialog> createState() => _UnlockBackupDialogState();
}

class _UnlockBackupDialogState extends State<_UnlockBackupDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (_busy || password.isEmpty) return;
    setState(() {
      _busy = true;
      _wrong = false;
    });
    bool ok;
    try {
      ok = await widget.attempt(password);
    } catch (_) {
      // Whatever went wrong, the backup didn't open: let them try again.
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _wrong = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Tr('Encrypted backup'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Tr('Enter the password this backup was encrypted with.'),
          const SizedBox(height: 16),
          BackupPasswordField(
            key: const Key('backup-unlock-password'),
            controller: _controller,
            label: tr('Backup password'),
            autofocus: true,
            enabled: !_busy,
            errorText: _wrong ? tr('Wrong password. Try again.') : null,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Tr('Cancel'),
        ),
        FilledButton(
          key: const Key('backup-unlock'),
          onPressed: _busy || _controller.text.isEmpty ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Tr('Unlock'),
        ),
      ],
    );
  }
}

/// A password field with a show/hide eye.
class BackupPasswordField extends StatefulWidget {
  const BackupPasswordField({
    required this.controller,
    required this.label,
    super.key,
    this.autofocus = false,
    this.enabled = true,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final bool enabled;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<BackupPasswordField> createState() => _BackupPasswordFieldState();
}

class _BackupPasswordFieldState extends State<BackupPasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    autofocus: widget.autofocus,
    enabled: widget.enabled,
    obscureText: !_shown,
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.visiblePassword,
    textInputAction: widget.textInputAction,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.errorText,
      helperText: widget.helperText,
      helperMaxLines: 3,
      suffixIcon: IconButton(
        tooltip: _shown ? tr('Hide password') : tr('Show password'),
        icon: AppIcon(
          _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _shown = !_shown),
      ),
    ),
  );
}

/// Sets the backup password — turning encryption on, or changing it.
/// Pops true once [onSave] has saved it.
///
/// With a master recovery phrase set up ([onSavePhrase] given), it offers
/// that phrase as the backup key instead (GitHub #210).
class BackupPasswordSheet extends StatefulWidget {
  const BackupPasswordSheet({
    required this.changing,
    required this.onSave,
    super.key,
    this.onSavePhrase,
    this.startWithPhrase = false,
  });

  /// Encryption is already on: this picks a new password.
  final bool changing;
  final Future<void> Function(String password) onSave;

  /// Locks backups with the recovery phrase, given its words as typed.
  /// Throws [ArgumentError] for a wrong phrase. Null without a phrase set
  /// up, and then only a password is offered.
  final Future<void> Function(List<String> words)? onSavePhrase;

  /// Opens on the recovery phrase rather than a password.
  final bool startWithPhrase;

  @override
  State<BackupPasswordSheet> createState() => _BackupPasswordSheetState();
}

class _BackupPasswordSheetState extends State<BackupPasswordSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  late bool _usePhrase = widget.onSavePhrase != null && widget.startWithPhrase;

  Future<void> _savePhrase(List<String> words) async {
    final save = widget.onSavePhrase;
    if (_saving || save == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await save(words);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ArgumentError
            ? '${e.message}'
            : tr("Couldn't save: {0}", [e]);
      });
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _longEnough =>
      _password.text.length >= BackupCrypto.minPasswordLength;

  bool get _matches => _password.text == _confirm.text;

  bool get _valid => _longEnough && _matches;

  Future<void> _save() async {
    if (_saving || !_valid) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_password.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ArgumentError
            ? '${e.message}'
            : tr("Couldn't save: {0}", [e]);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.4,
    );
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom:
            MediaQuery.of(context).padding.bottom +
            MediaQuery.of(context).viewInsets.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              !widget.changing
                  ? tr('Encrypt backups')
                  : widget.onSavePhrase != null
                  ? tr('Change how backups are locked')
                  : tr('Change backup password'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.onSavePhrase != null) ...[
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                key: const Key('backup-lock-kind'),
                segments: const [
                  ButtonSegment(value: true, label: Tr('Recovery phrase')),
                  ButtonSegment(value: false, label: Tr('Password')),
                ],
                selected: {_usePhrase},
                showSelectedIcon: false,
                onSelectionChanged: _saving
                    ? null
                    : (s) => setState(() {
                        _usePhrase = s.first;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            Text(
              _usePhrase
                  ? widget.changing
                        ? tr(
                            'New backups are locked with your 10-word '
                            'recovery phrase. Backups made before keep what '
                            'they were locked with — XPENC on this phone '
                            'still opens them.',
                          )
                        : tr(
                            'Every backup from now on is locked (AES-256) '
                            'with the 10-word recovery phrase you already '
                            'use for the lock screen, so there is no second '
                            'password to keep. Anyone with the file sees '
                            'only scrambled data. Restoring one on another '
                            'phone asks for the 10 words.',
                          )
                  : widget.changing
                  ? tr(
                      'New backups use the new password. Backups made before '
                      'keep the old one — XPENC on this phone still opens '
                      'them, anywhere else they need the old password.',
                    )
                  : tr(
                      'Every backup from now on is locked with this '
                      'password (AES-256). Anyone with the file — a file '
                      'manager, a cloud copy, Connector on GitHub — sees '
                      'only scrambled data. Restoring one on another phone '
                      'asks for the password.',
                    ),
              style: muted,
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: cs.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _usePhrase
                            ? tr(
                                'Keep the phrase written down. Turning it '
                                'off for the lock screen later does not '
                                'unlock these backups — lose the words and '
                                'they can never be restored, not by you, '
                                'not by us.',
                              )
                            : tr(
                                'There is no way to reset this password. '
                                'Forget it and those backups can never be '
                                'restored — not by you, not by us.',
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_usePhrase) ...[
              Tr(
                'Type your recovery phrase to confirm it.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              MasterPhraseField(
                key: const Key('backup-phrase'),
                submitLabel: widget.changing
                    ? tr('Use recovery phrase')
                    : tr('Turn on encryption'),
                busy: _saving,
                error: _error,
                onSubmit: _savePhrase,
              ),
            ] else ...[
              BackupPasswordField(
                key: const Key('backup-password'),
                controller: _password,
                label: widget.changing ? tr('New password') : tr('Password'),
                autofocus: true,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                helperText: tr('At least {0} characters.', [
                  BackupCrypto.minPasswordLength,
                ]),
                errorText: _password.text.isNotEmpty && !_longEnough
                    ? tr('Use at least {0} characters.', [
                        BackupCrypto.minPasswordLength,
                      ])
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              BackupPasswordField(
                key: const Key('backup-password-confirm'),
                controller: _confirm,
                label: tr('Type it again'),
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                errorText: _confirm.text.isNotEmpty && !_matches
                    ? tr("The passwords don't match.")
                    : null,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('backup-password-save'),
                onPressed: _saving || !_valid ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.changing
                            ? tr('Change password')
                            : tr('Turn on encryption'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
