// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

package xyz.journai.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class EmergencyCardWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val bitmap = widgetData.getString("emergency_card", null)?.let { BitmapFactory.decodeFile(it) }

        for (appWidgetId in appWidgetIds) {
            saveSize(widgetData, appWidgetManager.getAppWidgetOptions(appWidgetId))

            val views = RemoteViews(context.packageName, R.layout.emergency_card_widget)

            if (bitmap != null) {
                views.setImageViewBitmap(R.id.emergency_card_image, bitmap)
                views.setViewVisibility(R.id.emergency_card_image, View.VISIBLE)
                views.setViewVisibility(R.id.emergency_card_placeholder, View.GONE)
            } else {
                views.setViewVisibility(R.id.emergency_card_image, View.GONE)
                views.setViewVisibility(R.id.emergency_card_placeholder, View.VISIBLE)
            }

            views.setOnClickPendingIntent(
                R.id.emergency_card_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("journai://emergency-card")),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)

        saveSize(HomeWidgetPlugin.getData(context), newOptions)
    }

    private fun saveSize(widgetData: SharedPreferences, options: Bundle) {
        val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)

        if (width == 0 || height == 0) {
            return
        }

        widgetData.edit().putInt("emergency_card_width", width).putInt("emergency_card_height", height).apply()
    }
}
