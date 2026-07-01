# StreamFlix V2 — Implementation Plan

## Overview

Since you've completed Phase 1, we'll proceed with **Phase 2** through **Phase 5**. Due to token limits, I'll deliver the plan in parts:

- **Part 1**: Phase 2A — Project Setup + Core Infrastructure  
- **Part 2**: Phase 2B — Data Layer + Movie Catalog
- **Part 3**: Phase 2C — UI Screens (Home + Detail)
- **Part 4**: Phase 2D — Video Player + Subtitles
- **Part 5**: Phase 3 — Client-Side Streaming
- **Part 6**: Phase 4 — Telegram Login
- **Part 7**: Phase 5 — Supabase Sync

---

# PART 1: Phase 2A — Project Setup + Core Infrastructure

## Phase 2A — Project Setup + Core Infrastructure

### Goal
Establish the foundational architecture for StreamFlix V2: dependency injection with Riverpod, navigation with GoRouter, networking with Dio, and a complete design system matching Netflix's dark, premium aesthetic. After this phase, the app has no data yet but has a working navigation structure, type-safe routing, and all reusable UI components ready for screens to use.

### Prerequisites
- Fresh Flutter project created in Phase 1
- `flutter run -d chrome` shows the default counter app
- `flutter run` on Android device works
- Git repository initialized

### Fetch from Coding Agent

```
╔══════════════════════════════════════════════════════════════════╗
║  FETCH FROM CODING AGENT — V1 API Discovery (Part 1 of 4)       ║
╠══════════════════════════════════════════════════════════════════╣
║  "Show me the contents of the routes/ directory. List all files  ║
║   and for each route file, show me:                              ║
║   1. All endpoint paths (e.g., GET /api/movies)                  ║
║   2. Request parameters (query, path, body)                      ║
║   3. Response structure with actual field names                  ║
║   I need this to build accurate Dart models."                    ║
╚══════════════════════════════════════════════════════════════════╝
```

**Wait for response, then create:**  
`docs/v1_api_endpoints.md` — document all endpoints discovered

### Files to Create

#### 1. Configuration & Constants

**`lib/core/config/app_config.dart`**
```dart
/// Centralized app configuration using --dart-define
class AppConfig {
  /// V1 Backend base URL
  /// Web: http://localhost:3000 or production domain
  /// Android: http://192.168.x.x:3000 (same LAN IP)
  static const String v1BaseUrl = String.fromEnvironment(
    'V1_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Request timeout in seconds
  static const int timeoutSeconds = 30;

  /// Image cache duration
  static const Duration imageCacheDuration = Duration(days: 7);

  // Phase 3 additions (streaming) - commented out for now:
  // static const int telegramApiId = int.fromEnvironment('TG_API_ID');
  // static const String telegramApiHash = String.fromEnvironment('TG_API_HASH');
  // static const String telegramBotSession = String.fromEnvironment('TG_BOT_SESSION');

  // Phase 5 additions (Supabase) - commented out for now:
  // static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  // static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
```

**`lib/core/constants/app_colors.dart`**
```dart
import 'package:flutter/material.dart';

/// Netflix-inspired color palette
class AppColors {
  AppColors._(); // Private constructor - this class is not meant to be instantiated

  // Primary colors
  static const Color netflixRed = Color(0xFFE50914);
  static const Color netflixRedDark = Color(0xFFB20710);
  
  // Background colors
  static const Color background = Color(0xFF141414);
  static const Color backgroundLight = Color(0xFF1F1F1F);
  static const Color backgroundCard = Color(0xFF2F2F2F);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  
  // Accent colors
  static const Color success = Color(0xFF46D369);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFE50914);
  
  // Overlay colors
  static const Color overlay = Color(0x99000000); // 60% black
  static const Color overlayLight = Color(0x4D000000); // 30% black
  
  // Gradient colors
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000), // Transparent
      Color(0x80000000), // 50% black
      Color(0xFF141414), // Solid background
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0xCC000000), // 80% black
    ],
    stops: [0.5, 1.0],
  );
}
```

**`lib/core/constants/app_text_styles.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';

/// Typography scale matching Netflix's design
class AppTextStyles {
  AppTextStyles._();

  // Hero/Display styles
  static const TextStyle heroTitle = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const TextStyle heroTitleMobile = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.1,
  );

  // Headings
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Special purpose
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
    letterSpacing: 1.5,
  );
}
```

**`lib/core/constants/app_dimensions.dart`**
```dart
/// Spacing, sizing, and layout constants
class AppDimensions {
  AppDimensions._();

  // Spacing scale
  static const double spaceXSmall = 4.0;
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 16.0;
  static const double spaceLarge = 24.0;
  static const double spaceXLarge = 32.0;
  static const double spaceXXLarge = 48.0;

  // Border radius
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;

  // Icon sizes
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // Movie card dimensions
  static const double movieCardWidth = 160.0;
  static const double movieCardHeight = 240.0; // 2:3 aspect ratio
  static const double movieCardWidthLarge = 200.0;
  static const double movieCardHeightLarge = 300.0;

  // Hero banner
  static const double heroBannerHeightMobile = 400.0;
  static const double heroBannerHeightTablet = 500.0;
  static const double heroBannerHeightDesktop = 600.0;

  // Button dimensions
  static const double buttonHeight = 48.0;
  static const double buttonHeightSmall = 36.0;
  static const double buttonMinWidth = 120.0;

  // Maximum content width (for web)
  static const double maxContentWidth = 1920.0;
  static const double maxContentWidthNarrow = 1200.0;
}
```

#### 2. Network Layer

**`lib/core/network/dio_client.dart`**
```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/config/app_config.dart';

/// Dio HTTP client singleton
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.v1BaseUrl,
      connectTimeout: Duration(seconds: AppConfig.timeoutSeconds),
      receiveTimeout: Duration(seconds: AppConfig.timeoutSeconds),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Request interceptor - logs all requests in debug mode
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('🌐 REQUEST[${options.method}] => ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('✅ RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}');
        return handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('❌ ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}');
        debugPrint('   Message: ${error.message}');
        return handler.next(error);
      },
    ),
  );

  return dio;
});
```

**`lib/core/network/api_endpoints.dart`**
```dart
/// V1 API endpoint path constants
/// These will be populated after fetching V1 routes
class ApiEndpoints {
  ApiEndpoints._();

  // Movie endpoints (placeholder - update after V1 fetch)
  static const String movies = '/api/movies';
  static const String movieDetail = '/api/movies/:id'; // Replace :id with actual ID
  static const String moviesByGenre = '/api/movies/genre/:genre';
  static const String featuredMovies = '/api/movies/featured';

  // Streaming endpoints
  static const String stream = '/stream/:id'; // V1 streaming endpoint

  // Subtitle endpoints
  static const String subtitles = '/api/subtitles/:id';

  // Static file patterns (update after V1 fetch)
  static String moviePoster(String movieId) => '/data/$movieId/poster.jpg';
  static String movieLogo(String movieId) => '/data/$movieId/logo.png';
  static String movieBackdrop(String movieId) => '/data/$movieId/backdrop.jpg';
  static String movieMetadata(String movieId) => '/data/$movieId/metadata.json';

  // Phase 4 additions (auth) - commented for now:
  // static const String checkMember = '/api/check-member';

  // Phase 5 additions (Supabase bridge) - commented for now:
  // static const String supabaseToken = '/api/auth/supabase-token';
}
```

#### 3. Router Setup

**`lib/core/router/route_names.dart`**
```dart
/// Named route constants for type-safe navigation
class RouteNames {
  RouteNames._();

  // Phase 2 routes
  static const String home = '/';
  static const String movieDetail = '/movie/:id';
  static const String watch = '/watch/:id';

  // Phase 4 routes (auth) - commented for now:
  // static const String login = '/login';
  // static const String loginOtp = '/login/otp';
  // static const String joinChannel = '/join-channel';

  // Utility methods
  static String movieDetailPath(String movieId) => '/movie/$movieId';
  static String watchPath(String movieId) => '/watch/$movieId';
}
```

**`lib/core/router/app_router.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix_v2/core/router/route_names.dart';
import 'package:streamflix_v2/features/movies/presentation/screens/home_screen.dart';
import 'package:streamflix_v2/features/movies/presentation/screens/movie_detail_screen.dart';
import 'package:streamflix_v2/features/player/presentation/screens/watch_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  return GoRouter(
    initialLocation: RouteNames.home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.movieDetail,
        name: 'movieDetail',
        pageBuilder: (context, state) {
          final movieId = state.pathParameters['id']!;
          return MaterialPage(
            key: state.pageKey,
            child: MovieDetailScreen(movieId: movieId),
          );
        },
      ),
      GoRoute(
        path: RouteNames.watch,
        name: 'watch',
        pageBuilder: (context, state) {
          final movieId = state.pathParameters['id']!;
          return MaterialPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: WatchScreen(movieId: movieId),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

#### 4. Core Widgets

**`lib/core/widgets/app_image.dart`**
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:streamflix_v2/core/config/app_config.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/widgets/shimmer_box.dart';

/// Cached network image wrapper with loading and error states
class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Construct full URL if relative path provided
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${AppConfig.v1BaseUrl}$imageUrl';

    Widget image = CachedNetworkImage(
      imageUrl: fullUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      placeholder: (context, url) => ShimmerBox(
        width: width,
        height: height,
      ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: AppColors.backgroundCard,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textTertiary,
              size: 48,
            ),
          ),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
```

**`lib/core/widgets/shimmer_box.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';

/// Animated loading placeholder with shimmer effect
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                AppColors.backgroundCard,
                AppColors.backgroundLight,
                AppColors.backgroundCard,
              ],
              stops: [
                0.0,
                _animation.value.clamp(0.0, 1.0),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}
```

**`lib/core/widgets/gradient_overlay.dart`**
```dart
import 'package:flutter/material.dart';

/// Reusable gradient overlay for backdrops and cards
class GradientOverlay extends StatelessWidget {
  final List<Color> colors;
  final List<double>? stops;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientOverlay({
    super.key,
    required this.colors,
    this.stops,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
  });

  /// Bottom-to-top dark gradient (typical for hero banners)
  const GradientOverlay.bottomDark({
    super.key,
  })  : colors = const [
          Color(0x00000000),
          Color(0x80000000),
          Color(0xFF141414),
        ],
        stops = const [0.0, 0.5, 1.0],
        begin = Alignment.topCenter,
        end = Alignment.bottomCenter;

  /// Card hover gradient (used on movie cards)
  const GradientOverlay.card({
    super.key,
  })  : colors = const [
          Color(0x00000000),
          Color(0xCC000000),
        ],
        stops = const [0.5, 1.0],
        begin = Alignment.topCenter,
        end = Alignment.bottomCenter;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }
}
```

**`lib/core/widgets/error_widget.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';

/// Reusable error widget with retry button
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconXLarge * 1.5,
              color: AppColors.error,
            ),
            const SizedBox(height: AppDimensions.spaceMedium),
            Text(
              message,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spaceLarge),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.netflixRed,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceLarge,
                    vertical: AppDimensions.spaceMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

### Files to Modify

**`lib/main.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/router/app_router.dart';

void main() {
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
          background: AppColors.background,
          surface: AppColors.backgroundLight,
          error: AppColors.error,
        ),
        fontFamily: 'Roboto', // Or use a custom font closer to Netflix
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

