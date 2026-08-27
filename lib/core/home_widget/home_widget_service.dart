import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../money.dart';
import '../routing/app_router.dart';

/// One line on the Budgets widget: a category name plus its "spent / limit"
/// already formatted in the user's chosen currency — see
/// [HomeWidgetService.updateBudgetSummary].
typedef WidgetBudgetLine = ({String name, Money spent, Money limit});

/// Bridges the app to the Android home-screen widgets — see
/// `android/app/src/main/kotlin/com/yash/xpenc/` for the native side that
/// renders whatever this saves. Four widgets share this one service:
/// Balance (net worth + shortcuts), Budgets (top budgets by usage), Quick
/// Add (just the shortcuts, enlarged), and This Month (income vs expense
/// for the current calendar month) — see GitHub's widget-section request.
///
/// There is no background refresh: like message capture, this app has no
/// background service, so a widget only updates while the app itself is
/// open (on start, and live thereafter — see `app.dart`).
class HomeWidgetService {
  const HomeWidgetService();

  static const _balanceAndroidName = 'BalanceWidgetProvider';
  static const _budgetAndroidName = 'BudgetWidgetProvider';
  static const _quickAddAndroidName = 'QuickAddWidgetProvider';
  static const _monthSummaryAndroidName = 'MonthSummaryWidgetProvider';

  /// How many lines the Budgets widget's static layout has rows for — see
  /// `budget_widget.xml`.
  static const maxBudgetLines = 3;

  Future<void> updateBalance(Money netWorth) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'net_worth',
        MoneyFormat.symbol(netWorth),
      );
      await HomeWidget.updateWidget(androidName: _balanceAndroidName);
    } catch (e) {
      // A widget that fails to refresh must never take the app down with it.
      debugPrint('HomeWidgetService.updateBalance failed: $e');
    }
  }

  /// [lines] should already be capped to [maxBudgetLines] and ordered
  /// most-pressing first — this saves exactly what it's given, formatted,
  /// as JSON the native side reads with no formatting logic of its own
  /// (RemoteViews has no access to the app's currency/locale config).
  Future<void> updateBudgetSummary(List<WidgetBudgetLine> lines) async {
    try {
      final json = jsonEncode([
        for (final line in lines)
          {
            'name': line.name,
            'value':
                '${MoneyFormat.symbol(line.spent)} / '
                '${MoneyFormat.symbol(line.limit)}',
          },
      ]);
      await HomeWidget.saveWidgetData<String>('budget_summary', json);
      await HomeWidget.updateWidget(androidName: _budgetAndroidName);
    } catch (e) {
      debugPrint('HomeWidgetService.updateBudgetSummary failed: $e');
    }
  }

  Future<void> updateMonthSummary(Money income, Money expense) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'month_income',
        MoneyFormat.symbol(income),
      );
      await HomeWidget.saveWidgetData<String>(
        'month_expense',
        MoneyFormat.symbol(expense),
      );
      await HomeWidget.updateWidget(androidName: _monthSummaryAndroidName);
    } catch (e) {
      debugPrint('HomeWidgetService.updateMonthSummary failed: $e');
    }
  }

  /// Prompts the launcher to offer pinning [widget] directly to the home
  /// screen, from inside the app — Settings > Widgets' "Add to home
  /// screen" buttons. Android 8+ and launcher-dependent; callers should
  /// check [canRequestPin] first and hide the button otherwise.
  Future<void> requestPin(HomeScreenWidget widget) async {
    try {
      await HomeWidget.requestPinWidget(androidName: _androidNameOf(widget));
    } catch (e) {
      debugPrint('HomeWidgetService.requestPin failed: $e');
    }
  }

  Future<bool> canRequestPin() async {
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  static String _androidNameOf(HomeScreenWidget widget) => switch (widget) {
    HomeScreenWidget.balance => _balanceAndroidName,
    HomeScreenWidget.budgets => _budgetAndroidName,
    HomeScreenWidget.quickAdd => _quickAddAndroidName,
    HomeScreenWidget.monthSummary => _monthSummaryAndroidName,
  };

  /// Call once at startup. Covers both a cold start launched *from* a
  /// widget and a tap on one while the app is already running.
  void init() {
    HomeWidget.widgetClicked.listen(_handleUri);
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_handleUri)
        .catchError((_) {});
  }

  void _handleUri(Uri? uri) {
    if (uri == null || uri.host != 'add') return;
    // Only `expense`/`income` are ever sent by a widget — anything else
    // falls back to the screen's own default rather than a broken deep link.
    final type = uri.queryParameters['type'];
    appRouter.go(type == null ? '/add' : '/add?type=$type');
  }
}

/// The four preset home-screen widgets — see the doc on [HomeWidgetService].
enum HomeScreenWidget { balance, budgets, quickAdd, monthSummary }
