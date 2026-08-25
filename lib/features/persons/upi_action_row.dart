import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../core/payments/upi_launcher.dart';

/// A "Pay"/"Request" row: a label, a Beta badge, and a single "UPI" button —
/// the generic `upi://` intent lets Android's own chooser surface whichever
/// UPI apps (Google Pay, PhonePe, anything else) are actually installed,
/// rather than this app picking specific ones. Room for other payment
/// methods (PayPal, for users outside UPI's reach) as additional buttons
/// alongside this one later. When [payeeUpiId] isn't set yet (the person has
/// no UPI ID for Pay, or the app's own user hasn't set theirs for Request),
/// the button stays visible but disabled, with a tappable nudge in its
/// place — never silently hidden, since that reads as broken rather than
/// "not set up yet".
class UpiActionRow extends StatelessWidget {
  const UpiActionRow({
    required this.action,
    required this.label,
    required this.amount,
    required this.payeeUpiId,
    required this.payeeName,
    required this.missingHint,
    required this.onMissingTap,
    this.note,
    super.key,
  });

  final UpiAction action;
  final String label;
  final Money amount;

  /// Null/blank means "not set up yet" — see class doc.
  final String? payeeUpiId;
  final String payeeName;
  final String? note;

  /// Shown, tappable, in place of a nudge when [payeeUpiId] is missing.
  final String missingHint;
  final VoidCallback onMissingTap;

  bool get _ready => payeeUpiId != null && payeeUpiId!.trim().isNotEmpty;

  Future<void> _pay(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await UpiLauncher.launch(
      action: action,
      payeeUpiId: payeeUpiId!,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );
    if (opened) return;

    await Clipboard.setData(ClipboardData(text: payeeUpiId!));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text("Couldn't open a UPI app — copied UPI ID instead")),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
        if (!_ready)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onMissingTap,
              child: Text(
                missingHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _ready ? () => _pay(context) : null,
            child: const Text('UPI'),
          ),
        ),
      ],
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