**`pubspec.yaml`** — Dependencies section
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.3.5
  
  # Navigation
  go_router: ^14.0.2
  
  # Networking
  dio: ^5.4.0
  
  # Image loading
  cached_network_image: ^3.3.1
  
  # Code generation (for Riverpod + Freezed later)
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  
  # Code generators
  build_runner: ^2.4.8
  riverpod_generator: ^2.4.0
  freezed: ^2.4.7
  json_serializable: ^6.7.1
```

### Key Implementation Details

1. **--dart-define Usage**  
   The app must ALWAYS be run with the V1 base URL defined:
   ```bash
   # Web development
   flutter run -d chrome --dart-define=V1_BASE_URL=http://localhost:3000
   
   # Android development (replace with your machine's LAN IP)
   flutter run --dart-define=V1_BASE_URL=http://192.168.1.100:3000
   ```
   Android CANNOT use `localhost` — it refers to the device itself, not the host machine.

2. **Dio Interceptor**  
   The request/response logging is debug-only. In production builds, these `debugPrint` calls are automatically stripped.

3. **Image Caching Strategy**  
   `CachedNetworkImage` automatically handles:
   - Memory cache (fast repeat access)
   - Disk cache (persistent across app restarts)
   - `memCacheWidth` and `memCacheHeight` prevent loading full-resolution images for thumbnails

4. **Shimmer Animation**  
   Uses `SingleTickerProviderStateMixin` for efficient animation. The gradient moves horizontally to create the shimmer effect.

5. **Router Error Handling**  
   The `errorBuilder` in GoRouter catches:
   - Invalid routes (404-style errors)
   - Missing path parameters
   - Navigation to routes that don't exist

6. **NoTransitionPage vs MaterialPage**  
   - `NoTransitionPage`: No animation (used for home screen to avoid flash on load)
   - `MaterialPage`: Standard bottom-to-top slide transition (details, player)

### pubspec.yaml Changes
Already included above in "Files to Modify" section.

### Commands to Run

```bash
# 1. Add dependencies
flutter pub add flutter_riverpod riverpod_annotation go_router dio cached_network_image freezed_annotation json_annotation

# 2. Add dev dependencies
flutter pub add --dev build_runner riverpod_generator freezed json_serializable

# 3. Get dependencies
flutter pub get

# 4. Generate code (router will fail until screens exist - that's expected)
dart run build_runner build --delete-conflicting-outputs

# 5. Verify app runs with placeholder screens
flutter run -d chrome --dart-define=V1_BASE_URL=http://localhost:3000
```

**Expected outcome at this point:**  
App will fail to build because `HomeScreen`, `MovieDetailScreen`, and `WatchScreen` don't exist yet. That's correct — we're building them in Phase 2B/2C.

To test the infrastructure without screens, temporarily comment out the route definitions in `app_router.dart` and create a placeholder home screen:

```dart
// Temporary test widget
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Phase 2A Complete - Infrastructure Ready'),
      ),
    );
  }
}
```

### Acceptance Criteria

1. ✅ Running `flutter pub get` completes without errors
2. ✅ Running `dart run build_runner build` generates `app_router.g.dart`
3. ✅ App builds successfully for both web and Android targets
4. ✅ The placeholder home screen shows dark background (#141414)
5. ✅ Navigating to an invalid route (e.g., `/invalid`) shows the custom error page
6. ✅ Network requests (test with a dummy Dio call) include correct base URL from `--dart-define`
7. ✅ `AppImage` widget displays a shimmer placeholder while loading an image
8. ✅ Console logs show Dio request/response interceptor output in debug mode
9. ✅ All color constants are accessible via `AppColors.netflixRed`, etc.
10. ✅ All text styles render correctly when applied to Text widgets

---
# PART 2: Phase 2B — Data Layer + Movie Catalog

## Phase 2B — Data Layer + Movie Catalog

### Goal
Build the complete data layer that fetches movie information from V1's API and `data/` directory. This includes Freezed models matching V1's exact JSON structure, repository pattern implementation, and Riverpod providers for reactive state management. After this phase, the app can fetch and cache movie lists, movie details, and all associated metadata without any UI yet.

### Prerequisites
- Phase 2A completed: all core infrastructure in place
- `dart run build_runner build` runs successfully
- Dio client configured and tested
- V1 backend running and accessible at the configured URL

### Fetch from Coding Agent

```
╔══════════════════════════════════════════════════════════════════╗
║  FETCH FROM CODING AGENT — V1 Data Structures (Part 2 of 4)     ║
╠══════════════════════════════════════════════════════════════════╣
║  "Show me the complete contents of one metadata.json file from   ║
║   the data/{movie_id}/ directory. I need to see every field      ║
║   name, data type, and nested structure. Also show me how the    ║
║   V1 API response differs (if at all) from the metadata.json     ║
║   file — does the API endpoint return the same structure or      ║
║   does it wrap/transform it?"                                    ║
╚══════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════╗
║  FETCH FROM CODING AGENT — V1 Movie List Endpoint               ║
╠══════════════════════════════════════════════════════════════════╣
║  "Show me the route handler for the main movie list endpoint.    ║
║   What is the exact response structure? Is it:                   ║
║   - A plain array: [movie1, movie2, ...]                         ║
║   - A wrapped object: { movies: [...], total: N }                ║
║   - Paginated: { data: [...], page: N, totalPages: M }           ║
║   Show me the actual code that sends the response."              ║
╚══════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════╗
║  FETCH FROM CODING AGENT — V1 Genre System                       ║
╠══════════════════════════════════════════════════════════════════╣
║  "Show me how genres are stored in V1. Are they:                 ║
║   - TMDB genre objects: { id: 28, name: 'Action' }               ║
║   - Just strings: ['Action', 'Thriller']                         ║
║   - Just IDs: [28, 53]                                           ║
║   Show me the genre field in a metadata.json file and any        ║
║   genre-related API endpoints."                                  ║
╚══════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════╗
║  FETCH FROM CODING AGENT — V1 Featured/Category Logic            ║
╠══════════════════════════════════════════════════════════════════╣
║  "Does V1 have endpoints for:                                    ║
║   - Featured/hero movies for the home banner?                    ║
║   - Movies by genre/category?                                    ║
║   - Trending/popular movies?                                     ║
║   Show me all route handlers related to movie categorization     ║
║   and filtering."                                                ║
╚══════════════════════════════════════════════════════════════════╝
```

**After all fetches, update:**  
`docs/v1_api_contract.md` with complete API documentation

### Files to Create

#### 1. Domain Models (Freezed)

**`lib/features/movies/data/models/genre.dart`**
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'genre.freezed.dart';
part 'genre.g.dart';

/// TMDB Genre model
@freezed
class Genre with _$Genre {
  const factory Genre({
    required int id,
    required String name,
  }) = _Genre;

  factory Genre.fromJson(Map<String, dynamic> json) => _$GenreFromJson(json);
}
```

**`lib/features/movies/data/models/movie.dart`**
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix_v2/features/movies/data/models/genre.dart';

part 'movie.freezed.dart';
part 'movie.g.dart';

/// Movie model matching V1 metadata.json structure
/// 
/// IMPORTANT: Update this model after fetching actual V1 metadata.json
/// The fields below are based on typical TMDB structure but MUST match
/// V1's exact field names and types.
@freezed
class Movie with _$Movie {
  const factory Movie({
    // Core identification
    required String id, // May be int or String - verify with V1
    required String title,
    @JsonKey(name: 'original_title') String? originalTitle,
    
    // Metadata
    required String overview,
    @JsonKey(name: 'release_date') String? releaseDate,
    @JsonKey(name: 'vote_average') double? voteAverage,
    @JsonKey(name: 'vote_count') int? voteCount,
    double? popularity,
    
    // Media paths (relative or full URLs - verify with V1)
    @JsonKey(name: 'poster_path') String? posterPath,
    @JsonKey(name: 'backdrop_path') String? backdropPath,
    @JsonKey(name: 'logo_path') String? logoPath,
    
    // Classification
    List<Genre>? genres,
    @JsonKey(name: 'genre_ids') List<int>? genreIds, // May use IDs instead of objects
    
    // Additional metadata
    int? runtime, // In minutes
    String? status, // 'Released', 'Post Production', etc.
    String? tagline,
    
    // Video information (for Phase 3 streaming)
    @JsonKey(name: 'file_id') String? fileId,
    @JsonKey(name: 'access_hash') String? accessHash,
    @JsonKey(name: 'file_reference') String? fileReference,
    @JsonKey(name: 'dc_id') int? dcId,
    @JsonKey(name: 'file_size') int? fileSize,
    
    // Adult content flag
    bool? adult,
  }) = _Movie;

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
}

/// Extension methods for computed properties
extension MovieX on Movie {
  /// Full poster URL
  String? get fullPosterUrl {
    if (posterPath == null) return null;
    if (posterPath!.startsWith('http')) return posterPath;
    return '/data/$id/poster.jpg'; // V1 static file pattern
  }

  /// Full backdrop URL
  String? get fullBackdropUrl {
    if (backdropPath == null) return null;
    if (backdropPath!.startsWith('http')) return backdropPath;
    return '/data/$id/backdrop.jpg';
  }

  /// Full logo URL
  String? get fullLogoUrl {
    if (logoPath == null) return null;
    if (logoPath!.startsWith('http')) return logoPath;
    return '/data/$id/logo.png';
  }

  /// Release year extracted from release_date
  String? get releaseYear {
    if (releaseDate == null || releaseDate!.isEmpty) return null;
    return releaseDate!.split('-').first;
  }

