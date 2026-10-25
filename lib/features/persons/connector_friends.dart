import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/connector/connector_platform.dart';
import '../../core/connector/friends/connector_friend.dart';
import '../../core/connector/friends/connector_friends_source.dart';
import '../../core/platform/platform_features.dart';
import '../../core/widgets/app_surfaces.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../connector/connector_controller.dart';

/// Where Connector friends come from here, if anywhere: the Connector app on
/// Android, the built-in Connector on XPENC web (built with an anon key).
final connectorFriendsSourceProvider = Provider<ConnectorFriendsSource?>((ref) {
  if (PlatformFeatures.connectorFriendsApp) return const AndroidFriendsSource();
  final platform = connectorPlatform;
  if (platform == null) return null;
  return SessionFriendsSource(store: platform.store, api: platform.friends);
});

/// The current friends list. [FriendsHidden] means no friend features at
/// all — no Connector on this device.
final connectorFriendsProvider = FutureProvider.autoDispose<FriendsLookup>((
  ref,
) async {
  final source = ref.watch(connectorFriendsSourceProvider);
  if (source == null) return const FriendsHidden();
  // XPENC web: connecting or disconnecting changes the answer.
  if (PlatformFeatures.isWeb) {
    ref.watch(connectorProvider.select((v) => v.state.connected));
  }
  try {
    return await source.load();
  } on MissingPluginException {
    return const FriendsHidden();
  }
});

/// True once it's known there's a Connector here — for showing the friend
/// options at all. Errors count as "yes": the picker explains. For a
/// widget's `build`; elsewhere, [friendsShownIn] a `ref.read`.
bool connectorFriendsShown(WidgetRef ref) =>
    friendsShownIn(ref.watch(connectorFriendsProvider));

bool friendsShownIn(AsyncValue<FriendsLookup> lookup) => switch (lookup) {
  AsyncData(value: FriendsHidden()) => false,
  AsyncLoading(hasValue: false) => false,
  _ => true,
};

/// Opens wherever friends are managed: the Connector app, or XPENC web's
/// Settings → Connector.
Future<void> openConnectorForFriends(BuildContext context) async {
  if (PlatformFeatures.connectorFriendsApp) {
    final opened = await AndroidFriendsSource.openConnector();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text("Couldn't open the Connector app.")),
        );
    }
    return;
  }
  await context.push('/more/settings/connector');
}

/// Picks a Connector friend — for adding them as a person, or linking
/// [linking] to them. Friends already linked to someone else show who, and
/// can't be picked twice.
Future<ConnectorFriend?> pickConnectorFriend(
  BuildContext context, {
  PersonRow? linking,
}) => showAppSheet<ConnectorFriend>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _FriendPickerSheet(linking: linking),
);

/// "Link Connector friend" on an existing person: picks, links, says so.
Future<void> linkPersonToFriend(
  BuildContext context,
  WidgetRef ref,
  PersonRow person,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final friend = await pickConnectorFriend(context, linking: person);
  if (friend == null) return;
  try {
    await ref
        .read(dbProvider)
        .linkPersonFriend(
          person.id,
          friendId: friend.id,
          username: friend.username,
        );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${person.name} is @${friend.username}')),
      );
  } on FriendAlreadyLinked catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('@${friend.username} is already ${e.person.name}.'),
        ),
      );
  }
}

Future<void> confirmUnlinkFriend(
  BuildContext context,
  WidgetRef ref,
  PersonRow person,
) async {
  final ok = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Unlink @${person.remoteUsername}?'),
      content: Text(
        '${person.name} stays, with all their history. They just stop being '
        'tied to their Connector account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Unlink'),
        ),
      ],
    ),
  );
  if (ok == true) await ref.read(dbProvider).unlinkPersonFriend(person.id);
}

/// "@username · Connector friend" on a linked person's page (tap to unlink);
/// "Link Connector friend" on anyone else's, where there's a Connector.
class ConnectorFriendBadge extends ConsumerWidget {
  const ConnectorFriendBadge({required this.person, super.key});

