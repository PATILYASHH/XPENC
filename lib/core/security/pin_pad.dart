import 'dart:math';

import 'package:flutter/material.dart';

/// Filled/empty circles showing how many of [length] digits have been typed.
/// [shake] is set briefly after a wrong PIN to animate a horizontal shake.
class PinDots extends StatelessWidget {
  const PinDots({
    required this.entered,
    required this.length,
    this.error = false,
    super.key,
  });

  final int entered;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = error ? theme.colorScheme.error : theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < entered ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// A 0-9 + backspace grid, the same 3-column shape as the amount keypad on
/// Add Transaction — kept separate since this one has no decimal key and no
/// amount buffer to manage.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.extraKey,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Bottom-left slot — biometric shortcut on the lock screen, empty
  /// elsewhere.
  final Widget? extraKey;

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '',
      '0',
      '<',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 4; r++)
          Row(
            children: [
              for (var c = 0; c < 3; c++)
                Expanded(child: _key(context, keys[r * 3 + c])),
            ],
          ),
      ],
    );
  }

  Widget _key(BuildContext context, String k) {
    if (k.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(height: 56, child: Center(child: extraKey)),
      );
    }
    final theme = Theme.of(context);
    final isBackspace = k == '<';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => isBackspace ? onBackspace() : onDigit(k),
        child: SizedBox(
          height: 56,
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: theme.colorScheme.onSurface,
                  )
                : Text(k, style: theme.textTheme.headlineSmall),
          ),
        ),
      ),
    );
  }
}

/// The 12-slot grid [PinKeypad]/[BigPinKeypad] both lay out: `1`-`9` in
/// reading order, a blank (biometric) slot, `0`, then backspace (`<`).
const kSequentialPinKeys = <String>[
  '1', '2', '3', //
  '4', '5', '6',
  '7', '8', '9',
  '', '0', '<',
];

/// Same 12 slots as [kSequentialPinKeys], but with `0`-`9` placed in random
/// positions — the blank (biometric) slot and backspace stay fixed at their
/// usual spots so muscle memory for *those* two still works, only the
/// digits themselves move. Pass [random] to get a reproducible order (e.g.
/// in a test); omit it for real shuffling.
List<String> shuffledPinKeys([Random? random]) {
  final digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
    ..shuffle(random ?? Random());
  final keys = List<String>.filled(12, '');
  keys[11] = '<';
  var next = 0;
  for (var i = 0; i < 12; i++) {
    if (i == 9 || i == 11) continue; // blank slot, backspace: fixed in place
    keys[i] = digits[next++];
  }
  return keys;
}

/// Large filled circular buttons, the same 12-slot grid as [PinKeypad] but
/// bigger and easier to hit — GitHub #81. [scrambled] shuffles `0`-`9` into
/// random positions once, at first build; pass a fresh `key` (e.g. keyed to
/// an "attempt" counter the caller bumps on every wrong PIN) to force a new
/// shuffle for a new attempt.
class BigPinKeypad extends StatefulWidget {
  const BigPinKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.extraKey,
    this.scrambled = false,
    super.key,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Bottom-left slot — biometric shortcut on the lock screen, empty
  /// elsewhere.
  final Widget? extraKey;
  final bool scrambled;

  @override
  State<BigPinKeypad> createState() => _BigPinKeypadState();
}

class _BigPinKeypadState extends State<BigPinKeypad> {
  late final List<String> _keys = widget.scrambled
      ? shuffledPinKeys()
      : kSequentialPinKeys;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Circles as big as the available width allows, capped so they stay
        // reasonable on a tablet — not stretched to fill the whole screen.
        const spacing = 12.0;
        final diameter = ((constraints.maxWidth - spacing * 2) / 3).clamp(
          56.0,
          92.0,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < 4; r++)
              Padding(
                padding: EdgeInsets.only(bottom: r == 3 ? 0 : spacing),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var c = 0; c < 3; c++)
                      _key(context, _keys[r * 3 + c], diameter),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _key(BuildContext context, String k, double diameter) {
    if (k.isEmpty) {
      return SizedBox(
        width: diameter,
        height: diameter,
        child: Center(child: widget.extraKey),
      );
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBackspace = k == '<';
    return Material(
      shape: const CircleBorder(),
      color: isBackspace ? cs.primaryContainer : cs.surfaceContainerHighest,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => isBackspace ? widget.onBackspace() : widget.onDigit(k),
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: cs.onPrimaryContainer,
                    size: diameter * 0.34,
                  )
                : Text(
                    k,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
