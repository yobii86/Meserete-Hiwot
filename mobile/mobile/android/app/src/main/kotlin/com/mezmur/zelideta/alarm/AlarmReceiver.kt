package com.mezmur.zelideta.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_TRIGGER_ALARM = "com.mezmur.zelideta.ACTION_TRIGGER_ALARM"
        const val ACTION_STOP_ALARM = "com.mezmur.zelideta.ACTION_STOP_ALARM"
        const val ACTION_SNOOZE_ALARM = "com.mezmur.zelideta.ACTION_SNOOZE_ALARM"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return

        when (action) {
            ACTION_TRIGGER_ALARM -> {
                val serviceIntent = Intent(context, AlarmService::class.java).apply {
                    putExtras(intent)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }

            ACTION_STOP_ALARM -> {
                AlarmService.stop(context)
            }

            ACTION_SNOOZE_ALARM -> {
                val alarmId = intent.getIntExtra("alarm_id", 0)
                val payload = intent.getStringExtra("payload") ?: "alarm:0"
                val title = intent.getStringExtra("title") ?: "የመርሐ ግብር ማንቂያ"
                val body = intent.getStringExtra("body") ?: ""
                AlarmService.snooze(context, alarmId, payload, title, body)
            }

            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                AlarmScheduler.rescheduleAll(context)
            }
        }
    }
}