  final PersonRow person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = person.remoteUsername;
    if (username == null) {
      if (!connectorFriendsShown(ref)) return const SizedBox.shrink();
      return Center(
        child: TextButton.icon(
          onPressed: () => linkPersonToFriend(context, ref, person),
          icon: const AppIcon(Icons.group_outlined, size: 18),
          label: const Text('Link Connector friend'),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Center(
        child: InputChip(
          avatar: AppIcon(Icons.link_rounded, size: 18, color: cs.secondary),
          label: Text('@$username · Connector friend'),
          tooltip: 'Unlink',
          onPressed: () => confirmUnlinkFriend(context, ref, person),
        ),
      ),
    );
  }
}

class _FriendPickerSheet extends ConsumerWidget {
  const _FriendPickerSheet({this.linking});

  final PersonRow? linking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lookup = ref.watch(connectorFriendsProvider);
    final linkedTo = <String, PersonRow>{
      for (final p in [
        ...?ref.watch(personsProvider).valueOrNull,
        ...?ref.watch(archivedPersonsProvider).valueOrNull,
      ])
        ?p.remoteFriendId: p,
    };
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.4,
    );

    Widget openButton(String label) => Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => openConnectorForFriends(context),
        icon: const AppIcon(Icons.open_in_new_rounded, size: 18),
        label: Text(label),
      ),
    );

    final List<Widget> body = switch (lookup) {
      AsyncData(value: FriendsLoaded(:final friends, :final updatedAt)) => [
        if (friends.isEmpty) ...[
          Text(
            'No friends on Connector yet. Add them there by username, then '
            'come back.',
            style: muted,
          ),
          const SizedBox(height: 12),
          openButton(
            PlatformFeatures.connectorFriendsApp
                ? 'Open Connector'
                : 'Connector settings',
          ),
        ] else
          for (final friend in friends)
            _FriendTile(
              friend: friend,
              linkedTo: linkedTo[friend.id],
              linking: linking,
            ),
        if (updatedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'As Connector last shared them, '
            '${DateFormat('d MMM, h:mm a').format(updatedAt)}. Someone '
            'missing? Open Connector to refresh.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (friends.isNotEmpty) ...[
            const SizedBox(height: 8),
            openButton('Open Connector'),
          ],
        ],
      ],
      AsyncData(value: FriendsNotReady(:final message)) => [
        Text(message, style: muted),
        const SizedBox(height: 12),
        openButton(
          PlatformFeatures.connectorFriendsApp
              ? 'Open Connector'
              : 'Connector settings',
        ),
      ],
      AsyncData(value: FriendsHidden()) => [
        Text('Connector isn\'t on this device.', style: muted),
      ],
      AsyncError() => [
        Text(
          "Couldn't load your Connector friends. Check your connection and "
          'try again.',
          style: muted,
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    linking == null
                        ? 'Connector friends'
                        : 'Link ${linking!.name} to…',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const AppIcon(Icons.refresh_rounded),
                  onPressed: () => ref.invalidate(connectorFriendsProvider),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Linking only remembers who they are on Connector, here. '
              'Nothing is sent.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...body,
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.linkedTo,
    required this.linking,
  });

  final ConnectorFriend friend;

  /// The person already linked to [friend], if any.
  final PersonRow? linkedTo;
  final PersonRow? linking;

  @override
  Widget build(BuildContext context) {
    final taken = linkedTo != null && linkedTo!.id != linking?.id;
    final current = linkedTo != null && linkedTo!.id == linking?.id;
    return AppListTile(
      leading: CircleAvatar(
        child: Text(friend.name.characters.first.toUpperCase()),
      ),
      title: Text(friend.name),
      subtitle: Text(
        taken
            ? '@${friend.username} · already ${linkedTo!.name}'
            : current
            ? '@${friend.username} · linked now'
            : '@${friend.username}',
      ),
      enabled: !taken && !current,
      onTap: () => Navigator.of(context).pop(friend),
    );
  }
}
