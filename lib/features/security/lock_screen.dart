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

/// Which half of [UnlockMethod.pinAndTotp] (GitHub #111) is currently being
/// asked for — the PIN always comes first, the authenticator code second;
/// both must be correct before [LockScreen.onUnlocked] fires.
enum _PinTotpStep { pin, totp }

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

  /// Only meaningful while [UnlockMethod.pinAndTotp] is active (GitHub #111)
  /// — which of the two steps is currently showing. Resets to [_PinTotpStep.
  /// pin] each time a fresh [LockScreen] is mounted (i.e. every time the app
  /// re-locks), never mid-session.
  _PinTotpStep _pinTotpStep = _PinTotpStep.pin;

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

  // ── PIN + Authenticator, combined (GitHub #111) ─────────────────────────
  // A correct PIN here only advances to the TOTP step — it never unlocks by
  // itself, unlike plain [UnlockMethod.pin]. Only a correct code afterward
  // actually calls `onUnlocked`. Both steps share the shared wrong-attempt
  // counter with every other method, so the phrase fallback still kicks in
  // the same way after enough combined failures.

  void _onCombinedPinDigit(String d) {
    final pinLength = ref.read(passcodeLengthProvider);
    if (_checking || _pin.length >= pinLength) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == pinLength) _submitCombinedPin();
  }

  Future<void> _submitCombinedPin() async {
    setState(() => _checking = true);
    final db = ref.read(dbProvider);
    final ok = await db.verifyPasscode(_pin);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _checking = false;
        _pin = '';
        _pinTotpStep = _PinTotpStep.totp;
      });
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

  void _onCombinedTotpDigit(String d) {
    if (_totpChecking || _totp.length >= _totpCodeLength) return;
    setState(() {
      _totpError = false;
      _totp += d;
    });
    if (_totp.length == _totpCodeLength) _submitCombinedTotp();
  }

  Future<void> _submitCombinedTotp() async {
    setState(() => _totpChecking = true);
    final db = ref.read(dbProvider);
    final ok = await db.verifyTotp(_totp);
    if (!mounted) return;
    if (ok) {
      // The counter only resets once *both* factors are satisfied — a
      // correct PIN alone (see `_submitCombinedPin`) never touches it.
      await db.resetFailedPasscodeAttempts();
      if (!mounted) return;
      widget.onUnlocked();
      return;
    }
    await db.recordFailedPasscodeAttempt();
    if (!mounted) return;
    setState(() {
      _totpError = true;
      _totpChecking = false;
      _totp = '';
      _totpAttempt++;
    });
  }

  /// The TOTP keypad's paste key (GitHub #111), shared by [_buildTotpBody]'s
  /// single-method and combined-flow cases — fills [_totp] from the
  /// clipboard's digits and submits through whichever of [_submitTotp] /
  /// [_submitCombinedTotp] actually applies right now.
  void _onPasteTotp(String digits, {required bool combined}) {
    if (_totpChecking) return;
    setState(() {
      _totpError = false;
      _totp = digits.length > _totpCodeLength
          ? digits.substring(0, _totpCodeLength)
          : digits;
    });
    if (_totp.length != _totpCodeLength) return;
    if (combined) {
      _submitCombinedTotp();
    } else {
      _submitTotp();
    }
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
                                UnlockMethod.pinAndTotp =>
                                  _pinTotpStep == _PinTotpStep.pin
                                      ? _buildPinBody(context, combined: true)
                                      : _buildTotpBody(
                                          context,
                                          combined: true,
                                        ),
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

  /// [combined] is true for the PIN half of [UnlockMethod.pinAndTotp]
  /// (GitHub #111) — a correct PIN there only advances to the code step
  /// (see [_onCombinedPinDigit]), so the biometric shortcut is withheld:
  /// fingerprint unlock is documented as a PIN-only shortcut, and letting it
  /// also skip the authenticator half would silently turn "both factors" into
  /// "just a fingerprint".
  Widget _buildPinBody(BuildContext context, {bool combined = false}) {
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
        if (combined) ...[
          const SizedBox(height: 4),
          Text(
            'Step 1 of 2 — an authenticator code is needed next',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        PinDots(entered: _pin.length, length: pinLength, error: _error),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: LockScreenKeypad(
            style: lockScreenStyle,
            attempt: _attempt,
            onDigit: combined ? _onCombinedPinDigit : _onDigit,
            onBackspace: _onBackspace,
            extraKey: !combined && biometricEnabled
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
      UnlockMethod.pinAndTotp => 'Too many wrong attempts',
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

  /// [combined] is true for the code half of [UnlockMethod.pinAndTotp]
  /// (GitHub #111), reached only after [_buildPinBody]'s combined PIN step
  /// already verified — routes digit entry and the paste key to
  /// [_submitCombinedTotp] instead of [_submitTotp] so a correct code here
  /// actually unlocks, rather than the single-method TOTP flow's own submit.
  Widget _buildTotpBody(BuildContext context, {bool combined = false}) {
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
        if (combined) ...[
          const SizedBox(height: 4),
          Text(
            'Step 2 of 2',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
            onDigit: combined ? _onCombinedTotpDigit : _onTotpDigit,
            onBackspace: _onTotpBackspace,
            extraKey: PasteCodeKey(
              onCode: (d) => _onPasteTotp(d, combined: combined),
            ),
          ),
        ),
      ],
    );
  }
}
