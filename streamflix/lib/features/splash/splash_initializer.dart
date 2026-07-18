import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamflix/core/config/player_config.dart';
import 'package:streamflix/features/movies/data/models/watch_history.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';
import 'package:streamflix/core/network/local_loopback_server.dart';
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SplashInitializer {
  /// Initializes all heavy background services required before entering the app.
  static Future<void> initialize() async {
    // 1. Database & APIs
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    // 2. Video Player Config
    PlayerConfig.initialize();

    // 3. User Data & History
    await WatchHistoryManager.loadHistory();

    // 4. Downloads
    await DownloadManager().init();
    await DownloadManager().reconcile();

    // 5. Telegram Backend Services
    await LocalLoopbackServer().start();
    final box = Hive.box('authBox');
    final savedSession = box.get('telegram_session') as String?;
    await TelegramClientService().init(initialSession: savedSession);
  }
}
