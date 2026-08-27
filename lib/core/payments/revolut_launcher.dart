import 'package:url_launcher/url_launcher.dart';

import '../money.dart';

/// Builds and launches `https://revolut.me/<username>/<amount>` links —
/// same shape as [PaypalLauncher] but without a currency suffix (a
/// Revolut.me link is priced in the link owner's own account currency).
/// The caller passes the *other* person's username for "Pay" and the app's
/// own user's username (`Settings.myRevolut`) for "Request". Beta: real
/// Revolut app/browser behavior can't be fully guaranteed from code alone.
class RevolutLauncher {
  const RevolutLauncher._();

  /// Accepts a bare username as well as a pasted `revolut.me/<user>` URL.
  static String normalizeUsername(String raw) {
    var value = raw.trim();
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.replaceFirst(RegExp(r'^(www\.)?revolut\.me/'), '');
    final slash = value.indexOf('/');
    if (slash != -1) value = value.substring(0, slash);
    return value;
  }

  static Uri buildUri({required String username, required Money amount}) {
    final user = normalizeUsername(username);
    // A plain, ungrouped decimal string — NOT `MoneyFormat.bare`, which
    // applies locale digit grouping a path segment can't parse.
    final amountStr = amount.rupees.toStringAsFixed(2);
    return Uri.https('revolut.me', '/$user/$amountStr');
  }

  /// Never lets a raw exception surface — callers should copy something
  /// useful to the clipboard on `false`, matching [PaypalLauncher.launch].
  static Future<bool> launch({
    required String username,
    required Money amount,
  }) async {
    final uri = buildUri(username: username, amount: amount);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
