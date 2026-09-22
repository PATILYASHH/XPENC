import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../currency.dart';
import '../money.dart';
import '../../features/add_transaction/amount_buffer.dart';

/// A [ChangeNotifier]-based, `TextEditingController`-shaped holder for an
/// [AmountKeypadField]'s buffer text — a near drop-in replacement at call
/// sites that only ever read `.text` (e.g. `Money.tryParse(controller.text)`).
class AmountKeypadController extends ChangeNotifier {
  AmountKeypadController({String text = ''})
    : _text = text,
      _freshEntry = text.isNotEmpty;

  String _text;
  bool _freshEntry;

  String get text => _text;

  /// Replaces the buffer wholesale (e.g. clearing a field). Marks the buffer
  /// "fresh" so the next keypad tap starts a new number instead of appending
  /// — same contract [setAmount] relies on for prefilled edit flows.
  set text(String value) {
    _text = value;
    _freshEntry = true;
    notifyListeners();
  }

  /// Loads [amount] as the starting buffer for an edit/prefill flow. The next
  /// keypad tap replaces it instead of appending — a calculator starting a
  /// new number after showing a result, same as
  /// `_AddTransactionScreenState._bufferFromMoney`/`_freshAmountEntry`.
  void setAmount(Money amount) => text = _bufferFromMoney(amount);

  /// The live amount. Tolerates a trailing `.` while mid-type.
  Money get amount {
    var b = _text;
    if (b.endsWith('.')) b = b.substring(0, b.length - 1);
    return Money.tryParse(b) ?? const Money.zero();
  }

  void applyKey(String key) {
    _text = AmountBuffer.applyKey(_text, key, freshEntry: _freshEntry);
    _freshEntry = false;
    notifyListeners();
  }

  void applyBackspace() {
    _freshEntry = false;
    _text = AmountBuffer.applyBackspace(_text);
    notifyListeners();
  }

  /// Render a stored amount back into keypad-buffer text: plain rupees with
  /// up to two decimals, dropping a trailing `.00`/`.X0`. `1500` paise ->
  /// `"15"`, `1550` -> `"15.5"`, `1555` -> `"15.55"`.
  static String _bufferFromMoney(Money amount) {
    final paise = amount.abs.paise;
    final rupees = paise ~/ 100;
    final fraction = paise % 100;
    if (fraction == 0) return '$rupees';
    if (fraction % 10 == 0) return '$rupees.${fraction ~/ 10}';
    return '$rupees.${fraction.toString().padLeft(2, '0')}';
  }
}

/// Shared "only one keypad open at a time" coordinator for a sheet/dialog
/// that has *more than one* [AmountKeypadField] (e.g. Recurring Rule's
/// amount + promo amount + foreign amount). Pass the same instance to every
/// field's `group` parameter — tapping one field's display box closes
/// whichever other field in the group was open, the same way one real
/// `TextField` gaining focus blurs another. A sheet with only one money
/// field doesn't need this; leave `group` null.
class AmountKeypadFieldGroup extends ChangeNotifier {
  AmountKeypadController? _active;

  AmountKeypadController? get active => _active;

  void activate(AmountKeypadController controller) {
    if (_active == controller) return;
    _active = controller;
    notifyListeners();
  }

  void clear() {
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }
}

/// A `Money`-amount input: a tappable box styled like a `TextField` that
/// opens the app's own Samsung-style digit keypad below it instead of the OS
/// keyboard — see GitHub #135. Every screen that reads a currency amount
/// should use this instead of a plain `TextField` with a numeric
/// `keyboardType`, so the app never mixes the two input mechanisms for money.
///
/// [yieldTo] should list every *real* `FocusNode` on the same sheet/screen
/// (a name, note, or title field). This widget listens to them itself and
/// collapses its own keypad whenever one of them gains focus, so the custom
/// keypad and the OS keyboard are never both on screen at once — the same
/// invariant `_AddTransactionScreenState._textFieldFocused` enforced by hand,
/// now owned by the widget instead of every call site.
///
/// When a sheet has more than one money field, pass the same
/// [AmountKeypadFieldGroup] as [group] to each of them instead — see its doc
/// comment.
class AmountKeypadField extends StatefulWidget {
  const AmountKeypadField({
    required this.controller,
    this.label,
    this.hintText,
    this.currency,
    this.autofocus = false,
    this.yieldTo = const [],
    this.group,
    this.style,
    this.onChanged,
    this.displayKey,
    this.isDense = false,
    this.showPrefix = true,
    super.key,
  });

  final AmountKeypadController controller;
  final String? label;
  final String? hintText;

