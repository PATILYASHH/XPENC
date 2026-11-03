import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/routing/app_router.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// "Skip next" in an Auto rule's actions (GitHub #184): the rule stays on
/// and steps over one date — a gym month you're away for, a fee waived
/// once, rent paid some other way. Shared by the Auto list and the rule's
/// own page so both say the same thing.
class SkipNextTile extends StatelessWidget {
  const SkipNextTile({required this.rule, required this.onTap, super.key});

  final RecurringRuleRow rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final after = AppDatabase.nextOccurrence(
      rule.frequency,
      rule.nextDueDate,
      dayOfMonth: rule.dayOfMonth,
      monthOfYear: rule.monthOfYear,
    );
    return AppListTile(
      leading: const AppIcon(Icons.skip_next_rounded),
      title: const Text('Skip next'),
      subtitle: Text(
        'Skips ${_day(rule.nextDueDate)} only — nothing posts, and the rule '
        'carries on from ${_day(after)}',
      ),
      onTap: onTap,
    );
  }
}

/// Skips [rule]'s next occurrence and says so, with an Undo. The "coming
/// up" alert is rescheduled right away — otherwise it would still warn
/// about the skipped date until the app next opened.
Future<void> skipNextOccurrence(WidgetRef ref, RecurringRuleRow rule) async {
  final db = ref.read(dbProvider);
  final notifications = ref.read(notificationServiceProvider);
  final skip = await db.skipRecurringRuleOccurrence(rule.id);
  await notifications.syncRecurringNotifications();
  showAppSnackBar(
    '"${rule.name}" skips ${_day(skip.skipped)} — next on ${_day(skip.next)}',
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () async {
        final undone = await db.unskipRecurringRuleOccurrence(
          rule.id,
          skipped: skip.skipped,
          next: skip.next,
        );
        if (undone) await notifications.syncRecurringNotifications();
      },
    ),
  );
}

/// "2 Nov", or "2 Nov 2027" once it's not this year — a yearly rule's next
/// date always is.
String _day(DateTime d) => DateFormat(
  d.year == DateTime.now().year ? 'd MMM' : 'd MMM yyyy',
).format(d);
