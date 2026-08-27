import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/pin_pad.dart';
import '../../data/providers.dart';
import 'lock_screen_keypad.dart';

const _pinLengthOptions = [4, 5, 6];

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

  /// Bumped every time [_pin] resets for a fresh attempt, so a `scrambled`
  /// [LockScreenKeypad] reshuffles — see its `attempt` doc.
  int _attempt = 0;

  /// Only meaningful while entering/confirming a *new* PIN — the length of
  /// the *current* one (verifyCurrent) always comes from what's already
  /// stored, via [passcodeLengthProvider]. Defaults to the existing length
  /// when changing a passcode, so switching it is opt-in, not forced.
  late int _newPinLength;

  @override
  void initState() {
    super.initState();
    final hasPasscode = ref.read(hasPasscodeProvider);
    _step = hasPasscode ? _Step.verifyCurrent : _Step.enterNew;
    _newPinLength = ref.read(passcodeLengthProvider);
  }

  String get _title => switch (_step) {
    _Step.verifyCurrent => 'Enter current PIN',
    _Step.enterNew => 'Set a new PIN',
    _Step.confirmNew => 'Confirm PIN',
  };

  int get _pinLength => _step == _Step.verifyCurrent
      ? ref.read(passcodeLengthProvider)
      : _newPinLength;

  void _onLengthChanged(int length) {
    setState(() {
      _newPinLength = length;
      _pin = '';
      _error = false;
      _attempt++;
    });
  }

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
            _attempt++;
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
          _attempt++;
        });

      case _Step.enterNew:
        setState(() {
          _newPinPending = _pin;
          _step = _Step.confirmNew;
          _pin = '';
          _attempt++;
        });

      case _Step.confirmNew:
        if (_pin != _newPinPending) {
          setState(() {
            _error = true;
            _pin = '';
            _step = _Step.enterNew;
            _newPinPending = '';
            _attempt++;
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
            if (_step == _Step.enterNew) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SegmentedButton<int>(
                  segments: [
                    for (final n in _pinLengthOptions)
                      ButtonSegment(value: n, label: Text('$n digits')),
                  ],
                  selected: {_newPinLength},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _onLengthChanged(s.first),
                ),
              ),
            ],
            const Spacer(flex: 3),
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
