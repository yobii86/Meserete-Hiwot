package com.mezmur.zelideta.alarm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import com.mezmur.zelideta.MainActivity
import com.mezmur.zelideta.R

class AlarmService : Service() {

    companion object {
        const val CHANNEL_ID = "program_alarms"
        const val NOTIFICATION_ID = 99901
        private const val AUTO_DISMISS_MS = 10 * 60 * 1000L // 10 minutes max ringing

        private var currentService: AlarmService? = null

        fun isRinging(): Boolean = currentService != null

        fun stop(context: Context) {
            val intent = Intent(context, AlarmService::class.java).apply {
                action = AlarmReceiver.ACTION_STOP_ALARM
            }
            context.startService(intent)
        }

        fun snooze(context: Context, alarmId: Int, payload: String, title: String, body: String) {
            val intent = Intent(context, AlarmService::class.java).apply {
                action = AlarmReceiver.ACTION_SNOOZE_ALARM
                putExtra("alarm_id", alarmId)
                putExtra("payload", payload)
                putExtra("title", title)
                putExtra("body", body)
            }
            context.startService(intent)
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var currentAlarmId: Int = 0
    private var currentPayload: String = ""
    private var currentTitle: String = ""
    private var currentBody: String = ""

    private val autoDismissRunnable = Runnable {
        // Automatically stop and snooze after 10 minutes if user doesn't respond
        snooze(this, currentAlarmId, currentPayload, currentTitle, currentBody)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        currentService = this
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager

        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Mezmur:AlarmServiceWakeLock")?.apply {
            setReferenceCounted(false)
            acquire(15 * 60 * 1000L) // 15 mins max lock
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        if (action == AlarmReceiver.ACTION_STOP_ALARM) {
            stopAlarm()
            stopSelf()
            return START_NOT_STICKY
        }

        if (action == AlarmReceiver.ACTION_SNOOZE_ALARM) {
            val alarmId = intent.getIntExtra("alarm_id", currentAlarmId)
            val payload = intent.getStringExtra("payload") ?: currentPayload
            val title = intent.getStringExtra("title") ?: currentTitle
            val body = intent.getStringExtra("body") ?: currentBody

            // Snooze: schedule for +10 minutes
            val snoozeTime = System.currentTimeMillis() + (10 * 60 * 1000L)
            val programId = intent.getIntExtra("program_id", 0)
            AlarmScheduler.schedule(this, alarmId + 100000, snoozeTime, programId, title, body, payload)

            stopAlarm()
            stopSelf()
            return START_NOT_STICKY
        }

        currentAlarmId = intent?.getIntExtra("alarm_id", 0) ?: 0
        currentPayload = intent?.getStringExtra("payload") ?: "alarm:0"
        currentTitle = intent?.getStringExtra("title") ?: "የመርሐ ግብር ማንቂያ"
        currentBody = intent?.getStringExtra("body") ?: "መርሐ ግብሩ በቅርቡ ይጀምራል"

        startForegroundNotification(currentAlarmId, currentTitle, currentBody, currentPayload)
        startAudioAndVibration()

        handler.removeCallbacks(autoDismissRunnable)
        handler.postDelayed(autoDismissRunnable, AUTO_DISMISS_MS)

        return START_NOT_STICKY
    }

    private fun startForegroundNotification(
        alarmId: Int,
        title: String,
        body: String,
        payload: String
    ) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Ensure alarm channel exists
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "የመርሐ ግብር ማንቂያዎች (Program Alarms)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority program reminder alarms that ring on lockscreen"
                setSound(null, null) // Sound is handled explicitly by MediaPlayer
                enableVibration(false) // Vibration is handled explicitly by Vibrator
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            nm.createNotificationChannel(channel)
        }

        // Full Screen Intent pointing to MainActivity with alarm route
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = "com.mezmur.zelideta.OPEN_ALARM"
            putExtra("payload", payload)
            putExtra("alarm_id", alarmId)
            putExtra("title", title)
            putExtra("body", body)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            alarmId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop Action
        val stopIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_STOP_ALARM
            putExtra("alarm_id", alarmId)
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId + 1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Snooze Action
        val snoozeIntent = Intent(this, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_SNOOZE_ALARM
            putExtra("alarm_id", alarmId)
            putExtra("payload", payload)
            putExtra("title", title)
            putExtra("body", body)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId + 2,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setColor(0xFF6E1423.toInt()) // AppColors.maroon
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(R.drawable.audio_service_stop, "አቁም (Stop)", stopPendingIntent)
            .addAction(android.R.drawable.ic_popup_reminder, "አሸልብ (Snooze 10m)", snoozePendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startAudioAndVibration() {
        requestAudioFocus()

        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                val afd = resources.openRawResourceFd(R.raw.alarm)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()

                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setAudioAttributes(audioAttributes)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            // Fallback to ringtone if raw resource fails
        }

        try {
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            val pattern = longArrayOf(0, 800, 400, 800, 400, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {}
    }

    private fun requestAudioFocus() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .build()
            focusRequest = req
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
    }

    private fun abandonAudioFocus() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
    }

    private fun stopAlarm() {
        handler.removeCallbacks(autoDismissRunnable)

        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
        } catch (e: Exception) {}
        mediaPlayer = null

        try {
            vibrator?.cancel()
        } catch (e: Exception) {}
        vibrator = null

        abandonAudioFocus()

        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (e: Exception) {}
        wakeLock = null

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID)
    }

    override fun onDestroy() {
        stopAlarm()
        currentService = null
        super.onDestroy()
    }
}

