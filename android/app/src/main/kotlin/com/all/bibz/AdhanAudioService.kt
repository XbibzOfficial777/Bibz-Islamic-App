package com.all.bibz

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class AdhanAudioService : Service() {
    companion object {
        private const val CHANNEL_ID = "quranx_adhan_playback_v1"
        private const val NOTIFICATION_ID = 6901
        private const val PREFS = "quranx_adhan_audio"
        private const val LAST_ERROR = "last_error"

        fun start(context: android.content.Context, title: String? = null, body: String? = null) {
            val intent = Intent(context, AdhanAudioService::class.java).apply {
                putExtra("title", title ?: "Waktu sholat")
                putExtra("body", body ?: "Waktu sholat telah masuk")
            }
            androidx.core.content.ContextCompat.startForegroundService(context, intent)
        }
    }

    private var player: MediaPlayer? = null

    override fun onCreate() {
        super.onCreate()
        createPlaybackChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, playbackNotification(intent))
        playAdhan()
        return START_NOT_STICKY
    }

    private fun playAdhan() {
        stopPlayer()
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().remove(LAST_ERROR).apply()
        try {
            val afd = resources.openRawResourceFd(R.raw.quranx_adhan)
                ?: throw IllegalStateException("Resource quranx_adhan tidak tersedia")
            val mediaPlayer = MediaPlayer()
            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            afd.use { descriptor ->
                mediaPlayer.setDataSource(
                    descriptor.fileDescriptor,
                    descriptor.startOffset,
                    descriptor.length,
                )
            }
            mediaPlayer.setOnPreparedListener {
                getSharedPreferences(PREFS, MODE_PRIVATE).edit().remove(LAST_ERROR).apply()
                it.start()
            }
            mediaPlayer.setOnCompletionListener {
                it.release()
                player = null
                stopSelf()
            }
            mediaPlayer.setOnErrorListener { _, what, extra ->
                recordError("MediaPlayer gagal memutar audio adzan (what=$what, extra=$extra)")
                stopPlayer()
                stopSelf()
                true
            }
            player = mediaPlayer
            mediaPlayer.prepareAsync()
        } catch (error: Throwable) {
            recordError(error.message ?: error.javaClass.simpleName)
            stopSelf()
        }
    }

    private fun stopPlayer() {
        player?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
                // The player may still be preparing asynchronously.
            }
            it.release()
        }
        player = null
    }

    private fun recordError(message: String) {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putString(LAST_ERROR, message)
            .apply()
    }

    private fun playbackNotification(intent: Intent?): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                6902,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(intent?.getStringExtra("title") ?: "Waktu sholat")
            .setContentText("Audio adzan sedang diputar")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun createPlaybackChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Pemutaran audio adzan QuranX",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Status pemutaran audio adzan native"
                setSound(null, null)
                enableVibration(false)
            },
        )
    }

    override fun onDestroy() {
        stopPlayer()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
