import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The ➕ route. Expense / Income / Transfer — transfer is required for
/// cash↔bank and paying a credit-card bill.
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

enum _TxKind { expense, income, transfer }

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  _TxKind _kind = _TxKind.expense;

  Color get _kindColor => switch (_kind) {
        _TxKind.expense => AppColors.expense,
        _TxKind.income => AppColors.income,
        _TxKind.transfer => AppColors.transfer,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Add'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<_TxKind>(
              segments: const [
                ButtonSegment(value: _TxKind.expense, label: Text('Expense')),
                ButtonSegment(value: _TxKind.income, label: Text('Income')),
                ButtonSegment(value: _TxKind.transfer, label: Text('Transfer')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '₹0.00',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _kindColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Amount keypad · account · category · date · note',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.construction_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Built in Phase 2 — needs the data layer first.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
