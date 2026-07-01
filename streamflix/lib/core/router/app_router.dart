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
import 'package:streamflix/features/profile/presentation/screens/profile_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: RouteNames.home,
    debugLogDiagnostics: true,
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
                path: RouteNames.search,
                name: 'search',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SearchScreen(),
                ),
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
        path: RouteNames.watch,
        name: 'watch',
        pageBuilder: (context, state) {
          final movieId = state.pathParameters['id']!;
          return MaterialPage(
            key: state.pageKey,
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
