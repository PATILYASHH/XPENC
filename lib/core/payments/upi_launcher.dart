import 'package:url_launcher/url_launcher.dart';

import '../branding/app_info.dart';
import '../money.dart';

/// Which side of the UPI intent spec to use. `pay` sends money; `collect`
/// opens the requesting app's own "request money" flow, pre-filled — it
/// cannot itself notify the other person's phone (that needs PSP-level
/// integration no personal app has access to). Both are Beta: real UPI app
/// behavior can't be fully guaranteed from code alone.
enum UpiAction { pay, collect }

/// Builds and launches `upi://pay` / `upi://collect` deep links.
///
/// A single generic `upi://` intent, deliberately — every UPI app registers
/// itself as a handler for it, so Android's own chooser surfaces whatever's
/// actually installed (Google Pay, PhonePe, or anything else) instead of
/// this app guessing at per-app schemes that aren't all equally documented
/// or reliable. One "UPI" button, not one button per app.
///
/// For [UpiAction.pay], `payeeUpiId`/`payeeName` are the *other* person's
/// VPA/name — money leaves the app's user. For [UpiAction.collect],
/// `payeeUpiId`/`payeeName` must be the app's own user's identity (from
/// `Settings.myUpiId`/`myUpiName`) — a collect intent's payee is whoever is
/// requesting the money, not the person being asked to pay.
class UpiLauncher {
  const UpiLauncher._();

  static Uri buildUri({
    required UpiAction action,
    required String payeeUpiId,
    required String payeeName,
    required Money amount,
    String? note,
  }) {
    return Uri(
      scheme: 'upi',
      host: action == UpiAction.pay ? 'pay' : 'collect',
      queryParameters: {
        'pa': payeeUpiId,
        'pn': payeeName.isEmpty ? AppInfo.name : payeeName,
        // A plain, ungrouped decimal string — NOT `MoneyFormat.bare`, which
        // applies locale digit grouping (e.g. "1,234.00" for INR) that a
        // UPI `am` param can't parse.
        'am': amount.rupees.toStringAsFixed(2),
        'cu': 'INR', // UPI is India-only regardless of the app's currency.
        if (note != null && note.isNotEmpty) 'tn': note,
      },
    );
  }

  /// Never lets a raw exception surface — callers should copy something
  /// useful to the clipboard on `false`, matching the convention in
  /// `about_screen.dart`'s `_open`.
  static Future<bool> launch({
    required UpiAction action,
    required String payeeUpiId,
    required String payeeName,
    required Money amount,
    String? note,
  }) async {
    final uri = buildUri(
      action: action,
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
