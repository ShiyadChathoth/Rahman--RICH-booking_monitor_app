package com.example.pi_monitor_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PiMonitorWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, pendingIntentFlags)

            val views = RemoteViews(context.packageName, R.layout.pi_monitor_widget).apply {
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                // Get server status
                val isOnline = widgetData.getBoolean("server_is_online", false)

                if (isOnline) {
                    setImageViewResource(R.id.iv_status_dot, R.drawable.status_dot_online)
                } else {
                    setImageViewResource(R.id.iv_status_dot, R.drawable.status_dot_offline)
                }

                // Get the rest of the data
                val cpuTemp = widgetData.getString("cpu_temp", "-- °C")
                val cpuTempRaw = widgetData.getString("cpu_temp_raw", "0.0")?.toFloat() ?: 0.0f
                val cpuText = widgetData.getString("cpu_text", "--%")
                val cpuPercent = widgetData.getInt("cpu_percent", 0)

                val ramText = widgetData.getString("ram_text", "-- GB / -- GB (--%)")
                val ramPercent = widgetData.getInt("ram_percent", 0)

                val diskText = widgetData.getString("disk_text", "-- GB / -- GB (--%)")
                val diskPercent = widgetData.getInt("disk_percent", 0)

                // Update all the views
                setTextViewText(R.id.tv_cpu_temp, "Temp: $cpuTemp")

                // Set text color based on temperature
                val tempColor = when {
                    cpuTempRaw >= 80.0 -> Color.RED
                    cpuTempRaw >= 60.0 -> Color.YELLOW
                    else -> Color.GREEN
                }
                setTextColor(R.id.tv_cpu_temp, tempColor)

                setTextViewText(R.id.tv_cpu_text, cpuText)
                setProgressBar(R.id.pb_cpu_usage, 100, cpuPercent, false)
                setProgressBar(R.id.pb_cpu_usage_orange, 100, cpuPercent, false)
                if (cpuPercent >= 50) {
                    setViewVisibility(R.id.pb_cpu_usage, View.GONE)
                    setViewVisibility(R.id.pb_cpu_usage_orange, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.pb_cpu_usage, View.VISIBLE)
                    setViewVisibility(R.id.pb_cpu_usage_orange, View.GONE)
                }

                setTextViewText(R.id.tv_ram_text, ramText)
                setProgressBar(R.id.pb_ram_usage, 100, ramPercent, false)
                setProgressBar(R.id.pb_ram_usage_orange, 100, ramPercent, false)
                if (ramPercent >= 50) {
                    setViewVisibility(R.id.pb_ram_usage, View.GONE)
                    setViewVisibility(R.id.pb_ram_usage_orange, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.pb_ram_usage, View.VISIBLE)
                    setViewVisibility(R.id.pb_ram_usage_orange, View.GONE)
                }

                setTextViewText(R.id.tv_disk_text, diskText)
                setProgressBar(R.id.pb_disk_usage, 100, diskPercent, false)
                setProgressBar(R.id.pb_disk_usage_orange, 100, diskPercent, false)
                if (diskPercent >= 50) {
                    setViewVisibility(R.id.pb_disk_usage, View.GONE)
                    setViewVisibility(R.id.pb_disk_usage_orange, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.pb_disk_usage, View.VISIBLE)
                    setViewVisibility(R.id.pb_disk_usage_orange, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}