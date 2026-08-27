package com.all.bibz

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object AdhanAlarmScheduler {
    private const val PREFS = "quranx_adhan_audio"
    private const val SAVED_ALARMS = "saved_alarms"

    fun schedule(context: Context, alarms: List<Map<String, Any?>>) {
        cancel(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val json = JSONArray()
        alarms.forEach { alarm ->
            val id = (alarm["id"] as Number).toInt()
            val triggerAtMillis = (alarm["triggerAtMillis"] as Number).toLong()
            val title = alarm["title"] as String
            val body = alarm["body"] as String
            val payload = alarm["payload"] as String
            val item = JSONObject()
                .put("id", id)
                .put("triggerAtMillis", triggerAtMillis)
                .put("title", title)
                .put("body", body)
                .put("payload", payload)
            json.put(item)
            scheduleOne(context, alarmManager, id, triggerAtMillis, title, body, payload)
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(SAVED_ALARMS, json.toString())
            .apply()
    }

    fun rescheduleSaved(context: Context) {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(SAVED_ALARMS, null) ?: return
        val saved = JSONArray(raw)
        val alarms = mutableListOf<Map<String, Any?>>()
        for (index in 0 until saved.length()) {
            val item = saved.getJSONObject(index)
            val triggerAtMillis = item.getLong("triggerAtMillis")
            if (triggerAtMillis > System.currentTimeMillis()) {
                alarms += mapOf(
                    "id" to item.getInt("id"),
                    "triggerAtMillis" to triggerAtMillis,
                    "title" to item.getString("title"),
                    "body" to item.getString("body"),
                    "payload" to item.getString("payload"),
                )
            }
        }
        schedule(context, alarms)
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = preferences.getString(SAVED_ALARMS, null)
        if (raw != null) {
            val saved = JSONArray(raw)
            for (index in 0 until saved.length()) {
                val id = saved.getJSONObject(index).getInt("id")
                alarmManager.cancel(pendingIntent(context, id))
            }
        }
        preferences.edit().remove(SAVED_ALARMS).apply()
    }

    private fun scheduleOne(
        context: Context,
        alarmManager: AlarmManager,
        id: Int,
        triggerAtMillis: Long,
        title: String,
        body: String,
        payload: String,
    ) {
        if (triggerAtMillis <= System.currentTimeMillis()) return
        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
            putExtra("payload", payload)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun pendingIntent(context: Context, id: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, AdhanAlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}
