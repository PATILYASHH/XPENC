import 'dart:convert';

/// Where an entry stands with the friend it's shared with
/// (`PersonEntries.sharedStatus`).
enum SharedStatus {
  /// Made here, waiting for Connector to send it.
  sending,

  /// On the server, waiting for the friend's answer.
  pending,

  /// The friend accepted it — the same on both sides now.
  accepted,

  /// The friend said it's wrong. Fix and send it again, or keep it as
  /// this phone's own.
  rejected,

  /// The server refused it (not friends any more, say). Only here.
  failed,

  /// A friend's entry, accepted here.
  received;

  static SharedStatus? of(String? name) =>
      name == null ? null : values.asNameMap()[name];

  /// Amount, date, direction and note are agreed by both sides — changed
  /// only by a correcting entry.
  bool get locked => this == accepted || this == received;
}

/// One shared entry, as Connector sees it from this account's side
/// (`CONECTR/lib/core/shared/shared_entry.dart`, `toWire`).
class RemoteEntry {
  const RemoteEntry({
    required this.id,
    required this.friendId,
    required this.byMe,
    this.clientRef,
    required this.theyOwe,
    required this.amountMinor,
    required this.currency,
    required this.date,
    this.dueDate,
    this.note,
    this.isOpening = false,
    required this.status,
    required this.version,
  });

  factory RemoteEntry.fromJson(Map<String, dynamic> json) => RemoteEntry(
    id: json['id'] as String,
    friendId: json['friendId'] as String,
    byMe: json['byMe'] as bool,
    clientRef: json['clientRef'] as String?,
    theyOwe: json['theyOwe'] as bool,
    amountMinor: (json['amountMinor'] as num).toInt(),
    currency: json['currency'] as String,
    date: DateTime.parse(json['date'] as String),
    dueDate: json['dueDate'] == null
        ? null
        : DateTime.parse(json['dueDate'] as String),
    note: json['note'] as String?,
    isOpening: json['isOpening'] as bool? ?? false,
    status: json['status'] as String,
    version: (json['version'] as num).toInt(),
  );

  final String id;

  /// The other person's Connector id — `Persons.remoteFriendId`.
  final String friendId;

  /// Made by this account (on this phone, or another of its phones).
  final bool byMe;

  /// The maker's own id for it; set only when [byMe].
  final String? clientRef;

  /// From this side: the friend owes.
  final bool theyOwe;
  final int amountMinor;
  final String currency;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final bool isOpening;

  /// `pending`, `accepted` or `rejected`.
  final String status;
  final int version;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}

/// An op Connector couldn't send, and why — `not_friends`, `entry_locked`,
/// `entry_changed`, `entry_not_found`, `signed_out`, …
class FailedOp {
  const FailedOp({
    required this.type,
    this.clientRef,
    this.entryId,
    required this.error,
  });

  factory FailedOp.fromJson(Map<String, dynamic> json) => FailedOp(
    type: json['type'] as String? ?? '',
    clientRef: json['clientRef'] as String?,
    entryId: json['entryId'] as String?,
    error: json['error'] as String? ?? 'refused',
  );

  final String type;
  final String? clientRef;
  final String? entryId;
  final String error;
}

/// Everything Connector shares about entries with friends: its last
/// snapshot (`xpenc/shared.json`) and what's still queued to go out.
class SharedSnapshot {
  const SharedSnapshot({
    required this.signedIn,
    this.me,
    this.entries = const [],
    this.failed = const [],
    this.queued = const [],
  });

  /// Connector isn't there, or hasn't synced yet.
  static const none = SharedSnapshot(signedIn: false);

  /// [json]: the snapshot, null when there's none yet. [outbox]: the ops
  /// still queued, as a JSON array.
  factory SharedSnapshot.parse(String? json, String? outbox) {
    final queued = <Map<String, dynamic>>[];
    if (outbox != null) {
      final raw = jsonDecode(outbox);
      if (raw is List) {
        for (final op in raw) {
          if (op is Map<String, dynamic>) queued.add(op);
        }
      }
    }
    if (json == null) return SharedSnapshot(signedIn: false, queued: queued);
    final map = jsonDecode(json) as Map<String, dynamic>;
    if (map['version'] != 1) {
      return SharedSnapshot(signedIn: false, queued: queued);
    }
    return SharedSnapshot(
      signedIn: map['signedIn'] == true,
      me: map['me'] as String?,
      entries: [
        for (final e in (map['entries'] as List<dynamic>? ?? const []))
          RemoteEntry.fromJson(e as Map<String, dynamic>),
      ],
      failed: [
        for (final f in (map['failed'] as List<dynamic>? ?? const []))
          FailedOp.fromJson(f as Map<String, dynamic>),
      ],
      queued: queued,
    );
  }

  final bool signedIn;

  /// This phone's Connector account id.
  final String? me;
  final List<RemoteEntry> entries;
  final List<FailedOp> failed;

  /// Ops XPENC sent that Connector hasn't delivered yet.
  final List<Map<String, dynamic>> queued;

  bool get ready => signedIn && me != null;

  /// A friend's entries waiting for this phone's answer.
  List<RemoteEntry> waitingFor(String friendId) => [
    for (final e in entries)
      if (!e.byMe && e.isPending && e.friendId == friendId) e,
  ];

  /// Every friend's entries waiting for an answer, by friend.
  Map<String, List<RemoteEntry>> get waiting {
    final out = <String, List<RemoteEntry>>{};
    for (final e in entries) {
      if (!e.byMe && e.isPending) out.putIfAbsent(e.friendId, () => []).add(e);
    }
    return out;
  }

  /// This account's opening-balance entries with [friendId], newest last.
  List<RemoteEntry> openingsWith(String friendId) => [
    for (final e in entries)
      if (e.byMe && e.isOpening && e.friendId == friendId) e,
  ];

  /// An answer to [entryId] is still on its way.
  bool answering(String entryId) =>
      queued.any((op) => op['type'] == 'respond' && op['entryId'] == entryId);

  bool queuedFor(String clientRef) =>
      queued.any((op) => op['clientRef'] == clientRef);
}
