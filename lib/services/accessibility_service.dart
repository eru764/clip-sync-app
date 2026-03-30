import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AccessibilityService {
  static const EventChannel _clipboardChannel = 
      EventChannel('com.erulight.clip_sync_app/clipboard');
  
  static const MethodChannel _methodChannel =
      MethodChannel('com.erulight.clip_sync_app/accessibility');
  
  // Stream of clipboard changes from accessibility service
  static Stream<String> get clipboardStream {
    if (!Platform.isAndroid) {
      return Stream.empty();
    }
    return _clipboardChannel.receiveBroadcastStream().map((event) => event.toString());
  }
  
  // Save server URL to SharedPreferences for native receiver access
  static Future<void> saveServerUrl(String serverUrl) async {
    if (!Platform.isAndroid) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', serverUrl);
      print('Server URL saved to SharedPreferences: $serverUrl');
    } catch (e) {
      print('Error saving server URL: $e');
    }
  }
  
  // Check if accessibility service is enabled
  static Future<bool> isAccessibilityServiceEnabled() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final bool result = await _methodChannel.invokeMethod('isAccessibilityServiceEnabled');
      return result;
    } catch (e) {
      print('Error checking accessibility service: $e');
      return false;
    }
  }
  
  // Open accessibility settings
  static Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('Error opening accessibility settings: $e');
    }
  }
  
  // Request battery optimization exemption
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _methodChannel.invokeMethod('requestBatteryExemption');
    } catch (e) {
      print('Error requesting battery exemption: $e');
    }
  }
  
  // Start foreground service for clipboard monitoring
  static Future<void> startForegroundService() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _methodChannel.invokeMethod('startForegroundService');
      print('Foreground service started');
    } catch (e) {
      print('Error starting foreground service: $e');
    }
  }
  
  // Stop foreground service
  static Future<void> stopForegroundService() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _methodChannel.invokeMethod('stopForegroundService');
      print('Foreground service stopped');
    } catch (e) {
      print('Error stopping foreground service: $e');
    }
  }
}
