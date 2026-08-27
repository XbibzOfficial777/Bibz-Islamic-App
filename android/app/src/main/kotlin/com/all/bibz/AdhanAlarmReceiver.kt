package com.all.bibz

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val serviceIntent = Intent(context, AdhanAudioService::class.java).apply {
            putExtra("title", intent.getStringExtra("title") ?: "Waktu sholat")
            putExtra("body", intent.getStringExtra("body") ?: "Waktu sholat telah masuk")
            putExtra("payload", intent.getStringExtra("payload") ?: "")
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
