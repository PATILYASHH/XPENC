/// Someone the user is friends with on Connector — what a person in XPENC
/// can be linked to (`Persons.remoteFriendId`, `Persons.remoteUsername`).
class ConnectorFriend {
  const ConnectorFriend({
    required this.id,
    required this.username,
    this.displayName,
  });

  /// Wire shape shared with the Connector app's friends cache
  /// (`CONECTR/lib/features/friends/friends_cache.dart`) and Supabase's
  /// `profiles` rows.
  factory ConnectorFriend.fromJson(Map<String, dynamic> json) =>
      ConnectorFriend(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String?,
      );

  /// Their Connector user id — stable across unfriending and re-friending,
  /// unlike the friendship row's.
  final String id;
  final String username;
  final String? displayName;

  /// What a new person made from them is called.
  String get name {
    final display = displayName?.trim();
    return display == null || display.isEmpty ? username : display;
  }
}

/// What reading Connector friends found.
sealed class FriendsLookup {
  const FriendsLookup();
}

/// No Connector here (not installed, or iOS) — friend features stay hidden.
final class FriendsHidden extends FriendsLookup {
  const FriendsHidden();
}

/// Connector is here but can't list friends yet: signed out, no username,
/// web not connected. [message] says what to do.
final class FriendsNotReady extends FriendsLookup {
  const FriendsNotReady(this.message);
  final String message;
}

final class FriendsLoaded extends FriendsLookup {
  const FriendsLoaded({
    required this.myUsername,
    required this.friends,
    this.updatedAt,
  });

  final String myUsername;

  /// Sorted by username.
  final List<ConnectorFriend> friends;

  /// When the Connector app last refreshed the list it shares. Null when it
  /// was read live (XPENC web).
  final DateTime? updatedAt;
}