  /// Formatted runtime (e.g., "2h 15m")
  String? get formattedRuntime {
    if (runtime == null) return null;
    final hours = runtime! ~/ 60;
    final minutes = runtime! % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  /// Rating out of 10 formatted to 1 decimal place
  String get formattedRating {
    if (voteAverage == null) return 'N/A';
    return voteAverage!.toStringAsFixed(1);
  }

  /// Genre names as comma-separated string
  String get genreList {
    if (genres == null || genres!.isEmpty) return '';
    return genres!.map((g) => g.name).join(', ');
  }
}
```

**`lib/features/movies/data/models/movie_list_response.dart`**
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';

part 'movie_list_response.freezed.dart';
part 'movie_list_response.g.dart';

/// Response wrapper for movie list endpoints
/// Update structure after fetching V1 API response format
@freezed
class MovieListResponse with _$MovieListResponse {
  const factory MovieListResponse({
    // Option A: Plain array response - use @JsonKey(name: '.') on movies
    // Option B: Wrapped response (shown below)
    required List<Movie> movies,
    int? total,
    int? page,
    @JsonKey(name: 'total_pages') int? totalPages,
  }) = _MovieListResponse;

  factory MovieListResponse.fromJson(Map<String, dynamic> json) =>
      _$MovieListResponseFromJson(json);

  /// Alternative: if V1 returns plain array, use this factory instead
  factory MovieListResponse.fromList(List<dynamic> json) {
    return MovieListResponse(
      movies: json.map((e) => Movie.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
```

#### 2. Data Sources

**`lib/features/movies/data/datasources/movie_remote_datasource.dart`**
```dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix_v2/core/network/api_endpoints.dart';
import 'package:streamflix_v2/core/network/dio_client.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';

part 'movie_remote_datasource.g.dart';

/// Remote data source for movie-related API calls
class MovieRemoteDataSource {
  final Dio _dio;

  MovieRemoteDataSource(this._dio);

  /// Fetch all movies from V1
  Future<List<Movie>> getAllMovies() async {
    try {
      final response = await _dio.get(ApiEndpoints.movies);
      
      // Handle different response structures based on V1 API
      // Update this after fetching V1 response format
      if (response.data is List) {
        // Plain array response
        return (response.data as List)
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map<String, dynamic>) {
        // Wrapped response - adjust key name based on V1
        final movies = response.data['movies'] ?? response.data['data'] ?? [];
        return (movies as List)
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw Exception('Unexpected response format from V1');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch single movie details by ID
  Future<Movie> getMovieById(String movieId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.movieDetail.replaceAll(':id', movieId),
      );
      
      return Movie.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch movies by genre
  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.moviesByGenre.replaceAll(':genre', genreId),
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      // Handle wrapped response
      final movies = response.data['movies'] ?? response.data['data'] ?? [];
      return (movies as List)
          .map((json) => Movie.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch featured movies for hero banner
  Future<List<Movie>> getFeaturedMovies() async {
    try {
      final response = await _dio.get(ApiEndpoints.featuredMovies);
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      final movies = response.data['movies'] ?? response.data['data'] ?? [];
      return (movies as List)
          .map((json) => Movie.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      // If featured endpoint doesn't exist, fall back to all movies
      if (e.response?.statusCode == 404) {
        final allMovies = await getAllMovies();
        // Return top 5 by popularity or vote average
        allMovies.sort((a, b) {
          final aScore = (a.popularity ?? 0) + (a.voteAverage ?? 0) * 10;
          final bScore = (b.popularity ?? 0) + (b.voteAverage ?? 0) * 10;
          return bScore.compareTo(aScore);
        });
        return allMovies.take(5).toList();
      }
      throw _handleDioError(e);
    }
  }

  /// Fetch movie metadata.json directly
  /// Useful as fallback or for additional data not in API response
  Future<Movie> getMovieMetadata(String movieId) async {
    try {
      final response = await _dio.get(ApiEndpoints.movieMetadata(movieId));
      return Movie.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Convert DioException to user-friendly error message
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet connection.');
      
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          return Exception('Movie not found.');
        } else if (statusCode == 500) {
          return Exception('Server error. Please try again later.');
        }
        return Exception('Failed to load movies (${statusCode ?? 'unknown error'}).');
      
      case DioExceptionType.connectionError:
        return Exception('Cannot connect to server. Please check if the backend is running.');
      
      default:
        return Exception('An unexpected error occurred: ${e.message}');
    }
  }
}

/// Provider for MovieRemoteDataSource
@riverpod
MovieRemoteDataSource movieRemoteDataSource(MovieRemoteDataSourceRef ref) {
  return MovieRemoteDataSource(ref.watch(dioProvider));
}
```

#### 3. Repository Pattern

**`lib/features/movies/domain/repositories/movie_repository.dart`**
```dart
import 'package:streamflix_v2/features/movies/data/models/movie.dart';

/// Abstract repository interface for movies
/// Following clean architecture principles - domain layer doesn't know about implementation
abstract class MovieRepository {
  Future<List<Movie>> getAllMovies();
  Future<Movie> getMovieById(String movieId);
  Future<List<Movie>> getMoviesByGenre(String genreId);
  Future<List<Movie>> getFeaturedMovies();
}
```

**`lib/features/movies/data/repositories/movie_repository_impl.dart`**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix_v2/features/movies/data/datasources/movie_remote_datasource.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';
import 'package:streamflix_v2/features/movies/domain/repositories/movie_repository.dart';

part 'movie_repository_impl.g.dart';

/// Concrete implementation of MovieRepository
/// In Phase 2, this just delegates to the remote data source
/// In future phases, we might add caching layer here
class MovieRepositoryImpl implements MovieRepository {
  final MovieRemoteDataSource _remoteDataSource;

  MovieRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Movie>> getAllMovies() async {
    return await _remoteDataSource.getAllMovies();
  }

  @override
  Future<Movie> getMovieById(String movieId) async {
    return await _remoteDataSource.getMovieById(movieId);
  }

  @override
  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    return await _remoteDataSource.getMoviesByGenre(genreId);
  }

  @override
  Future<List<Movie>> getFeaturedMovies() async {
    return await _remoteDataSource.getFeaturedMovies();
  }
}

/// Provider for MovieRepository
@riverpod
MovieRepository movieRepository(MovieRepositoryRef ref) {
  return MovieRepositoryImpl(
    ref.watch(movieRemoteDataSourceProvider),
  );
}
```

#### 4. Presentation Layer Providers

**`lib/features/movies/presentation/providers/movies_provider.dart`**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';
import 'package:streamflix_v2/features/movies/data/repositories/movie_repository_impl.dart';

part 'movies_provider.g.dart';

/// Provider for all movies list
/// Returns AsyncValue<List<Movie>> which handles loading/error/data states
@riverpod
Future<List<Movie>> allMovies(AllMoviesRef ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getAllMovies();
}

/// Provider for featured movies (hero banner)
@riverpod
Future<List<Movie>> featuredMovies(FeaturedMoviesRef ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getFeaturedMovies();
}

/// Provider for movies by genre
/// This is a family provider - it takes a genreId parameter
@riverpod
Future<List<Movie>> moviesByGenre(MoviesByGenreRef ref, String genreId) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getMoviesByGenre(genreId);
}

/// Provider for single movie detail
@riverpod
Future<Movie> movieDetail(MovieDetailRef ref, String movieId) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getMovieById(movieId);
}

/// Provider for grouped movies by genre
/// Returns a map of genre name to list of movies
/// Useful for home screen rows
@riverpod
Future<Map<String, List<Movie>>> moviesGroupedByGenre(
  MoviesGroupedByGenreRef ref,
) async {
  final allMovies = await ref.watch(allMoviesProvider.future);
  
  // Group movies by their genres
  final Map<String, List<Movie>> grouped = {};
  
  for (final movie in allMovies) {
    if (movie.genres == null || movie.genres!.isEmpty) continue;
    
    for (final genre in movie.genres!) {
      grouped.putIfAbsent(genre.name, () => []).add(movie);
    }
  }
  
  // Sort each genre list by popularity/rating
  for (final genreMovies in grouped.values) {
    genreMovies.sort((a, b) {
      final aScore = (a.popularity ?? 0) + (a.voteAverage ?? 0) * 10;
      final bScore = (b.popularity ?? 0) + (b.voteAverage ?? 0) * 10;
      return bScore.compareTo(aScore);
    });
  }
  
  return grouped;
}
```

**`lib/features/movies/presentation/providers/genre_provider.dart`**
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix_v2/features/movies/data/models/genre.dart';
import 'package:streamflix_v2/features/movies/presentation/providers/movies_provider.dart';

part 'genre_provider.g.dart';

/// Provider that extracts unique genres from all movies
@riverpod
Future<List<Genre>> allGenres(AllGenresRef ref) async {
  final movies = await ref.watch(allMoviesProvider.future);
  
  final Map<int, Genre> uniqueGenres = {};
  
  for (final movie in movies) {
    if (movie.genres != null) {
      for (final genre in movie.genres!) {
        uniqueGenres[genre.id] = genre;
      }
    }
  }
  
  final genres = uniqueGenres.values.toList();
  genres.sort((a, b) => a.name.compareTo(b.name));
  
  return genres;
}
```

#### 5. Testing Utility Screen

Create a temporary screen to test the data layer before building the full UI:

**`lib/features/movies/presentation/screens/test_data_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/core/widgets/app_image.dart';
import 'package:streamflix_v2/core/widgets/error_widget.dart';
import 'package:streamflix_v2/features/movies/presentation/providers/movies_provider.dart';