  /// Formats the prefix symbol against this currency instead of the globally
  /// configured one — for a foreign-amount field. Defaults to
  /// [MoneyFormat.inputPrefix] (the app's configured currency) when null.
  final Currency? currency;

  /// False when the currency is already shown elsewhere next to this field
  /// (e.g. a currency-picker chip) — suppresses [currency]/
  /// [MoneyFormat.inputPrefix] entirely instead of showing it twice.
  final bool showPrefix;

  /// Opens the keypad immediately, the way `autofocus: true` opens the OS
  /// keyboard on a real `TextField`.
  final bool autofocus;

  final List<FocusNode> yieldTo;

  /// Coordinates visibility with sibling [AmountKeypadField]s on the same
  /// sheet — see [AmountKeypadFieldGroup].
  final AmountKeypadFieldGroup? group;

  final TextStyle? style;
  final ValueChanged<String>? onChanged;

  /// Tighter padding, for a field squeezed into an inline row rather than
  /// standing alone in a sheet/dialog — mirrors `TextField`'s `isDense`.
  final bool isDense;

  /// Key for the display `Text`, so a widget test can find it the same way
  /// `test/add_transaction_currency_test.dart` looks up `Key('amountDisplay')`.
  final Key? displayKey;

  @override
  State<AmountKeypadField> createState() => _AmountKeypadFieldState();
}

class _AmountKeypadFieldState extends State<AmountKeypadField> {
  /// Only meaningful when [AmountKeypadField.group] is null — with a group,
  /// visibility is derived from `group.active` instead (see [_active]).
  bool _standaloneActive = false;

  bool get _active => widget.group != null
      ? widget.group!.active == widget.controller
      : _standaloneActive;

  @override
  void initState() {
    super.initState();
    _standaloneActive = widget.autofocus;
    if (widget.autofocus) widget.group?.activate(widget.controller);
    widget.controller.addListener(_onControllerChanged);
    widget.group?.addListener(_onControllerChanged);
    for (final node in widget.yieldTo) {
      node.addListener(_onYieldFocusChanged);
    }
  }

  @override
  void didUpdateWidget(covariant AmountKeypadField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.group != widget.group) {
      oldWidget.group?.removeListener(_onControllerChanged);
      widget.group?.addListener(_onControllerChanged);
    }
    if (!identical(oldWidget.yieldTo, widget.yieldTo)) {
      for (final node in oldWidget.yieldTo) {
        node.removeListener(_onYieldFocusChanged);
      }
      for (final node in widget.yieldTo) {
        node.addListener(_onYieldFocusChanged);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.group?.removeListener(_onControllerChanged);
    for (final node in widget.yieldTo) {
      node.removeListener(_onYieldFocusChanged);
    }
    super.dispose();
  }

  void _onControllerChanged() => setState(() {});

  void _onYieldFocusChanged() {
    if (!widget.yieldTo.any((n) => n.hasFocus) || !_active) return;
    if (widget.group != null) {
      widget.group!.clear();
    } else {
      setState(() => _standaloneActive = false);
    }
  }

  void _activate() {
    FocusScope.of(context).unfocus();
    if (widget.group != null) {
      widget.group!.activate(widget.controller);
    } else if (!_standaloneActive) {
      setState(() => _standaloneActive = true);
    }
  }

  void _onDigit(String k) {
    widget.controller.applyKey(k);
    widget.onChanged?.call(widget.controller.text);
  }

  void _onBackspace() {
    widget.controller.applyBackspace();
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AmountKeypadDisplayBox(
          text: widget.controller.text,
          active: _active,
          onTap: _activate,
          label: widget.label,
          hintText: widget.hintText,
          currency: widget.currency,
          style: widget.style,
          displayKey: widget.displayKey,
          isDense: widget.isDense,
          showPrefix: widget.showPrefix,
        ),
        if (_active) ...[
          const SizedBox(height: 8),
          AmountKeypadGrid(onDigit: _onDigit, onBackspace: _onBackspace),
        ],
      ],
    );
  }
}

/// The tappable, `TextField`-styled box that shows an amount buffer without
/// ever being a real `TextField` — so the OS keyboard can never appear for
/// it. Split out from [AmountKeypadField] so a screen with *several* money
/// fields sharing one keypad region (like Add Transaction's main amount,
/// split rows, hybrid legs, foreign and change amounts) can use just the
/// display box per field, wired to whichever field is the current active
/// target for a single shared [AmountKeypadGrid], instead of each field
/// getting its own embedded keypad.
class AmountKeypadDisplayBox extends StatelessWidget {
  const AmountKeypadDisplayBox({
    required this.text,
    required this.active,
    required this.onTap,
    this.label,
    this.hintText,
    this.currency,
    this.style,
    this.displayKey,
    this.isDense = false,
    this.showPrefix = true,
    super.key,
  });

