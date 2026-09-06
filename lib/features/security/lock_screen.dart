import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/security/master_phrase_field.dart';
import '../../core/security/pin_pad.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show UnlockMethod;
import 'lock_screen_keypad.dart';

/// A TOTP code is always 6 digits (GitHub #104) — `Totp.provisioningUri`
/// hard-codes `digits=6`, so entry here matches.
const _totpCodeLength = 6;

/// Rendered directly by [XpencApp]'s `builder`, outside the router — a
/// blocking overlay, not a route, so there is no back button and no way
/// around it except a correct PIN or biometric.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTryBiometric());
  }

  Future<void> _maybeTryBiometric() async {
    if (_biometricTried) return;
    _biometricTried = true;
    // Biometric is a shortcut for *PIN* entry only (GitHub #104) — trying it
    // (or offering the fingerprint key at all) while a different method is
    // active would let a fingerprint silently bypass whichever front door
    // was actually chosen.
    if (!ref.read(biometricEnabledProvider) ||
        ref.read(unlockMethodProvider) != UnlockMethod.pin) {
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
      if (!mounted) return;
      widget.onUnlocked();
      return;
    }
    // Same counter a wrong PIN increments — the "too many wrong attempts"
    // fallback to the master phrase is generalized across whichever method
    // is active (GitHub #104), not PIN-specific.
    await db.recordFailedPasscodeAttempt();
    if (!mounted) return;
    setState(() {
      _totpError = true;
      _totpChecking = false;
      _totp = '';
      _totpAttempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlockMethod = ref.watch(unlockMethodProvider);
    final hasMasterPhrase = ref.watch(hasMasterPhraseProvider);
    final failedAttempts = ref.watch(failedPasscodeAttemptsProvider);
    final threshold = ref.watch(masterPhraseAttemptThresholdProvider);
    // The phrase is itself the fallback mechanism, so it never falls back to
    // itself (GitHub #104) — only reachable here when a *different* method
    // is active.
    final canFallBackToPhrase =
        hasMasterPhrase && unlockMethod != UnlockMethod.masterPhrase;
    // No time decay (GitHub #74): once the persisted counter reaches the
    // threshold, every future launch/resume lands here directly — the active
    // method's own entry below is unreachable again until the phrase is
    // entered correctly.
    final phraseLocked = canFallBackToPhrase && failedAttempts >= threshold;

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
                            : switch (unlockMethod) {
                                UnlockMethod.pin => _buildPinBody(context),
                                UnlockMethod.masterPhrase => _buildPhraseBody(
                                  context,
                                  isFallback: false,
                                ),
                                UnlockMethod.totp => _buildTotpBody(context),
                              },
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
  /// at a *different* active method (GitHub #104) rather than the phrase
  /// being the active method itself — only then does the "too many wrong…"
  /// framing make sense.
  Widget _buildPhraseBody(BuildContext context, {required bool isFallback}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final unlockMethod = ref.read(unlockMethodProvider);
    final fallbackHeading = switch (unlockMethod) {
      UnlockMethod.pin => 'Too many wrong PINs',
      UnlockMethod.totp => 'Too many wrong codes',
      UnlockMethod.masterPhrase =>
        '', // unreachable — the phrase can't fall back to itself
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
          ),
        ),
      ],
    );
  }
}