/// Temporary screen to test data fetching
/// Remove this file after Phase 2C when real screens are built
class TestDataScreen extends ConsumerWidget {
  const TestDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(allMoviesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Data Layer Test'),
        backgroundColor: AppColors.backgroundLight,
      ),
      body: moviesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.netflixRed,
          ),
        ),
        error: (error, stack) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(allMoviesProvider),
        ),
        data: (movies) {
          if (movies.isEmpty) {
            return const Center(
              child: Text(
                'No movies found',
                style: AppTextStyles.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            itemCount: movies.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Card(
                color: AppColors.backgroundCard,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      if (movie.fullPosterUrl != null)
                        AppImage(
                          imageUrl: movie.fullPosterUrl!,
                          width: 80,
                          height: 120,
                          borderRadius: BorderRadius.circular(4),
                        )
                      else
                        Container(
                          width: 80,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.movie,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              style: AppTextStyles.heading3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (movie.releaseYear != null)
                              Text(
                                movie.releaseYear!,
                                style: AppTextStyles.bodySmall,
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  movie.formattedRating,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (movie.genres != null && movie.genres!.isNotEmpty)
                              Text(
                                movie.genreList,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              movie.overview,
                              style: AppTextStyles.bodySmall,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Debug info
                            Text(
                              'ID: ${movie.id} | Runtime: ${movie.formattedRuntime ?? 'N/A'}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

### Files to Modify

**`lib/core/router/app_router.dart`**
```dart
// Add this import at the top:
import 'package:streamflix_v2/features/movies/presentation/screens/test_data_screen.dart';

// Replace the routes array with:
routes: [
  GoRoute(
    path: RouteNames.home,
    name: 'home',
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: const TestDataScreen(), // Temporary - replace with HomeScreen in Phase 2C
    ),
  ),
  // Comment out movie detail and watch routes for now
  // We'll uncomment them in Phase 2C/2D when screens are ready
  /*
  GoRoute(
    path: RouteNames.movieDetail,
    name: 'movieDetail',
    pageBuilder: (context, state) {
      final movieId = state.pathParameters['id']!;
      return MaterialPage(
        key: state.pageKey,
        child: MovieDetailScreen(movieId: movieId),
      );
    },
  ),
  GoRoute(
    path: RouteNames.watch,
    name: 'watch',
    pageBuilder: (context, state) {
      final movieId = state.pathParameters['id']!;
      return MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: WatchScreen(movieId: movieId),
      );
    },
  ),
  */
],
```

**`lib/core/network/api_endpoints.dart`**
```dart
// After fetching V1 API routes, update these constants with exact paths
// For now, these are reasonable defaults:

class ApiEndpoints {
  ApiEndpoints._();

  // Movie endpoints
  static const String movies = '/api/movies';
  static const String movieDetail = '/api/movies/:id';
  static const String moviesByGenre = '/api/movies/genre/:genre';
  static const String featuredMovies = '/api/movies/featured';
  
  // Streaming endpoints
  static const String stream = '/stream/:id';
  
  // Subtitle endpoints
  static const String subtitles = '/api/subtitles/:id';
  
  // Static file URL builders
  static String moviePoster(String movieId) => '/data/$movieId/poster.jpg';
  static String movieLogo(String movieId) => '/data/$movieId/logo.png';
  static String movieBackdrop(String movieId) => '/data/$movieId/backdrop.jpg';
  static String movieMetadata(String movieId) => '/data/$movieId/metadata.json';
  
  // Helper to get stream URL
  static String streamUrl(String movieId) => stream.replaceAll(':id', movieId);
}
```

**`docs/v1_api_contract.md`** (create this file)
```markdown
# StreamFlix V1 API Contract

## Base URL
- Development: `http://localhost:3000`
- Production: TBD

## Endpoints

### GET /api/movies
**Description:** Fetch all available movies

**Request:**
- Method: GET
- Headers: None required
- Query Parameters: None (update after V1 fetch)

**Response:**
```json
// UPDATE THIS AFTER FETCHING V1 RESPONSE
// Example structure (verify with actual V1):
[
  {
    "id": "550",
    "title": "Fight Club",
    "overview": "A ticking-time-bomb insomniac...",
    "release_date": "1999-10-15",
    "vote_average": 8.4,
    "vote_count": 26280,
    "poster_path": "/data/550/poster.jpg",
    "backdrop_path": "/data/550/backdrop.jpg",
    "logo_path": "/data/550/logo.png",
    "genres": [
      { "id": 18, "name": "Drama" }
    ],
    "runtime": 139,
    "tagline": "Mischief. Mayhem. Soap.",
    "file_id": "123456789",
    "access_hash": "987654321",
    "dc_id": 4,
    "file_size": 2147483648
  }
]
```

### GET /api/movies/:id
**Description:** Fetch detailed information for a specific movie

**Request:**
- Method: GET
- Path Parameters: `id` (movie ID)

**Response:**
```json
// Single movie object (same structure as array item above)
```

### GET /stream/:id
**Description:** Stream video file via V1 proxy (Phase 2 only)

**Request:**
- Method: GET
- Path Parameters: `id` (movie ID)
- Headers: `Range: bytes=0-524287` (optional, for seeking)

**Response:**
- Status: 206 Partial Content (if Range header present)
- Headers:
  - `Content-Type: video/mp4`
  - `Content-Range: bytes 0-524287/2147483648`
  - `Accept-Ranges: bytes`
- Body: Video chunk

### Static Files
**Pattern:** `/data/{movie_id}/{filename}`

Available files:
- `poster.jpg` - Movie poster (2:3 aspect ratio)
- `backdrop.jpg` - Backdrop/banner image (16:9 aspect ratio)
- `logo.png` - Transparent logo PNG
- `metadata.json` - Complete TMDB metadata

## Notes
- All image URLs in movie objects are relative paths (start with `/data/`)
- Dates are in ISO 8601 format: `YYYY-MM-DD`
- Ratings are on a scale of 0-10
- Runtime is in minutes
```

### Key Implementation Details

1. **Freezed Code Generation**  
   Every `@freezed` class requires three files:
   - `model_name.dart` - Your class definition
   - `model_name.freezed.dart` - Generated by `freezed` (immutability, copyWith, equality)
   - `model_name.g.dart` - Generated by `json_serializable` (JSON serialization)
   
   Never edit `.freezed.dart` or `.g.dart` manually.

2. **Riverpod Async Providers**  
   ```dart
   @riverpod
   Future<List<Movie>> allMovies(AllMoviesRef ref) async { ... }
   ```
   Automatically creates:
   - `allMoviesProvider` - The provider itself
   - Returns `AsyncValue<List<Movie>>` with three states:
     - `.when(loading: ..., error: ..., data: ...)`
     - `.isLoading` / `.hasError` / `.hasValue`
   
3. **Error Handling Pattern**  
   Dio errors are caught and transformed into user-friendly messages. The pattern:
   ```dart
   try {
     return await _dio.get(...);
   } on DioException catch (e) {
     throw _handleDioError(e);
   }
   ```
   This ensures all errors reach the UI as Exception objects with readable messages.

4. **Repository Pattern Benefits**  
   - Domain layer (`MovieRepository` interface) doesn't know about Dio or HTTP
   - Easy to mock for testing
   - Easy to swap implementation (e.g., add caching layer later)
   - Follows clean architecture principles

5. **Model Updates Required**  
   The `Movie` model above is a **template**. After fetching V1's actual metadata.json:
   - Update field names to match exactly (case-sensitive)
   - Add any missing fields V1 provides
   - Remove fields that don't exist in V1
   - Update `@JsonKey` annotations if V1 uses different naming (snake_case vs camelCase)

6. **Extension Methods**  
   `MovieX` extension provides computed properties without polluting the model:
   ```dart
   movie.fullPosterUrl  // Computed from posterPath + id
   movie.formattedRating  // "8.4" instead of 8.43289
   movie.genreList  // "Action, Thriller" instead of List<Genre>
   ```

### pubspec.yaml Changes
No new dependencies - all were added in Phase 2A.

### Commands to Run

```bash
# 1. Generate Freezed and Riverpod code
dart run build_runner build --delete-conflicting-outputs

# Expected output:
# - *.freezed.dart files for all models
# - *.g.dart files for all models
# - *_provider.g.dart for all Riverpod providers

# 2. Verify no build errors
flutter analyze

# 3. Run app with test data screen
flutter run -d chrome --dart-define=V1_BASE_URL=http://localhost:3000

# Make sure V1 backend is running first!
# If V1 is not running, you'll see connection error in the test screen
```

### Acceptance Criteria

1. ✅ `dart run build_runner build` completes without errors
2. ✅ All `.freezed.dart` and `.g.dart` files are generated
3. ✅ `flutter analyze` shows zero errors
4. ✅ App builds successfully for web and Android
5. ✅ `TestDataScreen` shows loading spinner on launch
6. ✅ After V1 responds, movie list appears with posters and titles
7. ✅ Each movie card shows: poster image, title, year, rating, genres, overview
8. ✅ Scrolling the list is smooth (no jank)
9. ✅ Pulling to refresh (or manual refresh) invalidates cache and re-fetches data
10. ✅ If V1 backend is stopped, error message appears: "Cannot connect to server..."
11. ✅ If V1 returns 404, error message appears: "Movie not found"
12. ✅ Clicking retry button on error screen re-attempts the fetch
13. ✅ Movie poster images load from V1's `/data/{id}/poster.jpg` URL
14. ✅ Console logs show Dio interceptor output for all HTTP requests
15. ✅ `docs/v1_api_contract.md` exists and documents all endpoints discovered from V1

### Debug Checklist

If the test screen shows errors:

**"Cannot connect to server"**
- ✓ Is V1 backend running? (`node server.js` in V1 directory)
- ✓ Is the correct port used? (default: 3000)
- ✓ On Android: did you use LAN IP instead of localhost?
- ✓ On Android: is device on the same WiFi network?

**"Unexpected response format"**
- ✓ Run the V1 API endpoint directly in browser or Postman
- ✓ Compare actual response to `Movie.fromJson` expectations
- ✓ Update `MovieRemoteDataSource.getAllMovies()` to handle V1's exact structure

**"FormatException: Invalid JSON"**
- ✓ V1 endpoint might be returning HTML error page instead of JSON
- ✓ Check V1 server logs for errors
- ✓ Verify endpoint path matches V1 routes exactly

**"type 'String' is not a subtype of type 'int'"**
- ✓ Movie model field types don't match V1 response
- ✓ Check if `id` is String in V1 but int in model (or vice versa)
- ✓ Update model annotations with `@JsonKey(fromJson: parseIdAsString)`

**Posters not loading**
- ✓ Check if V1 serves static files at `/data/{id}/poster.jpg`
- ✓ Verify `fullPosterUrl` extension method builds correct path
- ✓ Check browser DevTools Network tab for 404s

---

# PART 3: Phase 2C — UI Screens (Home + Detail)

## Phase 2C — UI Screens (Home + Detail)

### Goal
Build the complete Netflix-style user interface for browsing movies. The home screen features an auto-rotating hero banner, multiple horizontal movie rows organized by genre, and smooth scrolling interactions. The movie detail screen shows full metadata, high-quality imagery, and action buttons. After this phase, users can browse the entire catalog and navigate to movie details, but cannot play videos yet (that's Phase 2D).

### Prerequisites
- Phase 2B completed: all data providers working
- `TestDataScreen` successfully displays movie list from V1
- All models generate without errors
- Movie posters and backdrops load correctly from V1

### Fetch from Coding Agent
None required for this phase — all V1 data has been fetched in Phase 2B.

### Files to Create

#### 1. Home Screen

**`lib/features/movies/presentation/screens/home_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/widgets/error_widget.dart';
import 'package:streamflix_v2/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix_v2/features/movies/presentation/widgets/hero_banner.dart';
import 'package:streamflix_v2/features/movies/presentation/widgets/movie_row.dart';

/// Netflix-style home screen with hero banner and genre rows
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredMoviesAsync = ref.watch(featuredMoviesProvider);
    final groupedMoviesAsync = ref.watch(moviesGroupedByGenreProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false, // Let hero banner go under status bar
        child: CustomScrollView(
          slivers: [
            // Hero Banner Section
            SliverToBoxAdapter(
              child: featuredMoviesAsync.when(
                loading: () => const HeroBannerSkeleton(),
                error: (error, stack) => SizedBox(
                  height: 500,
                  child: AppErrorWidget(
                    message: 'Failed to load featured movies',
                    onRetry: () => ref.invalidate(featuredMoviesProvider),
                  ),
                ),
                data: (movies) {
                  if (movies.isEmpty) {
                    return const SizedBox(
                      height: 500,
                      child: Center(
                        child: Text('No featured movies available'),
                      ),
                    );
                  }
                  return HeroBanner(movies: movies);
                },
              ),
            ),

            // Movie Rows by Genre
            groupedMoviesAsync.when(
              loading: () => SliverToBoxAdapter(
                child: Column(
                  children: List.generate(
                    5,
                    (index) => const MovieRowSkeleton(),
                  ),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: AppErrorWidget(
                  message: 'Failed to load movies',
                  onRetry: () => ref.invalidate(moviesGroupedByGenreProvider),
                ),
              ),
              data: (groupedMovies) {
                if (groupedMovies.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('No movies available'),
                      ),
                    ),
                  );
                }

                // Convert map to list for stable ordering
                final genreEntries = groupedMovies.entries.toList();
                
                // Sort by genre name or prioritize certain genres
                genreEntries.sort((a, b) {
                  // Prioritize these genres at the top
                  const priority = [
                    'Action',
                    'Drama',
                    'Comedy',
                    'Thriller',
                    'Horror',
                    'Science Fiction',
                  ];
                  
                  final aIndex = priority.indexOf(a.key);
                  final bIndex = priority.indexOf(b.key);
                  
                  if (aIndex != -1 && bIndex != -1) {
                    return aIndex.compareTo(bIndex);
                  } else if (aIndex != -1) {
                    return -1;
                  } else if (bIndex != -1) {
                    return 1;
                  }
                  
                  return a.key.compareTo(b.key);
                });

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = genreEntries[index];
                      return MovieRow(
                        title: entry.key,
                        movies: entry.value,
                      );
                    },
                    childCount: genreEntries.length,
                  ),
                );
              },
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 48),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton for hero banner
class HeroBannerSkeleton extends StatelessWidget {
  const HeroBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final height = _getHeroHeight(context);
    
    return Container(
      height: height,
      color: AppColors.backgroundCard,
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.netflixRed,
        ),
      ),
    );
  }

  double _getHeroHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 600;
    if (width > 800) return 500;
    return 400;
  }
}
```

#### 2. Hero Banner Widget

**`lib/features/movies/presentation/widgets/hero_banner.dart`**
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/core/router/route_names.dart';
import 'package:streamflix_v2/core/widgets/app_image.dart';
import 'package:streamflix_v2/core/widgets/gradient_overlay.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';

/// Auto-rotating hero banner for featured movies
class HeroBanner extends StatefulWidget {
  final List<Movie> movies;
  final Duration rotationInterval;

  const HeroBanner({
    super.key,
    required this.movies,
    this.rotationInterval = const Duration(seconds: 6),
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoRotation();
  }

  void _startAutoRotation() {
    _timer = Timer.periodic(widget.rotationInterval, (timer) {
      if (!mounted) return;
      
      final nextPage = (_currentPage + 1) % widget.movies.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = _getHeroHeight(size.width);

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Page view with movie backdrops
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.movies.length,
            itemBuilder: (context, index) {
              return _HeroBannerSlide(
                movie: widget.movies[index],
                height: height,
              );
            },
          ),

          // Page indicators
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.movies.length,
                (index) => _PageIndicator(
                  isActive: index == _currentPage,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getHeroHeight(double width) {
    if (width > 1200) return AppDimensions.heroBannerHeightDesktop;
    if (width > 800) return AppDimensions.heroBannerHeightTablet;
    return AppDimensions.heroBannerHeightMobile;
  }
}

/// Single slide in the hero banner
class _HeroBannerSlide extends StatelessWidget {
  final Movie movie;
  final double height;

  const _HeroBannerSlide({
    required this.movie,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop image
        if (movie.fullBackdropUrl != null)
          AppImage(
            imageUrl: movie.fullBackdropUrl!,
            fit: BoxFit.cover,
          )
        else
          Container(color: AppColors.backgroundCard),

        // Dark gradient overlay
        const GradientOverlay.bottomDark(),

        // Content
        Positioned(
          left: isMobile ? 16 : 48,
          right: isMobile ? 16 : size.width * 0.4,
          bottom: isMobile ? 80 : 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo or Title
              if (movie.fullLogoUrl != null)
                AppImage(
                  imageUrl: movie.fullLogoUrl!,
                  height: isMobile ? 80 : 120,
                  fit: BoxFit.contain,
                )
              else
                Text(
                  movie.title,
                  style: isMobile
                      ? AppTextStyles.heroTitleMobile
                      : AppTextStyles.heroTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 16),

              // Genre tags
              if (movie.genres != null && movie.genres!.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: movie.genres!.take(3).map((genre) {
                    return Chip(
                      label: Text(
                        genre.name,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      backgroundColor: AppColors.backgroundCard,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // Overview (truncated)
              if (!isMobile)
                Text(
                  movie.overview,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  // Play button
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push(RouteNames.watchPath(movie.id));
                    },
                    icon: const Icon(Icons.play_arrow, size: 28),
                    label: Text(
                      'Play',
                      style: AppTextStyles.button,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.netflixRed,
                      foregroundColor: AppColors.textPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 32,
                        vertical: isMobile ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // More Info button
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push(RouteNames.movieDetailPath(movie.id));
                    },
                    icon: const Icon(Icons.info_outline, size: 24),
                    label: Text(
                      'More Info',
                      style: AppTextStyles.button,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.backgroundCard,
                      foregroundColor: AppColors.textPrimary,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 24,
                        vertical: isMobile ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page indicator dot
class _PageIndicator extends StatelessWidget {
  final bool isActive;

  const _PageIndicator({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.netflixRed : AppColors.textTertiary,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
```

#### 3. Movie Row Widget

**`lib/features/movies/presentation/widgets/movie_row.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/core/widgets/shimmer_box.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';
import 'package:streamflix_v2/features/movies/presentation/widgets/movie_card.dart';

/// Horizontal scrollable row of movie cards
class MovieRow extends StatelessWidget {
  final String title;
  final List<Movie> movies;

  const MovieRow({
    super.key,
    required this.title,
    required this.movies,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row title
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spaceMedium,
            right: AppDimensions.spaceMedium,
            top: AppDimensions.spaceLarge,
            bottom: AppDimensions.spaceSmall,
          ),
          child: Text(
            title,
            style: AppTextStyles.heading2,
          ),
        ),

        // Horizontal scrollable list
        SizedBox(
          height: AppDimensions.movieCardHeight + 60, // Card height + title space
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMedium,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < movies.length - 1
                      ? AppDimensions.spaceSmall
                      : 0,
                ),
                child: MovieCard(movie: movies[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Loading skeleton for movie row
class MovieRowSkeleton extends StatelessWidget {
  const MovieRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title skeleton
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spaceMedium,
            right: AppDimensions.spaceMedium,
            top: AppDimensions.spaceLarge,
            bottom: AppDimensions.spaceSmall,
          ),
          child: ShimmerBox(
            width: 150,
            height: 24,
            borderRadius: BorderRadius.circular(4),
          ),
        ),

        // Cards skeleton
        SizedBox(
          height: AppDimensions.movieCardHeight + 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMedium,
            ),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(
                  right: AppDimensions.spaceSmall,
                ),
                child: ShimmerBox(
                  width: AppDimensions.movieCardWidth,
                  height: AppDimensions.movieCardHeight,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

#### 4. Movie Card Widget

**`lib/features/movies/presentation/widgets/movie_card.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/core/router/route_names.dart';
import 'package:streamflix_v2/core/widgets/app_image.dart';
import 'package:streamflix_v2/core/widgets/gradient_overlay.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';

/// Movie poster card with hover effect
class MovieCard extends StatefulWidget {
  final Movie movie;
  final double? width;
  final double? height;

  const MovieCard({
    super.key,
    required this.movie,
    this.width,
    this.height,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width ?? AppDimensions.movieCardWidth;
    final height = widget.height ?? AppDimensions.movieCardHeight;

    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: () {
            context.push(RouteNames.movieDetailPath(widget.movie.id));
          },
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster image
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Poster
                        if (widget.movie.fullPosterUrl != null)
                          AppImage(
                            imageUrl: widget.movie.fullPosterUrl!,
                            width: width,
                            height: height,
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            color: AppColors.backgroundCard,
                            child: const Center(
                              child: Icon(
                                Icons.movie,
                                size: 48,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),

                        // Hover overlay with gradient
                        if (_isHovered) ...[
                          const GradientOverlay.card(),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.movie.title,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.movie.formattedRating,
                                      style: AppTextStyles.caption,
                                    ),
                                    if (widget.movie.releaseYear != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.movie.releaseYear!,
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Title below poster (always visible on mobile, hidden on hover for web)
                if (!_isHovered)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.spaceSmall,
                    ),
                    child: Text(
                      widget.movie.title,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

#### 5. Movie Detail Screen

**`lib/features/movies/presentation/screens/movie_detail_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/core/router/route_names.dart';
import 'package:streamflix_v2/core/widgets/app_image.dart';
import 'package:streamflix_v2/core/widgets/error_widget.dart';
import 'package:streamflix_v2/core/widgets/gradient_overlay.dart';
import 'package:streamflix_v2/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix_v2/features/movies/presentation/widgets/movie_detail_info.dart';
import 'package:streamflix_v2/features/movies/presentation/widgets/more_like_this_section.dart';

/// Full-screen movie detail page
class MovieDetailScreen extends ConsumerWidget {
  final String movieId;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieAsync = ref.watch(movieDetailProvider(movieId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: movieAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.netflixRed,
          ),
        ),
        error: (error, stack) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(movieDetailProvider(movieId)),
        ),
        data: (movie) {
          return CustomScrollView(
            slivers: [
              // Backdrop header with gradient
              SliverAppBar(
                expandedHeight: _getBackdropHeight(context),
                pinned: true,
                backgroundColor: AppColors.background,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                  tooltip: 'Back',
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Backdrop image
                      if (movie.fullBackdropUrl != null)
                        AppImage(
                          imageUrl: movie.fullBackdropUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(color: AppColors.backgroundCard),

                      // Gradient overlay
                      const GradientOverlay.bottomDark(),

                      // Logo positioned at bottom of backdrop
                      if (movie.fullLogoUrl != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: AppImage(
                            imageUrl: movie.fullLogoUrl!,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: Text(
                            movie.title,
                            style: AppTextStyles.heroTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Movie info section
              SliverToBoxAdapter(
                child: MovieDetailInfo(movie: movie),
              ),

              // "More Like This" section
              SliverToBoxAdapter(
                child: MoreLikeThisSection(movie: movie),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 48),
              ),
            ],
          );
        },
      ),
    );
  }

  double _getBackdropHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width > 1200) return size.height * 0.6;
    if (size.width > 800) return size.height * 0.5;
    return size.height * 0.4;
  }
}
```

#### 6. Movie Detail Info Widget

**`lib/features/movies/presentation/widgets/movie_detail_info.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/core/router/route_names.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';

/// Movie metadata and action buttons section
class MovieDetailInfo extends StatefulWidget {
  final Movie movie;

  const MovieDetailInfo({
    super.key,
    required this.movie,
  });

  @override
  State<MovieDetailInfo> createState() => _MovieDetailInfoState();
}

class _MovieDetailInfoState extends State<MovieDetailInfo> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(
        isMobile ? AppDimensions.spaceMedium : AppDimensions.spaceLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata row (year, runtime, rating)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (widget.movie.releaseYear != null)
                Text(
                  widget.movie.releaseYear!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              if (widget.movie.formattedRuntime != null) ...[
                Text(
                  '•',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                Text(
                  widget.movie.formattedRuntime!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              Text(
                '•',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.movie.formattedRating,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Genre chips
          if (widget.movie.genres != null && widget.movie.genres!.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.movie.genres!.map((genre) {
                return Chip(
                  label: Text(
                    genre.name,
                    style: AppTextStyles.bodySmall,
                  ),
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(
                    color: AppColors.textTertiary,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Description
          Text(
            widget.movie.overview,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            maxLines: _isDescriptionExpanded ? null : 3,
            overflow: _isDescriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),

          if (widget.movie.overview.length > 150)
            TextButton(
              onPressed: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              child: Text(
                _isDescriptionExpanded ? 'Show less' : 'More',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Play button (full width)
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push(RouteNames.watchPath(widget.movie.id));
              },
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text('Play'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.netflixRed,
                foregroundColor: AppColors.textPrimary,
                textStyle: AppTextStyles.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary actions row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Phase 5 - Add to My List functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('My List feature coming in Phase 5'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 24),
                  label: const Text('My List'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.textTertiary,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: AppTextStyles.buttonSmall,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Phase 5 - Rating functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rating feature coming in Phase 5'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.thumb_up_outlined, size: 24),
                  label: const Text('Rate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: AppColors.textTertiary,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: AppTextStyles.buttonSmall,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Additional info
          if (widget.movie.tagline != null && widget.movie.tagline!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '"${widget.movie.tagline}"',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

#### 7. More Like This Section

**`lib/features/movies/presentation/widgets/more_like_this_section.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';
import 'package:streamflix_v2/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix_v2/features/movies/presentation/widgets/movie_card.dart';

/// "More Like This" recommendations section
class MoreLikeThisSection extends ConsumerWidget {
  final Movie movie;

  const MoreLikeThisSection({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMoviesAsync = ref.watch(allMoviesProvider);

    return allMoviesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (allMovies) {
        final recommendations = _getRecommendations(allMovies);

        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'More Like This',
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 2 / 3.5, // Poster ratio + title space
                  crossAxisSpacing: AppDimensions.spaceSmall,
                  mainAxisSpacing: AppDimensions.spaceMedium,
                ),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  return MovieCard(movie: recommendations[index]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Get recommended movies based on genre overlap
  List<Movie> _getRecommendations(List<Movie> allMovies) {
    if (movie.genres == null || movie.genres!.isEmpty) {
      // No genres - return popular movies
      final sorted = List<Movie>.from(allMovies);
      sorted.sort((a, b) {
        final aScore = (a.popularity ?? 0) + (a.voteAverage ?? 0) * 10;
        final bScore = (b.popularity ?? 0) + (b.voteAverage ?? 0) * 10;
        return bScore.compareTo(aScore);
      });
      return sorted.where((m) => m.id != movie.id).take(6).toList();
    }

    final genreIds = movie.genres!.map((g) => g.id).toSet();

    // Score each movie by genre overlap
    final scored = allMovies
        .where((m) => m.id != movie.id) // Exclude current movie
        .map((m) {
      if (m.genres == null || m.genres!.isEmpty) return (m, 0.0);

      final overlap = m.genres!.where((g) => genreIds.contains(g.id)).length;
      final score = overlap.toDouble() +
          (m.voteAverage ?? 0) / 10 +
          (m.popularity ?? 0) / 100;
      return (m, score);
    }).toList();

    scored.sort((a, b) => b.$2.compareTo(a.$2));

    return scored.take(6).map((e) => e.$1).toList();
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    return 2;
  }
}
```

### Files to Modify

**`lib/core/router/app_router.dart`**
```dart
// Uncomment the movieDetail and watch routes that were commented in Phase 2B

import 'package:streamflix_v2/features/movies/presentation/screens/home_screen.dart';
import 'package:streamflix_v2/features/movies/presentation/screens/movie_detail_screen.dart';
// import for watch screen will be added in Phase 2D

// Update routes array:
routes: [
  GoRoute(
    path: RouteNames.home,
    name: 'home',
    pageBuilder: (context, state) => NoTransitionPage(
      key: state.pageKey,
      child: const HomeScreen(), // Changed from TestDataScreen
    ),
  ),
  GoRoute(
    path: RouteNames.movieDetail,
    name: 'movieDetail',
    pageBuilder: (context, state) {
      final movieId = state.pathParameters['id']!;
      return MaterialPage(
        key: state.pageKey,
        child: MovieDetailScreen(movieId: movieId),
      );
    },
  ),
  // Watch route still commented - Phase 2D will uncomment it
  /*
  GoRoute(
    path: RouteNames.watch,
    name: 'watch',
    pageBuilder: (context, state) {
      final movieId = state.pathParameters['id']!;
      return MaterialPage(
        key: state.pageKey,
        fullscreenDialog: true,
        child: WatchScreen(movieId: movieId),
      );
    },
  ),
  */
],
```

**Delete `lib/features/movies/presentation/screens/test_data_screen.dart`**  
No longer needed now that real screens exist.

### Key Implementation Details

1. **Hero Banner Auto-Rotation**  
   - Uses `PageController` for smooth page transitions
   - `Timer.periodic` triggers automatic page changes every 6 seconds
   - Animation duration is 800ms with `Curves.easeInOutCubic` for smooth motion
   - User can manually swipe to override auto-rotation
   - Timer is cancelled in `dispose()` to prevent memory leaks

2. **Responsive Layout**  
   ```dart
   final isMobile = MediaQuery.of(context).size.width < 600;
   final isTablet = size.width > 600 && size.width <= 1200;
   final isDesktop = size.width > 1200;
   ```
   - Hero banner height adjusts: 400px (mobile) → 500px (tablet) → 600px (desktop)
   - Text sizes scale down on mobile
   - Button padding reduces on smaller screens
   - Grid column count changes: 2 (mobile) → 3 (tablet) → 4 (desktop)

3. **Hover Effects (Web Only)**  
   - `MouseRegion` widget detects hover on web
   - On mobile, `MouseRegion` does nothing (no hover state exists)
   - `ScaleTransition` animates card scale from 1.0 to 1.05
   - Gradient overlay appears on hover to ensure text readability

4. **SliverAppBar with Backdrop**  
   - `expandedHeight` creates the collapsible backdrop section
   - `pinned: true` keeps the back button visible when scrolled
   - `FlexibleSpaceBar` handles the parallax scroll effect
   - Logo is positioned at bottom using `Positioned` widget

5. **Movie Recommendations Algorithm**  
   - If movie has genres: score by genre overlap + rating + popularity
   - Genre overlap weight is highest (direct match)
   - Rating and popularity are secondary factors
   - Returns top 6 matches excluding the current movie

6. **Performance Optimizations**  
   - `ListView.builder` only builds visible items (lazy loading)
   - `GridView.builder` with `shrinkWrap: true` inside `CustomScrollView`
   - `memCacheWidth` and `memCacheHeight` in `AppImage` prevent full-res decoding
   - Shimmer animation uses `SingleTickerProviderStateMixin` for efficiency

7. **Navigation Pattern**  
   - `context.push()` - Navigate forward (adds to stack)
   - `context.pop()` - Go back (removes from stack)
   - Routes use path parameters: `/movie/:id` extracts `id` from URL
   - Web URLs are bookmarkable: `streamflix.com/movie/550`

### pubspec.yaml Changes
None - all dependencies already added in Phase 2A.

### Commands to Run

```bash
# 1. Ensure code generation is up to date
dart run build_runner build --delete-conflicting-outputs

# 2. Run on web
flutter run -d chrome --dart-define=V1_BASE_URL=http://localhost:3000

# 3. Run on Android
flutter run --dart-define=V1_BASE_URL=http://192.168.1.100:3000

# 4. Hot reload is enabled - press 'r' to reload after UI changes
# Press 'R' (capital) for hot restart if state gets corrupted
```

### Acceptance Criteria

1. ✅ Home screen loads and displays a hero banner with a movie backdrop
2. ✅ Hero banner auto-rotates through 5 featured movies every 6 seconds
3. ✅ Page indicator dots at bottom of banner show which movie is active
4. ✅ "Play" button on hero banner navigates to watch screen (shows error for now - Phase 2D will fix)
5. ✅ "More Info" button on hero banner navigates to movie detail screen
6. ✅ At least 3 movie rows appear below the hero banner
7. ✅ Each row title matches a genre (e.g., "Action", "Drama", "Comedy")
8. ✅ Each row scrolls horizontally independently
9. ✅ Movie cards in rows display poster images from V1
10. ✅ On web: hovering over a movie card scales it to 1.05x and shows title overlay
11. ✅ On mobile: tapping a movie card navigates to detail screen
12. ✅ Movie detail screen shows backdrop at top with dark gradient
13. ✅ Movie logo (if available) displays over the backdrop
14. ✅ Metadata row shows: year, runtime, and rating
15. ✅ Genre chips display below metadata
16. ✅ Description text is truncated to 3 lines with "More" button to expand
17. ✅ "Play" button is full-width and red
18. ✅ "My List" and "Rate" buttons show snackbar message (Phase 5 placeholder)
19. ✅ "More Like This" section shows 6 recommended movies in a grid
20. ✅ Recommended movies share at least one genre with the current movie
21. ✅ Back button on detail screen returns to home
22. ✅ On web: browser back button works correctly
23. ✅ Scrolling on home screen is smooth with no jank
24. ✅ Scrolling on detail screen is smooth with backdrop parallax effect
25. ✅ All images load with shimmer placeholders during loading
26. ✅ If V1 backend is down, error widget appears with retry button
27. ✅ Clicking retry after network error successfully re-fetches data
28. ✅ App looks visually similar to Netflix (dark theme, red accents, clean layout)

### Visual Quality Checklist

**Home Screen:**
- [ ] Hero banner fills full viewport width
- [ ] Backdrop images are high quality (no pixelation)
- [ ] Gradient overlay smoothly transitions from transparent to black
- [ ] Movie logo is crisp and properly sized
- [ ] Genre tags have subtle background and rounded corners
- [ ] Page indicators are centered and animate smoothly
- [ ] Movie rows have consistent spacing (16px between cards)
- [ ] Row titles are bold and white
- [ ] Movie cards have 8px rounded corners
- [ ] Hover effect is smooth (200ms transition)

**Movie Detail Screen:**
- [ ] Backdrop fills top 50% of viewport
- [ ] Logo is positioned at bottom-left of backdrop
- [ ] Back button is always visible (pinned app bar)
- [ ] Metadata uses gray text (#B3B3B3)
- [ ] Genre chips have white border, transparent background
- [ ] Play button is Netflix red (#E50914)
- [ ] Secondary buttons have gray border
- [ ] "More Like This" grid has equal spacing
- [ ] Scroll behavior feels natural (not too fast or slow)

---
# PART 4: Phase 2D — Video Player + Subtitles

## Phase 2D — Video Player + Subtitles

### Goal
Implement a fully functional video player that streams movies from V1's backend using media_kit. The player features custom Netflix-style controls with auto-hide behavior, seek bar with buffered range visualization, fullscreen support, keyboard shortcuts (web), and subtitle rendering. After this phase, users can watch movies end-to-end on both web and Android with a polished, production-quality player experience.

### Prerequisites
- Phase 2C completed: home and detail screens fully functional
- All navigation routes working
- V1 backend streaming endpoint accessible at `/stream/:id`
- V1 backend returns correct HTTP headers for range requests

### Fetch from Coding Agent

```
╔══════════════════════════════════════════════════════════════════╗
║  FETCH FROM CODING AGENT — V1 Streaming Implementation (3 of 4) ║
╠══════════════════════════════════════════════════════════════════╣
║  "Show me the complete streaming route handler in V1. I need:   ║
║   1. The exact endpoint path (e.g., /stream/:id or /api/stream) ║
║   2. How the server handles Range requests                       ║
║   3. What headers the server sends in the response               ║
║   4. The Content-Type header value                               ║
║   5. Any authentication or token requirements                    ║
║   Show me the actual route code, not just descriptions."         ║
╚══════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════╗
║  FETCH FROM CODING AGENT — V1 Subtitle System (4 of 4)          ║
╠══════════════════════════════════════════════════════════════════╣
║  "Show me the subtitle endpoint and implementation. I need:      ║
║   1. The endpoint path and parameters (e.g., language code)      ║
║   2. Response format (SRT, WebVTT, or JSON?)                     ║
║   3. How to request specific language subtitles                  ║
║   4. What happens if no subtitles are available                  ║
║   5. Are subtitles fetched from subdl API or stored locally?     ║
║   Show me the route handler code."                               ║
╚══════════════════════════════════════════════════════════════════╝
```

**After fetching, update:**  
`docs/v1_api_contract.md` with streaming and subtitle endpoint details

### Files to Create

#### 1. Player Initialization

**`lib/core/config/player_config.dart`**
```dart
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
```

**`lib/main.dart`** (modify existing file)
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/config/player_config.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize media_kit BEFORE runApp
  PlayerConfig.initialize();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
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
          background: AppColors.background,
          surface: AppColors.backgroundLight,
          error: AppColors.error,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

#### 2. Player Provider

**`lib/features/player/presentation/providers/player_provider.dart`**
```dart
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix_v2/core/config/app_config.dart';
import 'package:streamflix_v2/features/movies/data/models/movie.dart';

part 'player_provider.g.dart';

/// Player state for a specific movie
class PlayerState {
  final Player player;
  final VideoController videoController;
  final bool isInitialized;
  final String? error;

  PlayerState({
    required this.player,
    required this.videoController,
    this.isInitialized = false,
    this.error,
  });

  PlayerState copyWith({
    Player? player,
    VideoController? videoController,
    bool? isInitialized,
    String? error,
  }) {
    return PlayerState(
      player: player ?? this.player,
      videoController: videoController ?? this.videoController,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }
}

/// Provider for video player instance
@riverpod
class MoviePlayer extends _$MoviePlayer {
  @override
  PlayerState build(String movieId) {
    // Create player instance
    final player = Player();
    final videoController = VideoController(player);
    
    // Clean up when provider is disposed
    ref.onDispose(() {
      debugPrint('🎬 Disposing player for movie $movieId');
      player.dispose();
    });

    return PlayerState(
      player: player,
      videoController: videoController,
    );
  }

  /// Initialize and start playback
  Future<void> play(Movie movie) async {
    try {
      debugPrint('🎬 Starting playback for: ${movie.title}');
      
      // Construct stream URL from V1 backend
      final streamUrl = '${AppConfig.v1BaseUrl}/stream/${movie.id}';
      debugPrint('🎬 Stream URL: $streamUrl');

      // Open media
      await state.player.open(
        Media(streamUrl),
        play: true, // Auto-play
      );

      // Update state
      state = state.copyWith(isInitialized: true);
      
      debugPrint('🎬 Playback started successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Player error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      state = state.copyWith(
        error: 'Failed to load video: ${e.toString()}',
      );
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await state.player.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await state.player.play();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await state.player.seek(position);
  }

  /// Toggle play/pause
  Future<void> playOrPause() async {
    if (state.player.state.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Set volume (0.0 to 100.0)
  Future<void> setVolume(double volume) async {
    await state.player.setVolume(volume.clamp(0.0, 100.0));
  }
}
```

#### 3. Watch Screen

**`lib/features/player/presentation/screens/watch_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/widgets/error_widget.dart';
import 'package:streamflix_v2/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix_v2/features/player/presentation/providers/player_provider.dart';
import 'package:streamflix_v2/features/player/presentation/widgets/player_controls.dart';

/// Full-screen video player screen
class WatchScreen extends ConsumerStatefulWidget {
  final String movieId;

  const WatchScreen({
    super.key,
    required this.movieId,
  });

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  bool _controlsVisible = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setLandscapeOrientation();
  }

  @override
  void dispose() {
    _restoreOrientation();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    // Wait for movie data to load
    final movieAsync = ref.read(movieDetailProvider(widget.movieId));
    
    movieAsync.whenData((movie) async {
      // Start playback
      final playerNotifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
      await playerNotifier.play(movie);
    });
  }

  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  void _exitPlayer() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final movieAsync = ref.watch(movieDetailProvider(widget.movieId));
    final playerState = ref.watch(moviePlayerProvider(widget.movieId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: movieAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.netflixRed,
          ),
        ),
        error: (error, stack) => AppErrorWidget(
          message: 'Failed to load movie details',
          onRetry: () {
            ref.invalidate(movieDetailProvider(widget.movieId));
            _initializePlayer();
          },
        ),
        data: (movie) {
          if (playerState.error != null) {
            return AppErrorWidget(
              message: playerState.error!,
              onRetry: () async {
                final notifier = ref.read(
                  moviePlayerProvider(widget.movieId).notifier,
                );
                await notifier.play(movie);
              },
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Video player
              Center(
                child: Video(
                  controller: playerState.videoController,
                  controls: NoVideoControls, // We use custom controls
                ),
              ),

              // Tap detector for showing/hiding controls
              GestureDetector(
                onTap: _toggleControls,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),

              // Custom controls overlay
              PlayerControls(
                movieId: widget.movieId,
                movieTitle: movie.title,
                visible: _controlsVisible,
                onVisibilityChanged: (visible) {
                  setState(() {
                    _controlsVisible = visible;
                  });
                },
                onExit: _exitPlayer,
                isFullscreen: _isFullscreen,
                onFullscreenToggle: () {
                  setState(() {
                    _isFullscreen = !_isFullscreen;
                  });
                  // Fullscreen logic here (platform-specific)
                },
              ),

              // Loading indicator while initializing
              if (!playerState.isInitialized)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.netflixRed,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading video...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

#### 4. Player Controls Widget

**`lib/features/player/presentation/widgets/player_controls.dart`**
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_dimensions.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';
import 'package:streamflix_v2/features/player/presentation/providers/player_provider.dart';
import 'package:streamflix_v2/features/player/presentation/widgets/seek_bar.dart';
import 'package:streamflix_v2/features/subtitles/presentation/widgets/subtitle_selector.dart';

/// Custom video player controls with auto-hide
class PlayerControls extends ConsumerStatefulWidget {
  final String movieId;
  final String movieTitle;
  final bool visible;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onExit;
  final bool isFullscreen;
  final VoidCallback onFullscreenToggle;

  const PlayerControls({
    super.key,
    required this.movieId,
    required this.movieTitle,
    required this.visible,
    required this.onVisibilityChanged,
    required this.onExit,
    required this.isFullscreen,
    required this.onFullscreenToggle,
  });

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  Timer? _hideTimer;
  bool _isDragging = false;

  @override
  void didUpdateWidget(PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.visible && !oldWidget.visible) {
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDragging && mounted) {
        widget.onVisibilityChanged(false);
      }
    });
  }

  void _onUserInteraction() {
    if (!widget.visible) {
      widget.onVisibilityChanged(true);
    }
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(moviePlayerProvider(widget.movieId));
    final player = playerState.player;

    // Listen to keyboard events on web
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          return _handleKeyPress(event);
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: widget.visible
            ? _buildControls(context, player)
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildControls(BuildContext context, player) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top bar (title + back button)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMedium),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: widget.onExit,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.movieTitle,
                      style: AppTextStyles.heading3.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Center play/pause button
          Center(
            child: StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                
                return GestureDetector(
                  onTap: () {
                    _onUserInteraction();
                    ref.read(moviePlayerProvider(widget.movieId).notifier)
                        .playOrPause();
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // Bottom controls (seek bar + buttons)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMedium),
              child: Column(
                children: [
                  // Seek bar
                  SeekBar(
                    movieId: widget.movieId,
                    onDragStart: () {
                      setState(() {
                        _isDragging = true;
                      });
                      _hideTimer?.cancel();
                    },
                    onDragEnd: () {
                      setState(() {
                        _isDragging = false;
                      });
                      _startHideTimer();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Control buttons row
                  Row(
                    children: [
                      // Play/Pause
                      StreamBuilder<bool>(
                        stream: player.stream.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _onUserInteraction();
                              ref.read(moviePlayerProvider(widget.movieId).notifier)
                                  .playOrPause();
                            },
                          );
                        },
                      ),

                      const SizedBox(width: 8),

                      // Time display
                      StreamBuilder<Duration>(
                        stream: player.stream.position,
                        builder: (context, positionSnapshot) {
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            builder: (context, durationSnapshot) {
                              final position = positionSnapshot.data ?? Duration.zero;
                              final duration = durationSnapshot.data ?? Duration.zero;
                              
                              return Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const Spacer(),

                      // Subtitle selector
                      SubtitleSelector(movieId: widget.movieId),

                      const SizedBox(width: 8),

                      // Volume
                      _buildVolumeControl(player),

                      const SizedBox(width: 8),

                      // Fullscreen toggle
                      IconButton(
                        icon: Icon(
                          widget.isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _onUserInteraction();
                          widget.onFullscreenToggle();
                        },
                        tooltip: widget.isFullscreen
                            ? 'Exit fullscreen'
                            : 'Fullscreen',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl(player) {
    return PopupMenuButton<void>(
      icon: const Icon(Icons.volume_up, color: Colors.white),
      tooltip: 'Volume',
      color: AppColors.backgroundCard,
      offset: const Offset(0, -200),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            height: 150,
            child: StreamBuilder<double>(
              stream: player.stream.volume,
              builder: (context, snapshot) {
                final volume = snapshot.data ?? 100.0;
                
                return RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: volume,
                      min: 0.0,
                      max: 100.0,
                      activeColor: AppColors.netflixRed,
                      inactiveColor: AppColors.textTertiary,
                      onChanged: (value) {
                        ref.read(moviePlayerProvider(widget.movieId).notifier)
                            .setVolume(value);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  KeyEventResult _handleKeyPress(KeyDownEvent event) {
    _onUserInteraction();

    final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
    final player = ref.read(moviePlayerProvider(widget.movieId)).player;

    // Space = play/pause
    if (event.logicalKey == LogicalKeyboardKey.space) {
      notifier.playOrPause();
      return KeyEventResult.handled;
    }

    // Left arrow = seek -10s
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final currentPos = player.state.position;
      final newPos = currentPos - const Duration(seconds: 10);
      notifier.seek(newPos.isNegative ? Duration.zero : newPos);
      return KeyEventResult.handled;
    }

    // Right arrow = seek +10s
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final currentPos = player.state.position;
      final duration = player.state.duration;
      final newPos = currentPos + const Duration(seconds: 10);
      notifier.seek(newPos > duration ? duration : newPos);
      return KeyEventResult.handled;
    }

    // F = fullscreen toggle
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      widget.onFullscreenToggle();
      return KeyEventResult.handled;
    }

    // M = mute toggle
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      final currentVolume = player.state.volume;
      notifier.setVolume(currentVolume > 0 ? 0 : 100);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
```

#### 5. Seek Bar Widget

**`lib/features/player/presentation/widgets/seek_bar.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/features/player/presentation/providers/player_provider.dart';

/// Custom seek bar with buffered range visualization
class SeekBar extends ConsumerStatefulWidget {
  final String movieId;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const SeekBar({
    super.key,
    required this.movieId,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(moviePlayerProvider(widget.movieId));
    final player = playerState.player;

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (context, durationSnapshot) {
            return StreamBuilder<Duration>(
              stream: player.stream.buffer,
              builder: (context, bufferSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                final duration = durationSnapshot.data ?? Duration.zero;
                final buffer = bufferSnapshot.data ?? Duration.zero;

                final durationMs = duration.inMilliseconds;
                if (durationMs == 0) {
                  return const LinearProgressIndicator(
                    backgroundColor: AppColors.textTertiary,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.netflixRed,
                    ),
                  );
                }

                final positionValue = position.inMilliseconds / durationMs;
                final bufferValue = buffer.inMilliseconds / durationMs;
                final sliderValue = _dragValue ?? positionValue;

                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: AppColors.netflixRed,
                    inactiveTrackColor: AppColors.textTertiary.withOpacity(0.3),
                    thumbColor: AppColors.netflixRed,
                    overlayColor: AppColors.netflixRed.withOpacity(0.3),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Buffered range indicator
                      Positioned.fill(
                        child: LinearProgressIndicator(
                          value: bufferValue.clamp(0.0, 1.0),
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textSecondary.withOpacity(0.5),
                          ),
                        ),
                      ),
                      
                      // Main slider
                      Slider(
                        value: sliderValue.clamp(0.0, 1.0),
                        onChanged: (value) {
                          setState(() {
                            _dragValue = value;
                          });
                        },
                        onChangeStart: (value) {
                          widget.onDragStart?.call();
                          setState(() {
                            _dragValue = value;
                          });
                        },
                        onChangeEnd: (value) {
                          final seekPosition = Duration(
                            milliseconds: (value * durationMs).round(),
                          );
                          ref.read(moviePlayerProvider(widget.movieId).notifier)
                              .seek(seekPosition);
                          
                          setState(() {
                            _dragValue = null;
                          });
                          
                          widget.onDragEnd?.call();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
```

#### 6. Subtitle Models

**`lib/features/subtitles/data/models/subtitle_track.dart`**
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtitle_track.freezed.dart';
part 'subtitle_track.g.dart';

/// Available subtitle track
@freezed
class SubtitleTrack with _$SubtitleTrack {
  const factory SubtitleTrack({
    required String language,
    required String languageCode,
    required String url,
    @Default(false) bool isDefault,
  }) = _SubtitleTrack;

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) =>
      _$SubtitleTrackFromJson(json);
}
```

**`lib/features/subtitles/data/models/subtitle_cue.dart`**
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtitle_cue.freezed.dart';

/// Individual subtitle cue with timing
@freezed
class SubtitleCue with _$SubtitleCue {
  const factory SubtitleCue({
    required int index,
    required Duration start,
    required Duration end,
    required String text,
  }) = _SubtitleCue;

  const SubtitleCue._();

  /// Check if this cue should be displayed at given position
  bool isActiveAt(Duration position) {
    return position >= start && position <= end;
  }
}
```

#### 7. Subtitle Selector

**`lib/features/subtitles/presentation/widgets/subtitle_selector.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix_v2/core/constants/app_colors.dart';
import 'package:streamflix_v2/core/constants/app_text_styles.dart';

/// Subtitle language selector button
class SubtitleSelector extends ConsumerWidget {
  final String movieId;

  const SubtitleSelector({
    super.key,
    required this.movieId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Phase 2D - Implement subtitle fetching from V1
    // For now, show a placeholder button
    
    return IconButton(
      icon: const Icon(Icons.closed_caption_outlined, color: Colors.white),
      onPressed: () {
        _showSubtitleMenu(context);
      },
      tooltip: 'Subtitles',
    );
  }

  void _showSubtitleMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'Subtitles',
          style: AppTextStyles.heading3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Off', style: AppTextStyles.bodyMedium),
              leading: Radio<String>(
                value: 'off',
                groupValue: 'off', // TODO: Track selected subtitle
                onChanged: (value) {
                  Navigator.pop(context);
                },
                activeColor: AppColors.netflixRed,
              ),
            ),
            // TODO: Add subtitle language options from V1 API
            const ListTile(
              title: Text(
                'Subtitle support coming soon',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

### Files to Modify

**`lib/core/router/app_router.dart`**
```dart
// Uncomment the watch route
import 'package:streamflix_v2/features/player/presentation/screens/watch_screen.dart';

// In routes array:
GoRoute(
  path: RouteNames.watch,
  name: 'watch',
  pageBuilder: (context, state) {
    final movieId = state.pathParameters['id']!;
    return MaterialPage(
      key: state.pageKey,
      fullscreenDialog: true,
      child: WatchScreen(movieId: movieId),
    );
  },
),
```

**`pubspec.yaml`**
```yaml
dependencies:
  # ... existing dependencies ...
  
  # Video playback
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_video: ^1.0.4  # Web support

dev_dependencies:
  # ... existing dev_dependencies ...

# Platform-specific dependencies (already handled by media_kit)
```

**`android/app/build.gradle`**
```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.yourname.streamflix.streamflix_v2"
        minSdkVersion 21  // media_kit requires API 21+
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
```

**`android/app/src/main/AndroidManifest.xml`**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Internet permission for streaming -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application
        android:label="StreamFlix"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true"> <!-- Allow HTTP for local dev -->
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:screenOrientation="userLandscape"> <!-- Landscape for player -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
            />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### Key Implementation Details

1. **media_kit Initialization**  
   `MediaKit.ensureInitialized()` MUST be called before any Player instance is created. Best practice is to call it in `main()` before `runApp()`.

2. **Player Lifecycle**  
   ```dart
   // Player is created when provider is first read
   final player = Player();
   
   // Disposed automatically when provider is disposed
   ref.onDispose(() {
     player.dispose();
   });
   ```
   Never dispose a player manually unless you're 100% sure the provider won't be accessed again.

3. **Streaming URL Format**  
   ```dart
   final streamUrl = '${AppConfig.v1BaseUrl}/stream/${movie.id}';
   // Example: http://localhost:3000/stream/550
   ```
   V1 must return these headers:
   - `Content-Type: video/mp4` (or correct video MIME type)
   - `Accept-Ranges: bytes`
   - `Content-Range: bytes START-END/TOTAL` (for range requests)
   - `Content-Length: SIZE` (for full file request)

4. **Controls Auto-Hide**  
   - Controls show on tap
   - 3-second timer starts
   - Timer resets on any user interaction
   - Timer is cancelled during seek drag
   - Controls fade out after 3 seconds of inactivity

5. **Keyboard Shortcuts (Web Only)**  
   | Key | Action |
   |-----|--------|
   | Space | Play/Pause |
   | ← | Seek -10s |
   | → | Seek +10s |
   | F | Toggle fullscreen |
   | M | Mute/Unmute |

6. **Seek Bar Behavior**  
   - Gray background = total duration
   - Light gray fill = buffered content
   - Red fill = current playback position
   - User can drag to any position
   - `onChangeStart` → pause auto-hide timer
   - `onChangeEnd` → seek player, resume auto-hide timer

7. **Fullscreen Handling**  
   - On entry: set landscape orientation, hide system UI
   - On exit: restore portrait, show system UI
   - Web: use browser's fullscreen API (not implemented in this phase)
   - Android: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`

8. **Error Handling**  
   Common errors:
   - Network timeout → "Connection timeout. Check your internet."
   - 404 from V1 → "Movie not found."
   - Invalid video format → "Unsupported video format."
   - All errors show `AppErrorWidget` with retry button

9. **Subtitle Placeholder**  
   Phase 2D includes subtitle UI but subtitle fetching/parsing is left as TODO. Actual implementation depends on V1's subtitle endpoint format discovered in the fetch step.

### pubspec.yaml Changes

```yaml
dependencies:
  # Add these:
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_video: ^1.0.4
```

### Commands to Run

```bash
# 1. Add video player dependencies
flutter pub add media_kit media_kit_video media_kit_libs_video

# 2. Generate code for new models
dart run build_runner build --delete-conflicting-outputs

# 3. Clean build (important for platform-specific native code)
flutter clean
flutter pub get

# 4. Run on web
flutter run -d chrome --dart-define=V1_BASE_URL=http://localhost:3000

# 5. Run on Android
flutter run --dart-define=V1_BASE_URL=http://192.168.1.100:3000
```

**IMPORTANT:** After adding media_kit, you MUST do `flutter clean` and rebuild. media_kit includes native libraries that need to be compiled into the app.

### Acceptance Criteria

1. ✅ App builds successfully after adding media_kit dependencies
2. ✅ Clicking "Play" button on home screen hero banner navigates to player
3. ✅ Clicking "Play" button on detail screen navigates to player
4. ✅ Player screen shows "Loading video..." while initializing
5. ✅ Video starts playing automatically when loaded
6. ✅ On web: video displays in center of black screen
7. ✅ On Android: video displays in landscape orientation
8. ✅ Tapping video shows controls overlay
9. ✅ Controls overlay fades out after 3 seconds of no interaction
10. ✅ Tapping again while controls are hidden shows them again
11. ✅ Play/pause button (center circle) toggles playback
12. ✅ Play/pause button (bottom bar) toggles playback
13. ✅ Seek bar moves smoothly as video plays
14. ✅ Dragging seek bar jumps to correct position in video
15. ✅ Buffered range shows as light gray fill on seek bar
16. ✅ Time display shows current position / total duration (e.g., "12:34 / 1:23:45")
17. ✅ Back button exits player and returns to previous screen
18. ✅ On web: Space key toggles play/pause
19. ✅ On web: Left arrow key seeks backward 10 seconds
20. ✅ On web: Right arrow key seeks forward 10 seconds
21. ✅ On web: F key toggles fullscreen (if implemented)
22. ✅ On web: M key mutes/unmutes
23. ✅ Volume control opens popup slider
24. ✅ Changing volume slider updates audio level immediately
25. ✅ Subtitle button shows dialog (even if no subtitles available yet)
26. ✅ Fullscreen button is visible (functionality may be placeholder)
27. ✅ On Android: screen stays landscape while playing
28. ✅ On Android: status bar and navigation bar hide in immersive mode
29. ✅ On Android: device back button exits player
30. ✅ If V1 streaming fails, error widget appears with retry button
31. ✅ Clicking retry attempts to reload the video
32. ✅ If network disconnects mid-playback, video buffers and shows loading
33. ✅ When network reconnects, playback resumes from buffered position
34. ✅ Closing and reopening player starts from beginning (no resume yet - Phase 5)
35. ✅ Player disposes correctly when exiting (no memory leaks)

### Testing Checklist

**Web Testing:**
```bash
# 1. Start V1 backend
cd streamflix-v1
node server.js

# 2. Start Flutter web
cd streamflix-v2
flutter run -d chrome --dart-define=V1_BASE_URL=http://localhost:3000

# 3. Open browser DevTools → Network tab
# 4. Play a movie
# 5. Verify:
#    - Initial request: GET /stream/ID with Range: bytes=0-
#    - Response: 206 Partial Content
#    - Subsequent requests as you seek
```

**Android Testing:**
```bash
# 1. Find your machine's LAN IP
# macOS/Linux: ifconfig | grep "inet "
# Windows: ipconfig

# 2. Start V1 with network binding
cd streamflix-v1
# Update server.js to bind to 0.0.0.0 instead of localhost if needed

# 3. Run Flutter on device
cd streamflix-v2
flutter run --dart-define=V1_BASE_URL=http://192.168.1.100:3000

# 4. Check logcat for network requests
adb logcat | grep -i "http"
```

**Common Issues:**

**Video doesn't play:**
- ✓ Check V1 server logs - is the stream endpoint being called?
- ✓ Check browser DevTools Network tab - what status code?
- ✓ Verify V1 returns correct headers (Content-Type, Accept-Ranges)
- ✓ Try the stream URL directly in browser - does it download?

**"ERR_CONNECTION_REFUSED" on Android:**
- ✓ Use LAN IP (192.168.x.x), NOT localhost
- ✓ Device and computer on same WiFi network
- ✓ Firewall not blocking port 3000
- ✓ V1 server bound to 0.0.0.0, not 127.0.0.1

**Video buffers constantly:**
- ✓ File too large for network speed (2GB+ files need fast connection)
- ✓ V1 GramJS might be slow fetching from Telegram
- ✓ Check V1 server CPU usage - is it maxed out?

**Controls don't hide:**
- ✓ Check if `_hideTimer` is being cancelled somewhere
- ✓ Verify `_isDragging` is reset to false after drag end
- ✓ Add debug print in timer callback to verify it fires

**Audio but no video (or vice versa):**
- ✓ Video file might have unsupported codec
- ✓ media_kit logs will show codec errors
- ✓ Check with: `flutter run --verbose`

---

## Phase 2 Complete! 🎉

After Phase 2D acceptance criteria pass, you have:
- ✅ A fully working Netflix-style streaming app
- ✅ Beautiful UI with hero banner and genre rows
- ✅ Movie detail pages with metadata
- ✅ Working video player with custom controls
- ✅ Smooth navigation and responsive layout
- ✅ Support for both web and Android

**The app is now production-ready for private use!**

Users can browse and watch movies. The only limitation is that all video bytes flow through your V1 server (bandwidth cost).

---
