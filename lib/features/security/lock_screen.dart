import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/security/master_phrase_field.dart';
import '../../core/security/paste_code_key.dart';
import '../../core/security/pin_pad.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show UnlockMethod;
import 'lock_screen_keypad.dart';

/// A TOTP code is always 6 digits (GitHub #104) — `Totp.provisioningUri`
/// hard-codes `digits=6`, so entry here matches.
const _totpCodeLength = 6;

/// Rendered directly by [XpencApp]'s `builder`, outside the router — a
/// blocking overlay, not a route, so there is no back button and no way
/// around it except a correct credential from one of the ready methods.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({required this.onUnlocked, super.key});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _error = false;
  bool _checking = false;
  bool _biometricTried = false;
  String? _phraseError;
  bool _phraseChecking = false;

  /// Bumped on every wrong PIN so a `scrambled` [LockScreenKeypad]
  /// reshuffles for the next attempt — see its `attempt` doc.
  int _attempt = 0;

  // ── TOTP entry (GitHub #104) ─────────────────────────────────────────────
  String _totp = '';
  bool _totpError = false;
  bool _totpChecking = false;

  /// Same purpose as [_attempt], for the TOTP keypad.
  int _totpAttempt = 0;

  /// Which method this lock session is currently asking for. Independent
  /// on/off toggles per method mean OR semantics (any ready method
  /// unlocks) — "try another method" below switches this to whichever
  /// other ready method the user picks; a successful unlock with it then
  /// persists the choice via `AppDatabase.setPreferredUnlockMethod` so the
  /// next lock remembers it. Seeded once, from whichever method was
  /// remembered last time, and never re-seeded mid-session (only "try
  /// another method" changes it after that).
  UnlockMethod? _shownMethod;

  @override
  void initState() {
    super.initState();
    _shownMethod = ref.read(unlockMethodProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTryBiometric());
  }

  Future<void> _maybeTryBiometric() async {
    if (_biometricTried) return;
    _biometricTried = true;
    // Biometric is a shortcut for *PIN* entry only (GitHub #104) — trying it
    // (or offering the fingerprint key at all) while a different method is
    // showing would let a fingerprint silently bypass whichever front door
    // is actually up right now.
    if (!ref.read(biometricEnabledProvider) ||
        _shownMethod != UnlockMethod.pin) {
      return;
    }
    await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return;
      final ok = await auth.authenticate(
        localizedReason: 'Unlock ${AppInfo.name}',
        biometricOnly: true,
      );
      if (ok && mounted) {
        await ref.read(dbProvider).resetFailedPasscodeAttempts();
        if (mounted) widget.onUnlocked();
      }
    } catch (_) {
      // Falls through to the PIN pad — biometric is a shortcut, never the
      // only way in.
    }
  }

  /// Clears every method's transient entry state — called whenever "try
  /// another method" switches [_shownMethod], so leftover digits/errors
  /// from the previous method never bleed into the new one.
  void _resetEntryState() {
    _pin = '';
    _error = false;
    _checking = false;
    _totp = '';
    _totpError = false;
    _totpChecking = false;
    _phraseError = null;
    _phraseChecking = false;
  }

  void _onDigit(String d) {
    final pinLength = ref.read(passcodeLengthProvider);
    if (_checking || _pin.length >= pinLength) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == pinLength) _submit();
  }

  void _onBackspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final db = ref.read(dbProvider);
    final ok = await db.verifyPasscode(_pin);
    if (!mounted) return;
    if (ok) {
      await db.resetFailedPasscodeAttempts();
      await db.setPreferredUnlockMethod(UnlockMethod.pin);
      if (!mounted) return;
      widget.onUnlocked();
      return;
    }
    await db.recordFailedPasscodeAttempt();
    if (!mounted) return;
    setState(() {
      _error = true;
      _checking = false;
      _pin = '';
      _attempt++;
    });
  }

  Future<void> _submitPhrase(List<String> words) async {
    setState(() {
      _phraseChecking = true;
      _phraseError = null;
    });
    final db = ref.read(dbProvider);
    final ok = await db.verifyMasterPhrase(words);
    if (!mounted) return;
    if (ok) {
      await db.resetFailedPasscodeAttempts();
      await db.setPreferredUnlockMethod(UnlockMethod.masterPhrase);
      if (!mounted) return;
      widget.onUnlocked();
      return;
    }
    setState(() {
      _phraseChecking = false;
      _phraseError = 'Wrong phrase';
    });
  }

  void _onTotpDigit(String d) {
    if (_totpChecking || _totp.length >= _totpCodeLength) return;
    setState(() {
      _totpError = false;
      _totp += d;
    });
    if (_totp.length == _totpCodeLength) _submitTotp();
  }

  void _onTotpBackspace() {
    if (_totpChecking || _totp.isEmpty) return;
    setState(() => _totp = _totp.substring(0, _totp.length - 1));
  }

  Future<void> _submitTotp() async {
    setState(() => _totpChecking = true);
    final db = ref.read(dbProvider);
    final ok = await db.verifyTotp(_totp);
    if (!mounted) return;
    if (ok) {
      await db.resetFailedPasscodeAttempts();
      await db.setPreferredUnlockMethod(UnlockMethod.totp);
      if (!mounted) return;
      widget.onUnlocked();
      return;
    }
    // Same counter a wrong PIN increments — the "too many wrong attempts"
    // fallback to the master phrase is generalized across whichever method
    // is showing (GitHub #104), not PIN-specific.
    await db.recordFailedPasscodeAttempt();
    if (!mounted) return;
    setState(() {
      _totpError = true;
      _totpChecking = false;
      _totp = '';
      _totpAttempt++;
    });
  }

  /// The TOTP keypad's paste key (GitHub #111) — fills [_totp] from the
  /// clipboard's digits and submits.
  void _onPasteTotp(String digits) {
    if (_totpChecking) return;
    setState(() {
      _totpError = false;
      _totp = digits.length > _totpCodeLength
          ? digits.substring(0, _totpCodeLength)
          : digits;
    });
    if (_totp.length == _totpCodeLength) _submitTotp();
  }

  /// Opens a bottom sheet listing every other ready method (GitHub #104 →
  /// independent on/off toggles) — tapping one switches [_shownMethod] and
  /// clears whatever was half-entered for the method being left.
  Future<void> _showMethodPicker(
    BuildContext context,
    List<UnlockMethod> otherMethods,
  ) async {
    final chosen = await showModalBottomSheet<UnlockMethod>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Try another method',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final method in otherMethods)
              ListTile(
                leading: Icon(_methodIcon(method)),
                title: Text(_methodLabel(method)),
                onTap: () => Navigator.of(sheetContext).pop(method),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _shownMethod = chosen;
      _resetEntryState();
    });
  }

  static IconData _methodIcon(UnlockMethod method) => switch (method) {
    UnlockMethod.pin => Icons.pin_outlined,
    UnlockMethod.masterPhrase => Icons.key_outlined,
    UnlockMethod.totp => Icons.qr_code_2_rounded,
  };

  static String _methodLabel(UnlockMethod method) => switch (method) {
    UnlockMethod.pin => 'PIN',
    UnlockMethod.masterPhrase => 'Master password',
    UnlockMethod.totp => 'Authenticator app',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMasterPhrase = ref.watch(hasMasterPhraseProvider);
    final failedAttempts = ref.watch(failedPasscodeAttemptsProvider);
    final threshold = ref.watch(masterPhraseAttemptThresholdProvider);
    final readyMethods = ref.watch(readyUnlockMethodsProvider);
    // A stale preference (its method was turned off, or never set) falls
    // back to whatever else is ready — never shown blank while the app is
    // actually locked.
    final shownMethod = readyMethods.contains(_shownMethod)
        ? _shownMethod
        : readyMethods.isEmpty
        ? null
        : readyMethods.first;
    // The phrase is itself the fallback mechanism, so it never falls back to
    // itself (GitHub #104) — only reachable here while a *different* method
    // is showing.
    final canFallBackToPhrase =
        hasMasterPhrase && shownMethod != UnlockMethod.masterPhrase;
    // No time decay (GitHub #74): once the persisted counter reaches the
    // threshold, every future launch/resume lands here directly — the
    // showing method's own entry below is unreachable again until the
    // phrase is entered correctly.
    final phraseLocked = canFallBackToPhrase && failedAttempts >= threshold;
    final otherReadyMethods = phraseLocked
        ? const <UnlockMethod>[]
        : readyMethods.where((m) => m != shownMethod).toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        // Fixed spacing, not flex `Spacer`s — `IntrinsicHeight` (an earlier
        // attempt at this, GitHub #78) inflates flex children based on their
        // flex factor rather than their actual content, which ballooned the
        // computed height and pushed most of the keypad off-screen. `Center`
        // inside a `minHeight: viewport` box gives the same "vertically
        // centered when it fits" look with a real, predictable content
        // height, and still falls back to scrolling — never clipping —
        // if it doesn't fit at all (tiny screens, large font scale).
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(size: 48),
                        const SizedBox(height: 12),
                        Text(
                          AppInfo.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 40),
                        phraseLocked
                            ? _buildPhraseBody(context, isFallback: true)
                            : switch (shownMethod) {
                                UnlockMethod.pin => _buildPinBody(context),
                                UnlockMethod.masterPhrase => _buildPhraseBody(
                                  context,
                                  isFallback: false,
                                ),
                                UnlockMethod.totp => _buildTotpBody(context),
                                null => const SizedBox.shrink(),
                              },
                        if (otherReadyMethods.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () =>
                                _showMethodPicker(context, otherReadyMethods),
                            child: const Text('Try another method'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinBody(BuildContext context) {
    final theme = Theme.of(context);
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final pinLength = ref.watch(passcodeLengthProvider);
    final lockScreenStyle = ref.watch(lockScreenStyleProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _error ? 'Wrong PIN' : 'Enter your PIN',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _error
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        PinDots(entered: _pin.length, length: pinLength, error: _error),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LockScreenKeypad(
            style: lockScreenStyle,
            attempt: _attempt,
            onDigit: _onDigit,
            onBackspace: _onBackspace,
            extraKey: biometricEnabled
                ? IconButton(
                    icon: const Icon(Icons.fingerprint_rounded, size: 28),
                    tooltip: 'Use biometric unlock',
                    onPressed: _tryBiometric,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  /// [isFallback] is true when this is reached via too many wrong attempts
  /// at a *different* showing method (GitHub #104) rather than the phrase
  /// being the method itself showing — only then does the "too many wrong…"
  /// framing make sense.
  Widget _buildPhraseBody(BuildContext context, {required bool isFallback}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shownMethod =
        ref.read(readyUnlockMethodsProvider).contains(_shownMethod)
        ? _shownMethod
        : null;
    final fallbackHeading = switch (shownMethod) {
      UnlockMethod.pin => 'Too many wrong PINs',
      UnlockMethod.totp => 'Too many wrong codes',
      UnlockMethod.masterPhrase ||
      null => 'Too many wrong attempts', // masterPhrase case unreachable
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_outlined, size: 32, color: cs.primary),
          const SizedBox(height: 12),
          if (isFallback) ...[
            Text(
              fallbackHeading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Text(
            'Enter your master recovery phrase to unlock XPENC.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          MasterPhraseField(
            error: _phraseError,
            busy: _phraseChecking,
            onSubmit: _submitPhrase,
          ),
        ],
      ),
    );
  }

  Widget _buildTotpBody(BuildContext context) {
    final theme = Theme.of(context);
    final lockScreenStyle = ref.watch(lockScreenStyleProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _totpError ? 'Wrong code' : 'Enter your authenticator code',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _totpError
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        PinDots(
          entered: _totp.length,
          length: _totpCodeLength,
          error: _totpError,
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LockScreenKeypad(
            style: lockScreenStyle,
            attempt: _totpAttempt,
            onDigit: _onTotpDigit,
            onBackspace: _onTotpBackspace,
            extraKey: PasteCodeKey(onCode: _onPasteTotp),
          ),
        ),
      ],
    );
  }
}
