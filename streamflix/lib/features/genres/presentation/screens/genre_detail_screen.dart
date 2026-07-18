import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_row.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/shared/presentation/widgets/shimmer_loading.dart';

class GenreDetailScreen extends ConsumerWidget {
  final String slug;
  final String genreName;

  const GenreDetailScreen({
    super.key,
    required this.slug,
    required this.genreName,
  });

  String _formatRowTitle(String key) {
    switch (key) {
      case 'popular':
        return 'Popular in $genreName';
      case 'topRated':
        return 'Top Rated $genreName';
      case 'newItems':
        return 'New in $genreName';
      case 'hiddenGems':
        return 'Hidden Gems';
      case 'multiAudioInGenre':
        return 'Multi Audio in $genreName';
      case 'recentlyAdded':
        return 'Recently Added';
      default:
        // capitalize first letter
        return key.substring(0, 1).toUpperCase() + key.substring(1);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curatedAsync = ref.watch(curatedContentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: curatedAsync.when(
        data: (curated) {
          final sections = curated.genresPage.sections[slug];
          
          if (sections == null || sections.isEmpty) {
            return _buildEmpty(context);
          }

          // Find a backdrop for the hero banner (from popular or any first available row)
          String? heroImage;
          for (final row in sections.values) {
            final withBackdrop = row.where((m) => m.fullBackdropUrl != null);
            if (withBackdrop.isNotEmpty) {
              heroImage = withBackdrop.first.fullBackdropUrl;
              break;
            }
          }

          // Calculate total titles
          final totalTitles = curated.genresPage.genres
                  .where((g) => g.slug == slug)
                  .firstOrNull
                  ?.count ?? 0;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.background,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (heroImage != null)
                        AppImage(
                          imageUrl: heroImage,
                          fit: BoxFit.cover,
                        ),
                      // Gradient to fade into the background color
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.background.withValues(alpha: 0.4),
                              AppColors.background.withValues(alpha: 0.8),
                              AppColors.background,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              genreName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 4.0,
                                    color: Colors.black87,
                                  ),
                                ],
                              ),
                            ),
                            if (totalTitles > 0)
                              Text(
                                '$totalTitles titles available',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Movie Rows
              ...sections.entries.where((e) => e.value.isNotEmpty).map((entry) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: MovieRow(
                      title: _formatRowTitle(entry.key),
                      movies: entry.value,
                    ),
                  ),
                );
              }),
              
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
        loading: () => const _GenreDetailSkeleton(),
        error: (error, stack) => AppErrorWidget(
          error: error.toString(),
          onRetry: () => ref.invalidate(curatedContentProvider),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(genreName),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'No titles found for this genre.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}

class _GenreDetailSkeleton extends StatelessWidget {
  const _GenreDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 300.0,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.background,
          flexibleSpace: FlexibleSpaceBar(
            background: ShimmerLoading(
              child: Container(color: Colors.white),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: MovieRowSkeleton(),
              );
            },
            childCount: 4,
          ),
        ),
      ],
    );
  }
}
