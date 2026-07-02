import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeControls {
  static const _channel = MethodChannel('com.streamflix.app/native_controls');

  /// Gets the native device volume as a percentage (0.0 to 1.0)
  static Future<double> getVolume() async {
    if (defaultTargetPlatform != TargetPlatform.android) return 0.5;
    try {
      final double? vol = await _channel.invokeMethod<double>('getVolume');
      return vol ?? 0.5;
    } catch (e) {
      debugPrint('⚠️ Error getting native volume: $e');
      return 0.5;
    }
  }

  /// Sets the native device volume as a percentage (0.0 to 1.0)
  static Future<void> setVolume(double value) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('setVolume', {'volume': value});
    } catch (e) {
      debugPrint('⚠️ Error setting native volume: $e');
    }
  }

  /// Gets the native screen brightness as a percentage (0.0 to 1.0)
  static Future<double> getBrightness() async {
    if (defaultTargetPlatform != TargetPlatform.android) return 1.0;
    try {
      final double? brightness = await _channel.invokeMethod<double>('getBrightness');
      return brightness ?? 1.0;
    } catch (e) {
      debugPrint('⚠️ Error getting native brightness: $e');
      return 1.0;
    }
  }

  /// Sets the native screen brightness as a percentage (0.0 to 1.0)
  static Future<void> setBrightness(double value) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('setBrightness', {'brightness': value});
    } catch (e) {
      debugPrint('⚠️ Error setting native brightness: $e');
    }
  }
}
