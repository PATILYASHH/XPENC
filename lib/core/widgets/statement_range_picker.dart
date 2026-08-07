import 'package:flutter/material.dart';

/// This month / Last month / a custom range picked via the platform's
/// built-in range picker — the same choice sheet every statement download
/// (per-account, per-budget-category, and the combined all-accounts one)
/// offers, so picking a period always feels the same.
Future<DateTimeRange?> pickStatementRange(BuildContext context) async {
  final now = DateTime.now();
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Statement period',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('This month'),
            onTap: () => Navigator.of(sheetContext).pop('this'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_month_outlined),
            title: const Text('Last month'),
            onTap: () => Navigator.of(sheetContext).pop('last'),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_outlined),
            title: const Text('Custom range'),
            onTap: () => Navigator.of(sheetContext).pop('custom'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null) return null;

  switch (choice) {
    case 'this':
      return DateTimeRange(
        start: DateTime(now.year, now.month),
        end: DateTime(
          now.year,
          now.month + 1,
        ).subtract(const Duration(days: 1)),
      );
    case 'last':
      return DateTimeRange(
        start: DateTime(now.year, now.month - 1),
        end: DateTime(now.year, now.month).subtract(const Duration(days: 1)),
      );
    default:
      if (!context.mounted) return null;
      return showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDateRange: DateTimeRange(
          start: DateTime(now.year, now.month),
          end: now,
        ),
      );
  }
}
