package com.erulight.clip_sync_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.*
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import android.content.SharedPreferences

class ClipboardBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.erulight.clip_sync_app.CLIPBOARD_CHANGED") {
            val content = intent.getStringExtra("content") ?: return
            Log.d("ClipSync", "BroadcastReceiver triggered with content: $content")
            
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Try both key formats for token
            val token = prefs.getString("flutter.auth_token", null) 
                ?: prefs.getString("auth_token", null) ?: run {
                Log.e("ClipSync", "Token not found in SharedPreferences")
                return
            }
            Log.d("ClipSync", "Token found: ${token != null}")
            Log.d("ClipSync", "Token value: $token")
            
            // Try both key formats for server URL with fallback
            val serverUrl = prefs.getString("flutter.server_url", null)
                ?: prefs.getString("server_url", null)
                ?: "https://clipsync-server-production-0685.up.railway.app"
            Log.d("ClipSync", "ServerUrl found: ${serverUrl != null}")
            Log.d("ClipSync", "ServerUrl value: $serverUrl")
            
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    Log.d("ClipSync", "Starting HTTP request to $serverUrl/clips")
                    val url = URL("$serverUrl/clips")
                    val connection = url.openConnection() as HttpURLConnection
                    connection.requestMethod = "POST"
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("Authorization", "Bearer $token")
                    connection.doOutput = true
                    
                    val body = """{"content": "$content", "type": "text"}"""
                    Log.d("ClipSync", "Request body: $body")
                    OutputStreamWriter(connection.outputStream).use { it.write(body) }
                    
                    val responseCode = connection.responseCode
                    Log.d("ClipSync", "Response code: $responseCode")
                    connection.disconnect()
                    Log.d("ClipSync", "Background clip synced: $content")
                } catch (e: Exception) {
                    Log.e("ClipSync", "Failed to sync clip: ${e.message}")
                    Log.e("ClipSync", "Exception stack trace: ${e.stackTraceToString()}")
                }
            }
        }
    }
}
