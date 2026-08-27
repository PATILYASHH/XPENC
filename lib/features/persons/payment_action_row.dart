import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One payment method's worth of state for a [PersonPaymentRow] — a button
/// label, the id used to decide whether it's ready, and the launch attempt
/// itself. [missingLabel] names the id in prose (e.g. "UPI ID") for the
/// row's combined nudge text; it deliberately excludes whose id it is —
/// the caller's hint template supplies that ("their" vs "your").
class PaymentMethodSpec {
  const PaymentMethodSpec({
    required this.buttonLabel,
    required this.missingLabel,
    required this.id,
    required this.attempt,
  });

  final String buttonLabel;
  final String missingLabel;

  /// Null/blank means "not set up yet".
  final String? id;

  /// Launches the payment link; returns whether it actually opened
  /// something (mirrors `UpiLauncher.launch` and friends).
  final Future<bool> Function() attempt;

  bool get ready => id != null && id!.trim().isNotEmpty;
}

/// A "Pay"/"Request" section: a label, a Beta badge, one button per
/// payment method (UPI, PayPal, Venmo, Cash App, Revolut, ...), and — when
/// any aren't set up yet — a single combined nudge naming them, rather than
/// one hint line per method. A method whose id isn't set stays visible but
/// disabled, never silently hidden, since that reads as broken rather than
/// "not set up yet". Tapping a ready button that fails to open an app
/// copies that method's id to the clipboard instead.
class PersonPaymentRow extends StatelessWidget {
  const PersonPaymentRow({
    required this.label,
    required this.methods,
    required this.missingHint,
    required this.onMissingTap,
    super.key,
  });

  final String label;
  final List<PaymentMethodSpec> methods;

  /// Builds the nudge text from the [PaymentMethodSpec.missingLabel]s of
  /// whichever methods aren't ready yet.
  final String Function(List<String> missingLabels) missingHint;
  final VoidCallback onMissingTap;

  Future<void> _pay(BuildContext context, PaymentMethodSpec method) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await method.attempt();
    if (opened) return;

    await Clipboard.setData(ClipboardData(text: method.id!));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't open ${method.buttonLabel} — copied "
            "${method.missingLabel} instead",
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = [
      for (final m in methods)
        if (!m.ready) m.missingLabel,
    ];

    final rows = <Widget>[];
    for (var i = 0; i < methods.length; i += 2) {
      final first = methods[i];
      final second = i + 1 < methods.length ? methods[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: Row(
            children: [
              Expanded(child: _MethodButton(method: first, onTap: _pay)),
              if (second != null) ...[
                const SizedBox(width: 10),
                Expanded(child: _MethodButton(method: second, onTap: _pay)),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const _BetaBadge(),
          ],
        ),
        const SizedBox(height: 8),
        if (missing.isNotEmpty) ...[
          _MissingHint(text: missingHint(missing), onTap: onMissingTap),
          const SizedBox(height: 4),
        ],
        ...rows,
      ],
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({required this.method, required this.onTap});

  final PaymentMethodSpec method;
  final void Function(BuildContext context, PaymentMethodSpec method) onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: method.ready ? () => onTap(context, method) : null,
      child: Text(method.buttonLabel),
    );
  }
}

class _MissingHint extends StatelessWidget {
  const _MissingHint({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'BETA',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onTertiaryContainer,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
