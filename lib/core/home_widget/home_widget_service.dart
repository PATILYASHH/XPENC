import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../money.dart';
import '../routing/app_router.dart';

/// Bridges the app to the Android home-screen "Balance" widget — see
/// `android/app/src/main/kotlin/com/yash/xpenc/BalanceWidgetProvider.kt` for
/// the native side that renders whatever this saves.
///
/// There is no background refresh: like message capture, this app has no
/// background service, so the widget's balance only updates while the app
/// itself is open (on start, and live thereafter — see `app.dart`).
class HomeWidgetService {
  const HomeWidgetService();

  static const _androidName = 'BalanceWidgetProvider';

  Future<void> updateBalance(Money netWorth) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'net_worth',
        MoneyFormat.symbol(netWorth),
      );
      await HomeWidget.updateWidget(androidName: _androidName);
    } catch (e) {
      // A widget that fails to refresh must never take the app down with it.
      debugPrint('HomeWidgetService.updateBalance failed: $e');
    }
  }

  /// Call once at startup. Covers both a cold start launched *from* the
  /// widget and a tap on it while the app is already running.
  void init() {
    HomeWidget.widgetClicked.listen(_handleUri);
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleUri)
        .catchError((_) {});
  }

  void _handleUri(Uri? uri) {
    if (uri == null || uri.host != 'add') return;
    // Only `expense`/`income` are ever sent by the widget — anything else
    // falls back to the screen's own default rather than a broken deep link.
    final type = uri.queryParameters['type'];
    appRouter.go(type == null ? '/add' : '/add?type=$type');
  }
}
