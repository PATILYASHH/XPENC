import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// People hidden via **Archive** on the Persons screen. Restoring one here is
/// the only way back — archiving never touches their lend/borrow history.
class ArchivedPersonsScreen extends ConsumerWidget {
  const ArchivedPersonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final archivedAsync = ref.watch(archivedPersonsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived people')),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            "Couldn't load archived people.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        data: (people) {
          if (people.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No archived people.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: people.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) => _ArchivedPersonTile(person: people[i]),
          );
        },
      ),
    );
  }
}

class _ArchivedPersonTile extends ConsumerWidget {
  const _ArchivedPersonTile({required this.person});

  final PersonRow person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        child: Text(
          _initials(person.name),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      title: Text(
        person.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Archived',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: TextButton.icon(
        icon: const Icon(Icons.unarchive_outlined, size: 18),
        label: const Text('Restore'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await ref.read(dbProvider).unarchivePerson(person.id);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('"${person.name}" restored')),
            );
        },
      ),
    );
  }
}

/// Two-letter initials from a name, e.g. "Rahul Kumar" -> "RK".
String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