  final String text;

  /// Whether this box is the current target of whatever keypad it's paired
  /// with — purely visual (shows the focused-border look), the caller owns
  /// the actual coordination.
  final bool active;
  final VoidCallback onTap;
  final String? label;
  final String? hintText;

  /// Formats the prefix symbol against this currency instead of the globally
  /// configured one — for a foreign-amount field. Defaults to
  /// [MoneyFormat.inputPrefix] (the app's configured currency) when null.
  final Currency? currency;
  final TextStyle? style;

  /// Key for the display `Text`, so a widget test can find it the same way
  /// `test/add_transaction_currency_test.dart` looks up `Key('amountDisplay')`.
  final Key? displayKey;

  /// Tighter padding, for a field squeezed into an inline row rather than
  /// standing alone in a sheet/dialog — mirrors `TextField`'s `isDense`.
  final bool isDense;

  /// False when the currency symbol is already shown elsewhere next to this
  /// field (e.g. Add Transaction's foreign-amount row has its own currency
  /// picker chip) — suppresses [currency]/[MoneyFormat.inputPrefix] entirely
  /// instead of showing it twice.
  final bool showPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefix = !showPrefix
        ? ''
        : currency != null
        ? (MoneyFormat.showSymbol ? '${currency!.symbol} ' : '')
        : MoneyFormat.inputPrefix;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: isDense,
          labelText: label,
          hintText: hintText,
          prefixText: prefix,
        ),
        isFocused: active,
        isEmpty: text.isEmpty,
        child: Text(
          text,
          key: displayKey,
          style:
              style ??
              theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: kTabularFigures,
              ),
        ),
      ),
    );
  }
}

/// The 4x3 Samsung-style digit grid: `1`-`9`, `.`, `0`, backspace. Each key
/// is its own shaded block (not a bare ripple-on-transparent), with a brief
/// press animation and a haptic tick — see GitHub #135. Public so a
/// multi-field screen can host a single shared instance instead of going
/// through [AmountKeypadField]'s one-grid-per-field composition.
class AmountKeypadGrid extends StatelessWidget {
  const AmountKeypadGrid({required this.onDigit, required this.onBackspace, super.key});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  static const _keys = <String>[
    '1', '2', '3', //
    '4', '5', '6', //
    '7', '8', '9', //
    '.', '0', '<', //
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 4; r++)
          Row(
            children: [
              for (var c = 0; c < 3; c++) Expanded(child: _buildKey(_keys[r * 3 + c])),
            ],
          ),
      ],
    );
  }

  Widget _buildKey(String k) {
    if (k == '<') return _BackspaceKey(onBackspace: onBackspace);
    return _DigitKey(label: k, onTap: () => onDigit(k));
  }
}

/// One shaded, rounded-rect key block — the Samsung One UI keyboard look:
/// its own background, not just an `InkWell` on transparent, with a brief
/// press-darken/scale and a haptic tick on tap.
class _DigitKey extends StatefulWidget {
  const _DigitKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_DigitKey> createState() => _DigitKeyState();
}

class _DigitKeyState extends State<_DigitKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
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
}

/// The backspace key — same shaded-block look as [_DigitKey] but on
/// `primaryContainer` (matching `BigPinKeypad`'s backspace styling), with a
/// single tap deleting once and a press-and-hold auto-repeating deletes
/// every ~120ms, like a system keyboard's backspace.
class _BackspaceKey extends StatefulWidget {
  const _BackspaceKey({required this.onBackspace});

  final VoidCallback onBackspace;

  @override
  State<_BackspaceKey> createState() => _BackspaceKeyState();
}

class _BackspaceKeyState extends State<_BackspaceKey> {
  bool _pressed = false;
  bool _longPressFired = false;
  Timer? _initialDelay;
  Timer? _repeatTimer;

  void _startRepeating() {
    _initialDelay = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        widget.onBackspace();
      });
    });
  }

  void _stopRepeating() {
    _initialDelay?.cancel();
    _repeatTimer?.cancel();
    _initialDelay = null;
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () {
          setState(() => _pressed = false);
          _stopRepeating();
        },
        onTap: () {
          if (_longPressFired) {
            _longPressFired = false;
            return;
          }
          HapticFeedback.lightImpact();
          widget.onBackspace();
        },
        onLongPressStart: (_) {
          _longPressFired = true;
          HapticFeedback.lightImpact();
          _startRepeating();
        },
        onLongPressEnd: (_) {
          _stopRepeating();
          setState(() => _pressed = false);
        },
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Material(
            color: cs.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              height: 56,
              child: Center(
                child: Icon(
                  Icons.backspace_outlined,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
