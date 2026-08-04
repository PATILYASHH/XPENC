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
