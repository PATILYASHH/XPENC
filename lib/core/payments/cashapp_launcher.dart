import 'package:url_launcher/url_launcher.dart';

import '../money.dart';

/// Builds and launches `https://cash.app/$cashtag/<amount>` links. Cash App
/// is USD-only, so — like [VenmoLauncher] — there's no currency parameter;
/// the caller passes the *other* person's cashtag for "Pay" and the app's
/// own user's cashtag (`Settings.myCashapp`) for "Request". Beta: real Cash
/// App app/browser behavior can't be fully guaranteed from code alone.
class CashAppLauncher {
  const CashAppLauncher._();

  /// Accepts a cashtag with or without its leading `$`, or a pasted
  /// `cash.app/$tag` URL, and always returns one with the `$` restored.
  static String normalizeCashtag(String raw) {
    var value = raw.trim();
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.replaceFirst(RegExp(r'^(www\.)?cash\.app/'), '');
    final slash = value.indexOf('/');
    if (slash != -1) value = value.substring(0, slash);
    if (!value.startsWith(r'$')) value = '\$$value';
    return value;
  }

  static Uri buildUri({required String cashtag, required Money amount}) {
    final tag = normalizeCashtag(cashtag);
    // A plain, ungrouped decimal string — NOT `MoneyFormat.bare`, which
    // applies locale digit grouping a path segment can't parse.
    final amountStr = amount.rupees.toStringAsFixed(2);
    return Uri.https('cash.app', '/$tag/$amountStr');
  }

  /// Never lets a raw exception surface — callers should copy something
  /// useful to the clipboard on `false`, matching [PaypalLauncher.launch].
  static Future<bool> launch({
    required String cashtag,
    required Money amount,
  }) async {
    final uri = buildUri(cashtag: cashtag, amount: amount);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
