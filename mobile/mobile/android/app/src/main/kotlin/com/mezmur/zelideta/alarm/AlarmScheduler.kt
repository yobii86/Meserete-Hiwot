package com.mezmur.zelideta.alarm

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import org.json.JSONObject

/**
 * Handles scheduling, cancellation, and persistence of real native alarms via AlarmManager.
 * Alarms survive device reboots, time-zone shifts, and application updates.
 */
object AlarmScheduler {

    private const val PREFS_NAME = "mz_alarm_registry"

    fun canScheduleExactAlarms(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            am?.canScheduleExactAlarms() ?: true
        } else {
            true
        }
    }

    fun canUseFullScreenIntent(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14 (API 34)
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.canUseFullScreenIntent() ?: true
        } else {
            true
        }
    }

    fun schedule(
        context: Context,
        alarmId: Int,
        timestampMs: Long,
        programId: Int,
        title: String,
        body: String,
        payload: String
    ): Boolean {
        if (timestampMs <= System.currentTimeMillis()) return false

        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return false

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_TRIGGER_ALARM
            putExtra("alarm_id", alarmId)
            putExtra("program_id", programId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("payload", payload)
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(context, alarmId, intent, flags)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestampMs, pendingIntent)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, timestampMs, pendingIntent)
        }

        saveAlarm(context, alarmId, timestampMs, programId, title, body, payload)
        return true
    }

    fun cancel(context: Context, alarmId: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_TRIGGER_ALARM
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getBroadcast(context, alarmId, intent, flags)
        am?.cancel(pendingIntent)
        pendingIntent.cancel()

        removeAlarm(context, alarmId)
    }

    fun cancelAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val all = prefs.all
        for ((key, _) in all) {
            val id = key.toIntOrNull() ?: continue
            cancel(context, id)
        }
        prefs.edit().clear().apply()
    }

    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val all = prefs.all

        for ((key, value) in all) {
            val id = key.toIntOrNull() ?: continue
            val jsonStr = value as? String ?: continue
            try {
                val obj = JSONObject(jsonStr)
                val time = obj.optLong("time", 0L)
                if (time > now) {
                    val programId = obj.optInt("program_id", 0)
                    val title = obj.optString("title", "መርሐ ግብር")
                    val body = obj.optString("body", "")
                    val payload = obj.optString("payload", "alarm:$programId")
                    schedule(context, id, time, programId, title, body, payload)
                } else {
                    prefs.edit().remove(key).apply()
                }
            } catch (e: Exception) {}
        }
    }

    private fun saveAlarm(
        context: Context,
        alarmId: Int,
        timestampMs: Long,
        programId: Int,
        title: String,
        body: String,
        payload: String
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val obj = JSONObject().apply {
            put("id", alarmId)
            put("time", timestampMs)
            put("program_id", programId)
            put("title", title)
            put("body", body)
            put("payload", payload)
        }
        prefs.edit().putString(alarmId.toString(), obj.toString()).apply()
    }

    private fun removeAlarm(context: Context, alarmId: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(alarmId.toString()).apply()
    }

    fun getAllScheduled(context: Context): List<Map<String, Any>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val list = mutableListOf<Map<String, Any>>()
        val now = System.currentTimeMillis()

        for ((_, value) in prefs.all) {
            val jsonStr = value as? String ?: continue
            try {
                val obj = JSONObject(jsonStr)
                val time = obj.optLong("time", 0L)
                if (time > now) {
                    list.add(
                        mapOf(
                            "id" to obj.optInt("id"),
                            "time" to time,
                            "program_id" to obj.optInt("program_id"),
                            "title" to obj.optString("title"),
                            "body" to obj.optString("body"),
                            "payload" to obj.optString("payload")
                        )
                    )
                }
            } catch (e: Exception) {}
        }
        return list
    }
}

