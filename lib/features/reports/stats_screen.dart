import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/budget_cycle.dart';
import '../../data/providers.dart';
import 'stats_modules.dart';
import 'stats_sections.dart';
import 'xpenc_score_screen.dart';

/// The Stats hub: the XPENC Score up top, this month at a glance, then one
/// tile per [StatsModule] — each opens a focused screen (cash flow, spending,
/// loans, people…) instead of one endless scroll. Every number is derived
/// from the ledger, so transfers between your own accounts never register as
/// income or expense.
///
/// [embedded] is true when this screen is a bottom-nav tab (GitHub #70) —
/// `AppShell`'s shared top bar owns the title/actions then. Default `false`
/// keeps `/more/stats` a standalone page.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final showYear = ref.watch(statsShowYearProvider);

    const modules = StatsModule.values;
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const XpencScoreCard(),
        const SizedBox(height: 28),
        const SectionCaption('This month'),
        const ThisMonthSection(),
        const SizedBox(height: 28),
        const SectionCaption('Explore'),
        for (var i = 0; i < modules.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: StatsModuleTile(modules[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < modules.length
                      ? StatsModuleTile(modules[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Text(
          'Transfers between your own accounts are never counted as income '
          'or expense.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Download report',
            onPressed: () => _downloadReport(context, ref, month, showYear),
          ),
        ],
      ),
      body: body,
    );
  }
}

/// Generates and shares the Income & Expense Report PDF for whatever period
/// the screen is currently showing.
Future<void> _downloadReport(
  BuildContext context,
  WidgetRef ref,
  DateTime month,
  bool showYear,
) async {
  final DateTime start;
  final DateTime end;
  final String periodLabel;
  final String fileSuffix;
  if (showYear) {
    start = DateTime(month.year);
    end = DateTime(month.year + 1).subtract(const Duration(milliseconds: 1));
    periodLabel = '${month.year}';
    fileSuffix = '${month.year}';
  } else {
    final startDay = ref.read(budgetStartDayProvider);
    final period = budgetPeriodFor(month, startDay);
    start = period.start;
    end = period.end;
    periodLabel = startDay == 1
        ? DateFormat('MMMM yyyy').format(month)
        : '${DateFormat('MMMM yyyy').format(month)} '
              '(${budgetPeriodRangeLabel(month, startDay)})';
    fileSuffix = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);
  final categories = ref.read(categoryMapProvider);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Generating report...')));
  try {
    final file = await service.writeIncomeExpenseReportPdf(
      start: start,
      end: end,
      periodLabel: periodLabel,
      fileSuffix: fileSuffix,
      categories: categories,
    );
    await service.share(
      file,
      subject: 'Income and expense report - $periodLabel',
    );
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Exported ${file.uri.pathSegments.last}')),
      );
  } catch (e) {
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text("Couldn't generate report: $e")));
  }
}
