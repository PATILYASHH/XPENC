import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../core/l10n/l10n.dart';

/// Asks, then permanently deletes [person] via [AppDatabase.deletePerson].
/// The dialog spells out how much history goes with them, since any money
/// those entries moved through an account is reversed too. Returns true
/// once deleted, so a detail page can pop itself.
Future<bool> confirmDeletePerson(
  BuildContext context,
  WidgetRef ref,
  PersonRow person,
) async {
  final db = ref.read(dbProvider);
  final count = await db.countEntriesForPerson(person.id);
  if (!context.mounted) return false;
  final confirmed = await _confirm(
    context,
    title: tr('Delete "{0}"?', [person.name]),
    body: count == 0
        ? tr("This permanently deletes the person. It can't be undone.")
        : tr(
            'This permanently deletes the person and their {0}, including '
            'their share of group expenses. Any money those entries moved '
            "through an account is reversed. It can't be undone — archive "
            'them instead to keep the history.',
            [plural(count, '1 entry', '{0} entries')],
          ),
  );
  if (!confirmed) return false;
  await db.deletePerson(person.id);
  if (context.mounted) _say(context, tr('Person deleted'));
  return true;
}

/// Same as [confirmDeletePerson], for a group — every expense in it is
/// reversed. Members themselves are kept.
Future<bool> confirmDeleteGroup(
  BuildContext context,
  WidgetRef ref,
  GroupRow group,
) async {
  final db = ref.read(dbProvider);
  final count = await db.countExpensesForGroup(group.id);
  if (!context.mounted) return false;
  final confirmed = await _confirm(
    context,
    title: tr('Delete "{0}"?', [group.name]),
    body: count == 0
        ? tr("This permanently deletes the group. Its members are kept. It "
              "can't be undone.")
        : tr(
            'This permanently deletes the group and its {0}. The dues and '
            "money they created are reversed; members are kept. It can't be "
            'undone — archive it instead to keep the history.',
            [plural(count, '1 expense', '{0} expenses')],
          ),
  );
  if (!confirmed) return false;
  await db.deleteGroup(group.id);
  if (context.mounted) _say(context, tr('Group deleted'));
  return true;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Tr('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Tr('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
