import 'package:media_kit/media_kit.dart';

/// Global media_kit initialization
/// Must be called in main() before runApp()
class PlayerConfig {
  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;
    
    MediaKit.ensureInitialized();
    _initialized = true;
  }
}
