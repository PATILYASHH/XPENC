import 'package:flutter/foundation.dart';

import 'outgoing_file_io.dart'
    if (dart.library.js_interop) 'outgoing_file_web.dart'
    as impl;

/// What a [ShareTarget] is to the share screen: WhatsApp and the messages
/// app wear their own marks and open the recipient's chat; any other app
/// wears its own icon.
enum ShareTargetKind { whatsapp, messages, app }

/// One app a share can go to straight, skipping the share sheet — one
/// entry of the phone's share sheet (Android only): WhatsApp's chat
/// picker, Gmail, Drive's "Save to Drive".
@immutable
class ShareTarget {
  const ShareTarget({
    required this.id,
    required this.label,
    this.appLabel,
    this.kind = ShareTargetKind.app,
    this.takesImage = true,
    this.takesPdf = true,
  });

  /// `package/activity`.
  final String id;
  final String label;

  /// The app's name, where the entry has one of its own ("Save to Drive").
  final String? appLabel;
  final ShareTargetKind kind;
  final bool takesImage;
  final bool takesPdf;

  bool takes(String mimeType) =>
      mimeType == 'application/pdf' ? takesPdf : takesImage;

  /// Takes it, or — the messages app — sends the text when it can't.
  bool canSend(String mimeType) =>
      kind == ShareTargetKind.messages || takes(mimeType);

  @override
  bool operator ==(Object other) => other is ShareTarget && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The phone's share targets, and the ones on the share screen's row.
@immutable
class ShareTargets {
  const ShareTargets({
    required this.all,
    required this.pinnedIds,
    this.customized = false,
  });

  static const none = ShareTargets(all: [], pinnedIds: []);

  /// How many fit on the row beside More.
  static const maxPinned = 4;

  final List<ShareTarget> all;

  /// In row order. Until [customized], WhatsApp and the messages app.
  final List<String> pinnedIds;
  final bool customized;

  /// The pinned ones still installed, in order.
  List<ShareTarget> get pinned {
    final byId = {for (final t in all) t.id: t};
    return [for (final id in pinnedIds) ?byId[id]];
  }

  /// Everything not on the row.
  List<ShareTarget> get unpinned {
    final ids = pinnedIds.toSet();
    return [
      for (final t in all)
        if (!ids.contains(t.id)) t,
    ];
  }

  ShareTargets withPinned(List<String> ids) =>
      ShareTargets(all: all, pinnedIds: ids, customized: true);
}

/// A share target's icon. [adaptive]: drawn full-bleed, to be masked round;
/// otherwise the app's own shape on a transparent square.
class ShareTargetIcon {
  const ShareTargetIcon(this.png, {required this.adaptive});

  final Uint8List png;
  final bool adaptive;
}

/// How [OutgoingFile.sendTo] went. [textOnly]: the messages app wouldn't
/// take the file, so only the message text went.
enum ShareAppResult { sent, textOnly, failed }

/// A file XPENC made for the user to take away — an export, a statement, a
/// share card, a backup. On a phone it goes to the system share sheet, so
/// it leaves only when the user picks where; XPENC web downloads it.
class OutgoingFile {
  const OutgoingFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  /// Stands in for the share sheet / download — for tests, which have
  /// neither.
  @visibleForTesting
  static Future<void> Function(OutgoingFile file, String subject)? debugDeliver;

  /// For tests: the phone's share targets ([pinShareTargets] edits them in
  /// place; a reset goes back to the ones set here), and a stand-in for
  /// handing a file to one.
  @visibleForTesting
  static ShareTargets? get debugTargets => _debugTargets;
  @visibleForTesting
  static set debugTargets(ShareTargets? targets) {
    _debugTargets = targets;
    _debugDefaults = targets;
  }

  static ShareTargets? _debugTargets;
  static ShareTargets? _debugDefaults;

  @visibleForTesting
  static Future<ShareAppResult> Function(
    OutgoingFile file,
    ShareTarget target,
    String? text,
  )?
  debugSendTo;

  /// [subject] names it for share targets that ask (email, mostly); [text]
  /// goes with it as the message, where the target takes one.
  Future<void> deliver({required String subject, String? text}) =>
      debugDeliver?.call(this, subject) ??
      impl.deliver(this, subject: subject, text: text);

  /// Whether this device can send to an app straight — Android. Elsewhere
  /// the system share sheet (or a download) is the only way.
  static bool get canShareToApps =>
      _debugTargets != null || impl.canShareToApps;

  /// The apps that take a shared file, and the ones on the share screen.
  static Future<ShareTargets> shareTargets() =>
      _debugTargets != null ? Future.value(_debugTargets) : impl.shareTargets();

  /// Keeps [ids] on the share screen, in order, on this phone; null goes
  /// back to WhatsApp and the messages app.
  static Future<void> pinShareTargets(List<String>? ids) async {
    final debug = _debugTargets;
    if (debug != null) {
      _debugTargets = ids == null ? _debugDefaults : debug.withPinned(ids);
      return;
    }
    await impl.pinShareTargets(ids);
  }

  static final _icons = <String, Future<ShareTargetIcon?>>{};

  /// [id]'s icon, [size] px square — fetched once per run.
  static Future<ShareTargetIcon?> shareTargetIcon(String id, {int size = 192}) {
    if (_debugTargets != null) return Future.value();
    return _icons.putIfAbsent(
      '$id@$size',
      () => impl.shareTargetIcon(id, size),
    );
  }

  /// Straight into [target], with [text] as the message: into the chat of
  /// [whatsappJid] (international digits, no `+`) on WhatsApp, addressed to
  /// [phone] in the messages app. The user still taps Send there.
  Future<ShareAppResult> sendTo(
    ShareTarget target, {
    String? text,
    String? whatsappJid,
    String? phone,
  }) =>
      debugSendTo?.call(this, target, text) ??
      impl.sendTo(
        this,
        target,
        text: text,
        whatsappJid: whatsappJid,
        phone: phone,
      );
}
