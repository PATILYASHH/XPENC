package com.yash.xpenc

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen "Quick Add" widget: nothing but the "+ Expense" / "+
 * Income" shortcuts, for anyone who wants a dedicated one-tap-to-log tile
 * without the Balance widget's balance line taking up space. No widget
 * data of its own — both taps just deep-link into Add Transaction with the
 * type preselected, identically to `BalanceWidgetProvider`.
 */
class QuickAddWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
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
