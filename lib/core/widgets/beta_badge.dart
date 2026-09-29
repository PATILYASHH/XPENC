import 'package:flutter/material.dart';

/// Small "BETA" pill for features whose behavior may still change — the
/// Pay/Request row, the More → Calculators group and its screens.
class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});

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
