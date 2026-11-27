import 'package:flutter/services.dart';

import '../../core/permissions/app_permissions.dart';
import '../../core/platform/platform_features.dart';
import '../../data/tables.dart';
import 'message_source.dart';
import 'parser/bank_message.dart';

/// Someone who has texted this phone (never a phone number — only senders
/// like `JD-HDFCBK-S`), for Auto money tracking's "Found in your messages".
class InboxSender {
  const InboxSender({
    required this.sender,
    required this.count,
    required this.last,
    this.samples = const [],
  });

  final String sender;
  final int count;
  final DateTime last;

  /// Their newest few texts — checked for payments, never kept.
  final List<String> samples;
}

/// The phone's SMS inbox, read-only (`SmsChannel.kt`). Only in Android builds
/// whose manifest declares READ_SMS — see android/app/build.gradle.kts.
abstract interface class SmsInbox {
  /// Whether this build may read SMS at all.
  Future<bool> declared();

  Future<PermissionState> permission();

  /// Shows Android's SMS dialog; the state afterwards.
  Future<PermissionState> requestPermission();

  /// Messages after [since] from senders containing one of [senders]
  /// (sender codes, `HDFCBK`) — oldest first, or [newestFirst].
  Future<List<RawMessage>> messages({
    required DateTime since,
    required List<String> senders,
    int limit = 500,
    bool newestFirst = false,
  });

  /// Who has written since [since], busiest first.
  Future<List<InboxSender>> senders({required DateTime since});
}

/// [SmsInbox] over the `xpenc/sms` channel.
class ChannelSmsInbox implements SmsInbox {
  const ChannelSmsInbox();

  static const _channel = MethodChannel('xpenc/sms');

  @override
  Future<bool> declared() async {
    if (!PlatformFeatures.smsCapture) return false;
    try {
      return await _channel.invokeMethod<bool>('declared') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<PermissionState> permission() =>
      AppPermissions.status(AppPermission.sms);

  @override
  Future<PermissionState> requestPermission() =>
      AppPermissions.request(AppPermission.sms);

  @override
  Future<List<RawMessage>> messages({
    required DateTime since,
    required List<String> senders,
    int limit = 500,
    bool newestFirst = false,
  }) async {
    if (senders.isEmpty) return const [];
    final rows = await _list('messages', {
      'since': since.millisecondsSinceEpoch,
      'senders': senders,
      'limit': limit,
      'newestFirst': newestFirst,
    });
    return [
      for (final r in rows)
        RawMessage(
          body: r['body'] as String,
          sender: r['sender'] as String,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(
            (r['date'] as num).toInt(),
          ),
          source: MessageSourceKind.sms,
        ),
    ];
  }

  @override
  Future<List<InboxSender>> senders({required DateTime since}) async {
    final rows = await _list('senders', {
      'since': since.millisecondsSinceEpoch,
      'samples': 3,
    });
    return [
      for (final r in rows)
        InboxSender(
          sender: r['sender'] as String,
          count: (r['count'] as num).toInt(),
          last: DateTime.fromMillisecondsSinceEpoch((r['last'] as num).toInt()),
          samples: [
            for (final s in (r['samples'] as List? ?? const [])) s as String,
          ],
        ),
    ];
  }

  /// Empty — never a throw — when there's no Android host, no permission
  /// or the read fails: a scan that finds nothing just tries again later.
  Future<List<Map<Object?, Object?>>> _list(
    String method,
    Map<String, Object> args,
  ) async {
    try {
      final raw = await _channel.invokeListMethod<Object?>(method, args);
      return [
        for (final r in raw ?? const <Object?>[])
          if (r is Map) r,
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }
}

/// Capture's [MessageSource] over the SMS inbox.
class SmsMessageSource implements MessageSource {
  const SmsMessageSource(this.inbox);

  final SmsInbox inbox;

  @override
  Future<bool> isSupported() => inbox.declared();

  @override
  Future<bool> hasPermission() async =>
      await inbox.permission() == PermissionState.granted;

  @override
  Future<bool> requestPermission() async =>
      await inbox.requestPermission() == PermissionState.granted;

  @override
  Future<List<RawMessage>> messagesSince(
    DateTime since, {
    List<String> senders = const [],
  }) => inbox.messages(since: since, senders: senders);
}
