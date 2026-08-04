import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/pin_pad.dart';
import '../../data/providers.dart';

const _pinLength = 4;

enum _Step { verifyCurrent, enterNew, confirmNew }

/// Set, change, or remove the passcode. [isRemoving] skips straight to
/// clearing it once the current PIN verifies — there's no "new PIN" step.
class SetPasscodeScreen extends ConsumerStatefulWidget {
  const SetPasscodeScreen({this.isRemoving = false, super.key});

  final bool isRemoving;

  @override
  ConsumerState<SetPasscodeScreen> createState() => _SetPasscodeScreenState();
}

class _SetPasscodeScreenState extends ConsumerState<SetPasscodeScreen> {
  late _Step _step;
  String _pin = '';
  String _newPinPending = '';
  bool _error = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final hasPasscode = ref.read(hasPasscodeProvider);
    _step = hasPasscode ? _Step.verifyCurrent : _Step.enterNew;
  }

  String get _title => switch (_step) {
    _Step.verifyCurrent => 'Enter current PIN',
    _Step.enterNew => 'Set a new PIN',
    _Step.confirmNew => 'Confirm PIN',
  };

  void _onDigit(String d) {
    if (_checking || _pin.length >= _pinLength) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == _pinLength) _submitStep();
  }

  void _onBackspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submitStep() async {
    switch (_step) {
      case _Step.verifyCurrent:
        setState(() => _checking = true);
        final ok = await ref.read(dbProvider).verifyPasscode(_pin);
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _error = true;
            _checking = false;
            _pin = '';
          });
          return;
        }
        if (widget.isRemoving) {
          await ref.read(dbProvider).clearPasscode();
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Passcode removed')));
          return;
        }
        setState(() {
          _step = _Step.enterNew;
          _checking = false;
          _pin = '';
        });

      case _Step.enterNew:
        setState(() {
          _newPinPending = _pin;
          _step = _Step.confirmNew;
          _pin = '';
        });

      case _Step.confirmNew:
        if (_pin != _newPinPending) {
          setState(() {
            _error = true;
            _pin = '';
            _step = _Step.enterNew;
            _newPinPending = '';
          });
          return;
        }
        setState(() => _checking = true);
        await ref.read(dbProvider).setPasscode(_pin);
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Passcode set')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Passcode')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(
              _title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (_error)
              Text(
                _step == _Step.enterNew
                    ? "PINs didn't match — try again"
                    : 'Wrong PIN',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: 18),
            PinDots(entered: _pin.length, length: _pinLength, error: _error),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
