import 'package:url_launcher/url_launcher.dart';

import '../money.dart';

/// Builds and launches `https://paypal.me/<id>/<amount><currency>` links.
///
/// A PayPal.me link is a payment request by nature — opening one with an
/// amount pre-filled shows a "Pay X to this person" page — so, unlike
/// [UpiLauncher], there's no separate pay/collect intent to pick between.
/// For "Pay" the caller passes the *other* person's PayPal.me id; for
/// "Request" it passes the app's own user's id (`Settings.myPaypal`), so the
/// resulting link is a request to be paid once opened or shared. Opening it
/// locally can't itself notify the other person — same caveat as UPI's
/// collect intent. Beta: real PayPal app/browser behavior can't be fully
/// guaranteed from code alone.
class PaypalLauncher {
  const PaypalLauncher._();

  /// Accepts a bare PayPal.me id as well as a full URL someone might paste
  /// in (`paypal.me/name`, `https://paypal.me/name/`) — strips whatever
  /// wrapping so only the id reaches the built link.
  static String normalizeId(String raw) {
    var value = raw.trim();
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.replaceFirst(RegExp(r'^(www\.)?paypal\.me/'), '');
    final slash = value.indexOf('/');
    if (slash != -1) value = value.substring(0, slash);
    return value;
  }

  static Uri buildUri({
    required String paypalId,
    required Money amount,
    required String currencyCode,
  }) {
    final id = normalizeId(paypalId);
    // A plain, ungrouped decimal string — NOT `MoneyFormat.bare`, which
    // applies locale digit grouping that a paypal.me path segment can't
    // parse.
    final amountStr = amount.rupees.toStringAsFixed(2);
    return Uri.https('paypal.me', '/$id/$amountStr$currencyCode');
  }

  /// Never lets a raw exception surface — callers should copy something
  /// useful to the clipboard on `false`, matching [UpiLauncher.launch].
  static Future<bool> launch({
    required String paypalId,
    required Money amount,
    required String currencyCode,
  }) async {
    final uri = buildUri(
      paypalId: paypalId,
      amount: amount,
      currencyCode: currencyCode,
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
