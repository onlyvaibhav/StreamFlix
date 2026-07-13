import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized app configuration using dotenv
class AppConfig {
  /// V1 Backend base URL
  /// Web: http://localhost:3000 or production domain
  /// Android: http://192.168.x.x:3000 (same LAN IP)
  static String get v1BaseUrl {
    final url = dotenv.env['V1_BASE_URL'] ?? 'http://localhost:3000';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Request timeout in seconds
  static const int timeoutSeconds = 10;

  /// Image cache duration
  static const Duration imageCacheDuration = Duration(days: 7);
}
