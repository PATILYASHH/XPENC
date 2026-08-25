import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../core/payments/upi_launcher.dart';

/// A "Pay"/"Request" row: a label, a Beta badge, and one button per
/// supported UPI app (Google Pay, PhonePe). When [payeeUpiId] isn't set yet
/// (the person has no UPI ID for Pay, or the app's own user hasn't set
/// theirs for Request), the buttons stay visible but disabled, with a
/// tappable nudge in their place — never silently hidden, since that reads
/// as broken rather than "not set up yet".
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

  Future<void> _pay(BuildContext context, UpiApp app) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await UpiLauncher.launch(
      app: app,
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
        SnackBar(content: Text("Couldn't open ${_appLabel(app)} — copied UPI ID instead")),
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _ready ? () => _pay(context, UpiApp.googlePay) : null,
                child: const Text('Google Pay'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _ready ? () => _pay(context, UpiApp.phonePe) : null,
                child: const Text('PhonePe'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _appLabel(UpiApp app) => switch (app) {
    UpiApp.googlePay => 'Google Pay',
    UpiApp.phonePe => 'PhonePe',
  };
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
