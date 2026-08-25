import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/security/master_phrase_field.dart';
import '../../core/security/pin_pad.dart';
import '../../data/providers.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTryBiometric());
  }

  Future<void> _maybeTryBiometric() async {
    if (_biometricTried) return;
    _biometricTried = true;
    if (!ref.read(biometricEnabledProvider)) return;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMasterPhrase = ref.watch(hasMasterPhraseProvider);
    final failedAttempts = ref.watch(failedPasscodeAttemptsProvider);
    final threshold = ref.watch(masterPhraseAttemptThresholdProvider);
    // No time decay (GitHub #74): once the persisted counter reaches the
    // threshold, every future launch/resume lands here directly — the PIN
    // pad below is unreachable again until the phrase is entered correctly.
    final phraseLocked = hasMasterPhrase && failedAttempts >= threshold;

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
                            ? _buildPhraseBody(context)
                            : _buildPinBody(context),
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
          child: PinKeypad(
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

  Widget _buildPhraseBody(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_outlined, size: 32, color: cs.primary),
          const SizedBox(height: 12),
          Text(
            'Too many wrong PINs',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
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
}
