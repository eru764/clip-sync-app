package com.erulight.clip_sync_app

import android.app.*
import android.content.*
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class ClipboardForegroundService : Service() {
    
    private var clipboardManager: ClipboardManager? = null
    private var lastClipContent: String? = null
    private val CHANNEL_ID = "ClipSyncChannel"
    private val NOTIFICATION_ID = 1001
    
    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        val clip = clipboardManager?.primaryClip
        val text = clip?.getItemAt(0)?.text?.toString()
        Log.d("ClipSync", "Clipboard changed: $text")
        if (text != null && text != lastClipContent && text.isNotEmpty()) {
            lastClipContent = text
            syncToServer(text)
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboardManager?.addPrimaryClipChangedListener(clipListener)
        Log.d("ClipSync", "Foreground service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ClipSync")
            .setContentText("Monitoring clipboard...")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(NOTIFICATION_ID, notification)
        Log.d("ClipSync", "Foreground service started")
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ClipSync Clipboard Monitor",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun syncToServer(content: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.auth_token", null) 
            ?: prefs.getString("auth_token", null) ?: return
        val serverUrl = "https://clipsync-server-production-0685.up.railway.app"
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = URL("$serverUrl/clips")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.doOutput = true
                val safeContent = content.replace("\"", "\\\"")
                val body = """{"content": "$safeContent", "type": "text"}"""
                OutputStreamWriter(connection.outputStream).use { it.write(body) }
                val code = connection.responseCode
                Log.d("ClipSync", "Sync response: $code")
                connection.disconnect()
            } catch (e: Exception) {
                Log.e("ClipSync", "Sync error: ${e.message}")
            }
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        clipboardManager?.removePrimaryClipChangedListener(clipListener)
        Log.d("ClipSync", "Foreground service destroyed")
    }
}
