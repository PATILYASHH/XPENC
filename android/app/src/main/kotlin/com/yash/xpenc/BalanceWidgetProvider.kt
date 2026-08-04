package com.yash.xpenc

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen "Balance" widget: total net worth plus two one-tap
 * shortcuts that jump straight into Add Transaction with the type already
 * chosen — the "smart" part is skipping the type-picker step, not any
 * inline entry inside the widget itself (RemoteViews can't host the app's
 * real amount keypad).
 *
 * Data (`net_worth`) is pushed from Dart via `HomeWidget.saveWidgetData` —
 * see `lib/core/home_widget/home_widget_service.dart`. There is no
 * background refresh: like message capture, this app has no background
 * service, so the widget only updates while the app itself is open.
 */
class BalanceWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.balance_widget).apply {
            setTextViewText(
                R.id.widget_balance,
                widgetData.getString("net_worth", null) ?: "--",
            )

            // Tapping the balance area (or the rest of the tile) just opens
            // the app where it already was.
            val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, openApp)

            val addExpense =
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("homewidget://add?type=expense"),
                )
            setOnClickPendingIntent(R.id.widget_add_expense, addExpense)

            val addIncome =
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("homewidget://add?type=income"),
                )
            setOnClickPendingIntent(R.id.widget_add_income, addIncome)
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
