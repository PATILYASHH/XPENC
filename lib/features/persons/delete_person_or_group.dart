import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

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
    title: 'Delete "${person.name}"?',
    body: count == 0
        ? "This permanently deletes the person. It can't be undone."
        : 'This permanently deletes the person and their $count '
              '${count == 1 ? 'entry' : 'entries'}, including their share '
              'of group expenses. Any money those entries moved through an '
              "account is reversed. It can't be undone — archive them "
              'instead to keep the history.',
  );
  if (!confirmed) return false;
  await db.deletePerson(person.id);
  if (context.mounted) _say(context, 'Person deleted');
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
    title: 'Delete "${group.name}"?',
    body: count == 0
        ? "This permanently deletes the group. Its members are kept. It "
              "can't be undone."
        : 'This permanently deletes the group and its $count '
              '${count == 1 ? 'expense' : 'expenses'}. The dues and money '
              'they created are reversed; members are kept. It can\'t be '
              'undone — archive it instead to keep the history.',
  );
  if (!confirmed) return false;
  await db.deleteGroup(group.id);
  if (context.mounted) _say(context, 'Group deleted');
  return true;
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
