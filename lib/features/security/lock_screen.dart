import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';
import '../../core/security/pin_pad.dart';
import '../../data/providers.dart';

const _pinLength = 4;

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
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      // Falls through to the PIN pad — biometric is a shortcut, never the
      // only way in.
    }
  }

  void _onDigit(String d) {
    if (_checking || _pin.length >= _pinLength) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == _pinLength) _submit();
  }

  void _onBackspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final ok = await ref.read(dbProvider).verifyPasscode(_pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _error = true;
      _checking = false;
      _pin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final biometricEnabled = ref.watch(biometricEnabledProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              const BrandMark(size: 48),
              const SizedBox(height: 12),
              Text(
                AppInfo.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _error ? 'Wrong PIN' : 'Enter your PIN',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _error
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              PinDots(entered: _pin.length, length: _pinLength, error: _error),
              const Spacer(flex: 3),
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
