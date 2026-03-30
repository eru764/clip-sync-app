package com.erulight.clip_sync_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import kotlinx.coroutines.*
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class SyncActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            "com.erulight.clip_sync_app.SYNC_CLIPBOARD" -> {
                val content = intent.getStringExtra("content") ?: return
                Log.d("ClipSync", "Sync action triggered for: $content")
                
                // Dismiss notification
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(2001)
                
                // Sync to server
                syncToServer(context, content)
            }
            "com.erulight.clip_sync_app.DISMISS_NOTIFICATION" -> {
                // Just dismiss the notification
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(2001)
                Log.d("ClipSync", "Notification dismissed")
            }
        }
    }
    
    private fun syncToServer(context: Context, content: String) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.auth_token", null) 
            ?: prefs.getString("auth_token", null) ?: run {
            Toast.makeText(context, "Not logged in", Toast.LENGTH_SHORT).show()
            return
        }
        val serverUrl = "https://clipsync-server-production-0685.up.railway.app"
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = URL("$serverUrl/clips")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.doOutput = true
                
                val safeContent = content.replace("\"", "\\\"").replace("\n", "\\n")
                val body = """{"content": "$safeContent", "type": "text"}"""
                OutputStreamWriter(connection.outputStream).use { it.write(body) }
                
                val responseCode = connection.responseCode
                connection.disconnect()
                
                withContext(Dispatchers.Main) {
                    if (responseCode in 200..299) {
                        Toast.makeText(context, "Synced!", Toast.LENGTH_SHORT).show()
                        Log.d("ClipSync", "Sync successful: $responseCode")
                    } else {
                        Toast.makeText(context, "Sync failed", Toast.LENGTH_SHORT).show()
                        Log.e("ClipSync", "Sync failed with code: $responseCode")
                    }
                }
            } catch (e: Exception) {
                Log.e("ClipSync", "Sync error: ${e.message}")
                withContext(Dispatchers.Main) {
                    Toast.makeText(context, "Sync error", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
}
