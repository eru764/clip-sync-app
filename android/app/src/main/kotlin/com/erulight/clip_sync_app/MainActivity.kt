package com.erulight.clip_sync_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val CLIPBOARD_CHANNEL = "com.erulight.clip_sync_app/clipboard"
    private val METHOD_CHANNEL = "com.erulight.clip_sync_app/accessibility"
    private var clipboardEventSink: EventChannel.EventSink? = null
    
    private val clipboardReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.erulight.clip_sync_app.CLIPBOARD_CHANGED") {
                val content = intent.getStringExtra("content")
                content?.let {
                    clipboardEventSink?.success(it)
                }
            }
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // EventChannel for clipboard events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    clipboardEventSink = events
                }
                
                override fun onCancel(arguments: Any?) {
                    clipboardEventSink = null
                }
            })
        
        // MethodChannel for accessibility service checks
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityServiceEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(null)
                    }
                    "requestBatteryExemption" -> {
                        val intent = Intent()
                        intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(null)
                    }
                    "startForegroundService" -> {
                        val intent = Intent(this, ClipboardForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopForegroundService" -> {
                        stopService(Intent(this, ClipboardForegroundService::class.java))
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val service = "${packageName}/.ClipboardAccessibilityService"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabledServices?.contains(service) == true
    }
    
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val filter = IntentFilter("com.erulight.clip_sync_app.CLIPBOARD_CHANGED")
        registerReceiver(clipboardReceiver, filter, RECEIVER_NOT_EXPORTED)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(clipboardReceiver)
    }
}
