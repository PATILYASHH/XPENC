import 'package:flutter/material.dart';

import '../../core/widgets/phase_placeholder.dart';

/// Graphical view: net-worth trend, spend by category, income vs expense,
/// budget rings. Pending message-capture cards surface at the top.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhasePlaceholder(
      title: 'Dashboard',
      subtitle: 'Your money at a glance',
      items: [
        PlaceholderItem('Review cards', 'Detected transactions awaiting you',
            phase: 'Phase 5'),
        PlaceholderItem('Net worth', 'Cash + Bank + Card balances',
            phase: 'Phase 2'),
        PlaceholderItem('This month', 'Income vs expense', phase: 'Phase 2'),
        PlaceholderItem('Budgets', 'Progress rings per category',
            phase: 'Phase 3'),
        PlaceholderItem('Charts', 'Trend, category pie, net-worth line',
            phase: 'Phase 8'),
      ],
    );
  }
}
