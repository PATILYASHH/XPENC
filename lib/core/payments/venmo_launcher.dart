import 'package:url_launcher/url_launcher.dart';

import '../money.dart';

/// Builds and launches `https://venmo.com/<username>?txn=pay&amount=...`
/// links. Venmo is US-only, so there's no currency parameter — like
/// [PaypalLauncher], the caller passes the *other* person's username for
/// "Pay" and the app's own user's username (`Settings.myVenmo`) for
/// "Request". Beta: real Venmo app/browser behavior can't be fully
/// guaranteed from code alone.
class VenmoLauncher {
  const VenmoLauncher._();

  /// Accepts a bare username as well as a pasted `venmo.com/<user>` URL,
  /// with or without a leading `@`.
  static String normalizeUsername(String raw) {
    var value = raw.trim();
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.replaceFirst(RegExp(r'^(www\.)?venmo\.com/(u/)?'), '');
    value = value.replaceFirst(RegExp(r'^@'), '');
    final slash = value.indexOf('/');
    if (slash != -1) value = value.substring(0, slash);
    final query = value.indexOf('?');
    if (query != -1) value = value.substring(0, query);
    return value;
  }

  static Uri buildUri({
    required String username,
    required Money amount,
    String? note,
  }) {
    final user = normalizeUsername(username);
    return Uri.https('venmo.com', '/$user', {
      'txn': 'pay',
      // A plain, ungrouped decimal string — NOT `MoneyFormat.bare`, which
      // applies locale digit grouping a query param can't parse.
      'amount': amount.rupees.toStringAsFixed(2),
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Never lets a raw exception surface — callers should copy something
  /// useful to the clipboard on `false`, matching [PaypalLauncher.launch].
  static Future<bool> launch({
    required String username,
    required Money amount,
    String? note,
  }) async {
    final uri = buildUri(username: username, amount: amount, note: note);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
