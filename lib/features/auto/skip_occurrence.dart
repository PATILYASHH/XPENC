import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/routing/app_router.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../core/l10n/l10n.dart';

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
      title: const Tr('Skip next'),
      subtitle: Text(
        tr('Skips {0} only — nothing posts, and the rule '
        'carries on from {1}', [_day(rule.nextDueDate), _day(after)]),
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
    tr('"{0}" skips {1} — next on {2}', [rule.name, _day(skip.skipped), _day(skip.next)]),
    action: SnackBarAction(
      label: tr('Undo'),
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

/// Pays [rule]'s occurrence on [confirmedDue] now (Pay now, GitHub #86) and
/// says what happened. [confirmedDue] is the date the confirm dialog showed:
/// if the app posted that occurrence on its own meanwhile, nothing is paid
/// a second time (GitHub #203). The "coming up" alert is rescheduled right
/// away, like a skip — otherwise it would still warn about the paid date.
Future<void> payNowAndReport(
  BuildContext context,
  WidgetRef ref,
  RecurringRuleRow rule, {
  required DateTime confirmedDue,
}) async {
  // The screen's own messenger, taken before the await — the same one the
  // rule's page always reported through.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final db = ref.read(dbProvider);
  final result = await db.payRecurringRuleNowResult(
    rule.id,
    expectedDueDate: confirmedDue,
  );
  await ref.read(notificationServiceProvider).syncRecurringNotifications();
  final message = switch (result) {
    PayNowResult.posted => tr('"{0}" posted', [rule.name]),
    // A card bill that's already been paid (#183).
    PayNowResult.nothingOwed => tr('Nothing left to pay on "{0}"', [rule.name]),
    PayNowResult.alreadyPosted => tr(
      '"{0}" for {1} already posted — nothing more was paid.',
      [rule.name, _day(confirmedDue)],
    ),
  };
  if (messenger == null) {
    showAppSnackBar(message);
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
