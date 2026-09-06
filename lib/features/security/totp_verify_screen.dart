import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/pin_pad.dart';
import '../../data/providers.dart';
import 'lock_screen_keypad.dart';

const _codeLength = 6;

/// Turning off the authenticator app requires entering a current code first
/// — same reasoning [MasterPhraseVerifyScreen] documents for turning off the
/// phrase: proves whoever is disabling it actually holds it. GitHub #104.
class TotpVerifyScreen extends ConsumerStatefulWidget {
  const TotpVerifyScreen({super.key});

  @override
  ConsumerState<TotpVerifyScreen> createState() => _TotpVerifyScreenState();
}

class _TotpVerifyScreenState extends ConsumerState<TotpVerifyScreen> {
  String _code = '';
  bool _error = false;
  bool _checking = false;
  int _attempt = 0;

  void _onDigit(String d) {
    if (_checking || _code.length >= _codeLength) return;
    setState(() {
      _error = false;
      _code += d;
    });
    if (_code.length == _codeLength) _submit();
  }

  void _onBackspace() {
    if (_checking || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final ok = await ref.read(dbProvider).verifyTotp(_code);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _checking = false;
        _error = true;
        _code = '';
        _attempt++;
      });
      return;
    }
    await ref.read(dbProvider).clearTotp();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Authenticator app turned off')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Turn off authenticator app')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Enter a current code from your authenticator app to turn '
                'this off.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            if (_error)
              Text(
                'Wrong code',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: 6),
            PinDots(entered: _code.length, length: _codeLength, error: _error),
            const Spacer(flex: 3),
            if (_checking)
              const CircularProgressIndicator()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LockScreenKeypad(
                  style: ref.watch(lockScreenStyleProvider),
                  attempt: _attempt,
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
