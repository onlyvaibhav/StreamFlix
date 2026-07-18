import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/router/navigation_shell.dart';
import 'package:streamflix/features/movies/presentation/screens/home_screen.dart';
import 'package:streamflix/features/movies/presentation/screens/movie_detail_screen.dart';
import 'package:streamflix/features/player/presentation/screens/watch_screen.dart';
import 'package:streamflix/features/library/presentation/screens/movies_catalog_screen.dart';
import 'package:streamflix/features/library/presentation/screens/tv_catalog_screen.dart';
import 'package:streamflix/features/search/presentation/screens/search_screen.dart';
import 'package:streamflix/features/genres/presentation/screens/genres_screen.dart';
import 'package:streamflix/features/genres/presentation/screens/genre_detail_screen.dart';
import 'package:streamflix/features/profile/presentation/screens/profile_screen.dart';
import 'package:streamflix/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:streamflix/features/auth/presentation/screens/login_screen.dart';
import 'package:streamflix/features/auth/presentation/providers/auth_provider.dart';
import 'package:streamflix/features/downloads/presentation/screens/series_downloads_screen.dart';
import 'package:streamflix/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:streamflix/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:streamflix/features/splash/presentation/screens/splash_screen.dart';

part 'app_router.g.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(Ref ref) {
  final isAuthenticated = ref.watch(authStateProvider);
  final hasSeenOnboarding = ref.watch(onboardingStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isGoingToSplash = state.matchedLocation == RouteNames.splash;
      if (isGoingToSplash) return null;

      final isGoingToLogin = state.matchedLocation == RouteNames.login;
      final isGoingToOnboarding = state.matchedLocation == RouteNames.onboarding;

      if (!hasSeenOnboarding && !isGoingToOnboarding) {
        return RouteNames.onboarding;
      }
      
      if (hasSeenOnboarding && isGoingToOnboarding) {
         return isAuthenticated ? RouteNames.home : RouteNames.login;
      }

      if (hasSeenOnboarding && !isAuthenticated && !isGoingToLogin) {
        return RouteNames.login;
      }
      
      if (hasSeenOnboarding && isAuthenticated && isGoingToLogin) {
        return RouteNames.home;
      }
      
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return NavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.home,
                name: 'home',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.genres,
                name: 'genres',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const GenresScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.tvShows,
                name: 'tvShows',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const TvCatalogScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.movies,
                name: 'movies',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const MoviesCatalogScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.downloads,
                name: 'downloads',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const DownloadsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: RouteNames.seriesDownloads,
                    name: 'seriesDownloads',
                    pageBuilder: (context, state) {
                      final seriesId = state.pathParameters['seriesId']!;
                      final showTitle = state.uri.queryParameters['showTitle'] ?? 'Episodes';
                      return MaterialPage(
                        key: state.pageKey,
                        child: SeriesDownloadsScreen(seriesId: seriesId, showTitle: showTitle),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.profile,
                name: 'profile',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
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
        path: RouteNames.genreDetail,
        name: 'genreDetail',
        pageBuilder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final genreName = state.uri.queryParameters['name'] ?? 'Genre';
          return MaterialPage(
            key: state.pageKey,
            child: GenreDetailScreen(slug: slug, genreName: genreName),
          );
        },
      ),
      GoRoute(
        path: RouteNames.watch,
        name: 'watch',
        pageBuilder: (context, state) {
          final movieId = state.pathParameters['id']!;
          final startTimeStr = state.uri.queryParameters['startTime'];
          final startTime = startTimeStr != null ? int.tryParse(startTimeStr) : null;
          return MaterialPage(
            key: state.pageKey,
            child: WatchScreen(movieId: movieId, startTime: startTime),
          );
        },
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.search,
        name: 'search',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: const SearchScreen(),
        ),
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
