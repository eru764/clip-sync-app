package com.erulight.clip_sync_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import org.json.JSONObject

class ClipboardAccessibilityService : AccessibilityService() {

    companion object {
        var isRunning = false
    }

    private var lastClipContent: String? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO)
    private val CHANNEL_ID = "ClipSyncNotifications"
    private val NOTIFICATION_ID = 2001

    override fun onServiceConnected() {
        super.onServiceConnected()
        if (isRunning) {
            Log.d("ClipSync", "Service already running, skipping duplicate instance")
            return
        }
        isRunning = true
        Log.d("ClipSync", "Accessibility service connected!")
        createNotificationChannel()

        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        serviceInfo = info

        serviceScope.launch {
            while (true) {
                delay(500)
                checkClipboard()
            }
        }
    }

    private fun checkClipboard() {
        try {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = clipboard.primaryClip
            val text = clip?.getItemAt(0)?.text?.toString()
            if (text != null && text != lastClipContent && text.isNotEmpty()) {
                lastClipContent = text
                Log.d("ClipSync", "New clipboard content: $text")
                autoSync(text)
            }
        } catch (e: Exception) {
            Log.e("ClipSync", "Clipboard poll error: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ClipSync Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun autoSync(content: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.auth_token", null) 
            ?: prefs.getString("auth_token", null)
        
        Log.d("ClipSync", "Auto-syncing. Token found: ${token != null}")
        
        if (token == null) {
            Log.e("ClipSync", "No token found, cannot sync")
            return
        }
        
        serviceScope.launch {
            val code = syncWithToken(content, token)
            if (code == 401) {
                Log.d("ClipSync", "Token expired, refreshing...")
                val newToken = refreshToken()
                if (newToken != null) {
                    syncWithToken(content, newToken)
                }
            }
        }
    }

    private suspend fun syncWithToken(content: String, token: String): Int {
        return try {
            val serverUrl = "https://clipsync-server-production-0685.up.railway.app"
            val url = java.net.URL("$serverUrl/clips")
            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "POST"
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.doOutput = true
            val jsonBody = JSONObject()
            jsonBody.put("content", content)
            jsonBody.put("type", "text")
            val body = jsonBody.toString()
            java.io.OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { it.write(body) }
            val responseCode = connection.responseCode
            if (responseCode == 200 || responseCode == 201) {
                Log.d("ClipSync", "Sync successful: $responseCode")
                showConfirmationNotification(content)
            } else {
                val errorStream = connection.errorStream?.bufferedReader()?.readText() ?: "no error body"
                Log.e("ClipSync", "Sync failed $responseCode: $errorStream")
            }
            connection.disconnect()
            responseCode
        } catch (e: Exception) {
            Log.e("ClipSync", "Sync error: ${e.message}")
            -1
        }
    }
    
    private fun refreshToken(): String? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val refreshToken = prefs.getString("flutter.refresh_token", null)
            ?: prefs.getString("refresh_token", null) ?: return null
        
        return try {
            val url = java.net.URL("https://securetoken.googleapis.com/v1/token?key=AIzaSyBbKI6LDUimJvKiBOFd2HFqs-sc7YQI_1w")
            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.doOutput = true
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            
            val body = "grant_type=refresh_token&refresh_token=$refreshToken"
            java.io.OutputStreamWriter(connection.outputStream).use { it.write(body) }
            
            val response = connection.inputStream.bufferedReader().readText()
            connection.disconnect()
            
            val idToken = response.substringAfter("\"id_token\":\"").substringBefore("\"")
            val newRefreshToken = response.substringAfter("\"refresh_token\":\"").substringBefore("\"")
            
            if (idToken.isNotEmpty()) {
                prefs.edit()
                    .putString("flutter.auth_token", idToken)
                    .putString("auth_token", idToken)
                    .putString("flutter.refresh_token", newRefreshToken)
                    .putString("refresh_token", newRefreshToken)
                    .apply()
                Log.d("ClipSync", "Token refreshed successfully")
                idToken
            } else null
        } catch (e: Exception) {
            Log.e("ClipSync", "Token refresh error: ${e.message}")
            null
        }
    }

    private fun showConfirmationNotification(content: String) {
        val preview = if (content.length > 40) content.substring(0, 40) + "..." else content
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("✓ Synced to devices")
            .setContentText(preview)
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setAutoCancel(true)
            .setTimeoutAfter(3000)
            .build()
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        serviceScope.cancel()
        Log.d("ClipSync", "Accessibility service destroyed")
    }
}
