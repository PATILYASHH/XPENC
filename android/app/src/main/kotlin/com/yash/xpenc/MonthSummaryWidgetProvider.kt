package com.yash.xpenc

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen "This Month" widget: this calendar month's income and
 * expense totals, side by side. Tapping it just opens the app — RemoteViews
 * can't host the real Stats charts.
 *
 * Data (`month_income`, `month_expense`) is pushed from Dart via
 * `HomeWidget.saveWidgetData`, already formatted in the user's chosen
 * currency — see `lib/core/home_widget/home_widget_service.dart`.
 */
class MonthSummaryWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.month_summary_widget).apply {
            setTextViewText(
                R.id.widget_month_income,
                widgetData.getString("month_income", null) ?: "--",
            )
            setTextViewText(
                R.id.widget_month_expense,
                widgetData.getString("month_expense", null) ?: "--",
            )

            val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, openApp)
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
