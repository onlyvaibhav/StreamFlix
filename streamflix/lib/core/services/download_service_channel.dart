import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Dart-side wrapper for the Android foreground service that keeps
/// downloads alive when the app is backgrounded or the screen is off.
///
/// One service instance represents overall download activity — it starts
/// when the first download begins and stops when the queue is fully empty.
class DownloadServiceChannel {
  static const _channel = MethodChannel('com.streamflix.app/download_service');

  /// Start the foreground service (shows persistent notification).
  /// Safe to call multiple times — Android ignores duplicate startForeground calls.
  static Future<void> startService(String title) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }
      
      await _channel.invokeMethod('startService', {'title': title});
      debugPrint('📱 Foreground download service started: $title');
    } catch (e) {
      // Don't let a service failure block the actual download
      debugPrint('⚠️ Failed to start foreground service: $e');
    }
  }

  /// Stop the foreground service (removes notification and releases wake lock).
  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod('stopService');
      debugPrint('📱 Foreground download service stopped');
    } catch (e) {
      debugPrint('⚠️ Failed to stop foreground service: $e');
    }
  }

  /// Update the notification text (e.g. switching to a new download item).
  static Future<void> updateNotification(String title) async {
    try {
      await _channel.invokeMethod('updateNotification', {'title': title});
    } catch (e) {
      debugPrint('⚠️ Failed to update download notification: $e');
    }
  }

  /// Force Android WebView to resume timers (overriding background suspension).
  static Future<void> resumeWebviewTimers() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('resumeWebviewTimers');
      }
    } catch (e) {
      // Ignore
    }
  }
}
