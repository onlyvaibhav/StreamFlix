import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/network/connectivity_service.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/presentation/providers/api_genres_provider.dart';
import 'package:streamflix/features/genres/presentation/widgets/genre_card.dart';
import 'package:streamflix/features/shared/presentation/widgets/shimmer_loading.dart';

class GenresScreen extends ConsumerStatefulWidget {
  const GenresScreen({super.key});

  @override
  ConsumerState<GenresScreen> createState() => _GenresScreenState();
}

class _GenresScreenState extends ConsumerState<GenresScreen> {
  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    if (isOffline) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Genres', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => context.push(RouteNames.search),
            ),
          ],
        ),
        body: AppErrorWidget(
          error: 'offline',
          onRetry: () => ref.invalidate(apiGenresProvider),
        ),
      );
    }

    final genresAsync = ref.watch(apiGenresProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: genresAsync.when(
          data: (genres) {
            if (genres.isEmpty) {
              return const Center(
                child: Text('No genres found', style: TextStyle(color: Colors.white)),
              );
            }
            
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Explore Genres',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search, color: Colors.white, size: 28),
                              onPressed: () => context.push(RouteNames.search),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Discover content by genre',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 16 / 9,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final genre = genres[index];
                        return GenreCard(
                          genre: genre,
                          onTap: () {
                            context.push(
                              Uri(
                                path: RouteNames.genreDetailPath(genre.slug),
                                queryParameters: {'name': genre.name},
                              ).toString()
                            );
                          },
                        );
                      },
                      childCount: genres.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
          loading: () => const _GenresSkeleton(),
          error: (error, stack) => AppErrorWidget(
            error: error.toString(),
            onRetry: () => ref.invalidate(apiGenresProvider),
          ),
        ),
      ),
    );
  }
}

class _GenresSkeleton extends StatelessWidget {
  const _GenresSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(child: SizedBox(width: 200, height: 40)),
                SizedBox(height: 12),
                ShimmerLoading(child: SizedBox(width: 150, height: 20)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const ShimmerLoading(
                    child: SizedBox(width: double.infinity, height: double.infinity),
                  ),
                );
              },
              childCount: 10,
            ),
          ),
        ),
      ],
    );
  }
}
