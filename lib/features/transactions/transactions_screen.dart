import 'package:flutter/material.dart';

import '../../core/widgets/phase_placeholder.dart';

/// All transactions, grouped day-wise with daily totals.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Transactions',
      subtitle: 'Everything, grouped day by day',
      items: [
        PlaceholderItem('Day-wise list', 'Grouped with per-day totals',
            phase: 'Phase 2'),
        PlaceholderItem('Filters', 'Type · account · category · date range',
            phase: 'Phase 2'),
        PlaceholderItem('Search', 'Find by note, merchant or amount',
            phase: 'Phase 2'),
      ],
    );
  }
}
