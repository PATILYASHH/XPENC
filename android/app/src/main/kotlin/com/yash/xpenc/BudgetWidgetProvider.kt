package com.yash.xpenc

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * The home-screen "Budgets" widget: up to three budgets, closest to (or
 * past) their limit first — the same lines and order Stats/Budgets show,
 * just the top of the list.
 *
 * Data (`budget_summary`, a JSON array of `{name, value}` pairs, already
 * formatted in the user's chosen currency) is pushed from Dart via
 * `HomeWidget.saveWidgetData` — see
 * `lib/core/home_widget/home_widget_service.dart`. Money is formatted in
 * Dart, not here: RemoteViews has no access to the app's currency/locale
 * config, and duplicating that logic in Kotlin would drift from it.
 */
class BudgetWidgetProvider : HomeWidgetProvider() {

  companion object {
    private val ROW_IDS =
        listOf(
            Triple(R.id.widget_budget_row_1, R.id.widget_budget_name_1, R.id.widget_budget_value_1),
            Triple(R.id.widget_budget_row_2, R.id.widget_budget_name_2, R.id.widget_budget_value_2),
            Triple(R.id.widget_budget_row_3, R.id.widget_budget_name_3, R.id.widget_budget_value_3),
        )
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val raw = widgetData.getString("budget_summary", null)
    val lines = parseLines(raw)

    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.budget_widget).apply {
            val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_root, openApp)

            setViewVisibility(
                R.id.widget_budget_empty,
                if (lines.isEmpty()) View.VISIBLE else View.GONE,
            )

            ROW_IDS.forEachIndexed { index, (rowId, nameId, valueId) ->
              val line = lines.getOrNull(index)
              if (line == null) {
                setViewVisibility(rowId, View.GONE)
              } else {
                setViewVisibility(rowId, View.VISIBLE)
                setTextViewText(nameId, line.first)
                setTextViewText(valueId, line.second)
              }
            }
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  /** `[{"name": "...", "value": "..."}, ...]` — anything malformed yields no rows. */
  private fun parseLines(raw: String?): List<Pair<String, String>> {
    if (raw.isNullOrEmpty()) return emptyList()
    return try {
      val array = JSONArray(raw)
      (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        val name = obj.optString("name", null) ?: return@mapNotNull null
        val value = obj.optString("value", null) ?: return@mapNotNull null
        name to value
      }
    } catch (e: Exception) {
      emptyList()
    }
  }
}
