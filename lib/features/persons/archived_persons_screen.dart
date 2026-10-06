import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'person_avatar.dart';
import '../../core/widgets/nav_bar_inset.dart';

/// People and groups hidden via **Archive** — only ever by hand (the
/// Persons long-press sheet, a group's menu, or "Archive" on the settled
/// prompt). Restoring one here is the only way back — archiving never
/// touches their lend/borrow or expense history.
class ArchivedPersonsScreen extends StatelessWidget {
  const ArchivedPersonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppTopBar(
          title: const Text('Archived'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Individual'),
              Tab(text: 'Group'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ArchivedPeople(), _ArchivedGroups()],
        ),
      ),
    );
  }
}

class _ArchivedPeople extends ConsumerWidget {
  const _ArchivedPeople();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(archivedPersonsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _Message("Couldn't load archived people."),
          data: (people) {
            if (people.isEmpty) return const _Message('No archived people.');
            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ).plusNavBar(context),
              itemCount: people.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) =>
                  _ArchivedPersonTile(person: people[i]),
            );
          },
        );
  }
}

class _ArchivedGroups extends ConsumerWidget {
  const _ArchivedGroups();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(archivedGroupsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _Message("Couldn't load archived groups."),
          data: (groups) {
            if (groups.isEmpty) return const _Message('No archived groups.');
            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ).plusNavBar(context),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) => _ArchivedGroupTile(group: groups[i]),
            );
          },
        );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          AppIcon(
            Icons.inventory_2_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedPersonTile extends ConsumerWidget {
  const _ArchivedPersonTile({required this.person});

  final PersonRow person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ArchivedTile(
      leading: PersonAvatar(name: person.name, photoPath: person.photoPath),
      name: person.name,
      onRestore: () => ref.read(dbProvider).unarchivePerson(person.id),
    );
  }
}

class _ArchivedGroupTile extends ConsumerWidget {
  const _ArchivedGroupTile({required this.group});

  final GroupRow group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _ArchivedTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        child: const AppIcon(Icons.groups_outlined, size: 20),
      ),
      name: group.name,
      onRestore: () => ref.read(dbProvider).unarchiveGroup(group.id),
    );
  }
}

class _ArchivedTile extends StatelessWidget {
  const _ArchivedTile({
    required this.leading,
    required this.name,
    required this.onRestore,
  });

  final Widget leading;
  final String name;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: leading,
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Archived',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: TextButton.icon(
        icon: const AppIcon(Icons.unarchive_outlined, size: 18),
        label: const Text('Restore'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          await onRestore();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('"$name" restored')));
        },
      ),
    );
  }
}
