import 'package:flutter/material.dart';

import '../../core/widgets/phase_placeholder.dart';

/// Total money + per-account balances. Types: Cash · Bank · Card.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Accounts',
      subtitle: 'Where your money actually sits',
      items: [
        PlaceholderItem('Total money', 'Cash + Bank + Card (net worth)',
            phase: 'Phase 2'),
        PlaceholderItem('Cash', 'Seeded on first run', phase: 'Phase 2'),
        PlaceholderItem('Bank', 'e.g. IPPB, Yes Bank — pick bank + last 4',
            phase: 'Phase 2'),
        PlaceholderItem('Card', 'Credit card = own balance; debit = linked',
            phase: 'Phase 2'),
        PlaceholderItem('Transfer', 'Cash ↔ Bank, pay credit-card bill',
            phase: 'Phase 2'),
      ],
    );
  }
}
