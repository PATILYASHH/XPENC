import 'package:url_launcher/url_launcher.dart';

import '../branding/app_info.dart';
import '../money.dart';

/// A UPI app a Pay/Request button can target. Google Pay and PhonePe only —
/// Samsung Wallet has no confirmed public deep-link scheme, so it's left out
/// rather than shipped broken.
enum UpiApp { googlePay, phonePe }

/// Which side of the UPI intent spec to use. `pay` sends money; `collect`
/// opens the requesting app's own "request money" flow, pre-filled — it
/// cannot itself notify the other person's phone (that needs PSP-level
/// integration no personal app has access to). Both are Beta: real UPI app
/// behavior can't be fully guaranteed from code alone.
enum UpiAction { pay, collect }

/// Builds and launches `upi://pay` / `upi://collect` deep links.
///
/// For [UpiAction.pay], `payeeUpiId`/`payeeName` are the *other* person's
/// VPA/name — money leaves the app's user. For [UpiAction.collect],
/// `payeeUpiId`/`payeeName` must be the app's own user's identity (from
/// `Settings.myUpiId`/`myUpiName`) — a collect intent's payee is whoever is
/// requesting the money, not the person being asked to pay.
class UpiLauncher {
  const UpiLauncher._();

  /// The generic intent every UPI app registers as a handler for — the
  /// universal fallback, and the *only* option for [UpiAction.collect] on
  /// either app (see [buildAppSpecificUri]).
  static Uri buildGenericUri({
    required UpiAction action,
    required String payeeUpiId,
    required String payeeName,
    required Money amount,
    String? note,
  }) {
    return Uri(
      scheme: 'upi',
      host: action == UpiAction.pay ? 'pay' : 'collect',
      queryParameters: _params(payeeUpiId, payeeName, amount, note),
    );
  }

  /// An app-specific scheme, tried before the generic fallback in [launch].
  /// Returns `null` when there's no documented scheme for this
  /// (app, action) pair — callers must fall back to [buildGenericUri]
  /// rather than guess one.
  ///
  /// Only `pay` has a documented app-specific scheme for either app right
  /// now. Neither Google Pay's `tez://` nor PhonePe's `phonepe://` has a
  /// confirmed public scheme for `collect` — this deliberately returns
  /// `null` for that pair rather than a guessed URI. Don't "fix" this
  /// without verifying a real working collect scheme on-device first.
  static Uri? buildAppSpecificUri({
    required UpiApp app,
    required UpiAction action,
    required String payeeUpiId,
    required String payeeName,
    required Money amount,
    String? note,
  }) {
    if (action != UpiAction.pay) return null;
    final params = _params(payeeUpiId, payeeName, amount, note);
    return switch (app) {
      UpiApp.googlePay =>
        Uri(scheme: 'tez', host: 'upi', path: 'pay', queryParameters: params),
      UpiApp.phonePe =>
        Uri(scheme: 'phonepe', host: 'pay', queryParameters: params),
    };
  }

  /// Tries [app]'s own scheme first, then the generic `upi://` intent
  /// (which still lets Android's own chooser handle it, or opens directly if
  /// only one UPI app is installed). Returns `false` only if both fail —
  /// callers should never let a raw exception surface; copy something useful
  /// to the clipboard instead, matching the convention in
  /// `about_screen.dart`'s `_open`.
  static Future<bool> launch({
    required UpiApp app,
    required UpiAction action,
    required String payeeUpiId,
    required String payeeName,
    required Money amount,
    String? note,
  }) async {
    final specific = buildAppSpecificUri(
      app: app,
      action: action,
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );
    if (specific != null) {
      try {
        if (await launchUrl(specific, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // Falls through to the generic intent below.
      }
    }

    final generic = buildGenericUri(
      action: action,
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );
    try {
      return await launchUrl(generic, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// `pn`/`tn` are free text (a person's name, a note) that can contain
  /// spaces or punctuation — `Uri`'s own `queryParameters` constructor
  /// percent-encodes them correctly, so build with that rather than
  /// interpolating a query string by hand.
  static Map<String, String> _params(
    String payeeUpiId,
    String payeeName,
    Money amount,
    String? note,
  ) {
    return {
      'pa': payeeUpiId,
      'pn': payeeName.isEmpty ? AppInfo.name : payeeName,
      // A plain, ungrouped decimal string — NOT `MoneyFormat.bare`, which
      // applies locale digit grouping (e.g. "1,234.00" for INR) that a UPI
      // `am` param can't parse.
      'am': amount.rupees.toStringAsFixed(2),
      'cu': 'INR', // UPI is India-only regardless of the app's own currency.
      if (note != null && note.isNotEmpty) 'tn': note,
    };
  }
}
