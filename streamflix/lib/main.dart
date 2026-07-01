import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/config/player_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:streamflix/core/router/app_router.dart';

import 'package:streamflix/features/movies/data/models/watch_history.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  PlayerConfig.initialize();
  await WatchHistoryManager.loadHistory();
  runApp(
    const ProviderScope(
      child: StreamFlixApp(),
    ),
  );
}

class StreamFlixApp extends ConsumerWidget {
  const StreamFlixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
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
    );
  }
}
