import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/config/player_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:streamflix/core/router/app_router.dart';

import 'package:streamflix/features/movies/data/models/watch_history.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:streamflix/core/network/local_loopback_server.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: '.env');
  
  await Hive.initFlutter();
  await Hive.openBox('authBox');

  // Setup WebViewController early so it can be mounted by StreamFlixApp
  TelegramClientService().setupController();

  runApp(
    const ProviderScope(
      child: StreamFlixApp(),
    ),
  );
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class StreamFlixApp extends ConsumerWidget {
  const StreamFlixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'StreamFlix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.netflixRed,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.netflixRed,
          secondary: AppColors.netflixRed,
          surface: AppColors.background,
          surfaceContainerHighest: AppColors.backgroundLight,
          error: AppColors.error,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            Positioned(
              top: -100,
              left: -100,
              child: SizedBox(
                width: 1,
                height: 1,
                child: WebViewWidget(
                  controller: TelegramClientService().webViewController,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
