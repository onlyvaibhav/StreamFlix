import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/core/network/connectivity_service.dart';
import 'package:streamflix/features/movies/presentation/widgets/hero_banner.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_row.dart';
import 'package:streamflix/features/movies/presentation/widgets/premium_app_bar.dart';

class MoviesCatalogScreen extends ConsumerStatefulWidget {
  const MoviesCatalogScreen({super.key});

  @override
  ConsumerState<MoviesCatalogScreen> createState() => _MoviesCatalogScreenState();
}

class _MoviesCatalogScreenState extends ConsumerState<MoviesCatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _scrollOffset.value = _scrollController.offset;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    if (isOffline) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: AppErrorWidget(
          error: 'offline', // State handled correctly inside AppErrorWidget
          onRetry: () => ref.invalidate(curatedContentProvider),
        ),
      );
    }

    final curatedAsync = ref.watch(curatedContentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main scrollable content
          Positioned.fill(
            child: curatedAsync.when(
              loading: () => ListView(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  HeroBannerSkeleton(),
                  MovieRowSkeleton(),
                  MovieRowSkeleton(),
                ],
              ),
              error: (error, stack) => AppErrorWidget(
                error: error,
                onRetry: () => ref.invalidate(curatedContentProvider),
              ),
              data: (curated) {
                final homepage = curated.homepage;
                
                // Filter all sections to only display type == 'movie'
                final movieHeroItems = homepage.hero.where((i) => i.type == 'movie').toList();
                final trendingMovies = homepage.trending.where((i) => i.type == 'movie').toList();
                final recentlyAddedMovies = homepage.recentlyAdded.where((i) => i.type == 'movie').toList();
                final topRatedMovies = homepage.topRated.where((i) => i.type == 'movie').toList();

                final List<Widget> sliverItems = [];

                // Hero banner of movies
                sliverItems.add(
                  SliverToBoxAdapter(
                    child: movieHeroItems.isEmpty
                        ? const SizedBox(
                            height: 400,
                            child: Center(
                              child: Text('Featured Movie Loading...'),
                            ),
                          )
                        : HeroBanner(movies: movieHeroItems),
                  ),
                );

                // Movie categories
                if (trendingMovies.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(title: 'Trending Movies', movies: trendingMovies),
                    ),
                  );
                }

                if (recentlyAddedMovies.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(title: 'New Releases', movies: recentlyAddedMovies),
                    ),
                  );
                }

                if (topRatedMovies.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(title: 'Top Rated Movies', movies: topRatedMovies),
                    ),
                  );
                }

                // Custom dynamic genre lists filtered by movie type
                homepage.rows.forEach((key, list) {
                  final moviesInGenre = list.where((i) => i.type == 'movie').toList();
                  if (moviesInGenre.isNotEmpty) {
                    sliverItems.add(
                      SliverToBoxAdapter(
                        child: MovieRow(
                          title: _formatSlug(key),
                          movies: moviesInGenre,
                        ),
                      ),
                    );
                  }
                });

                sliverItems.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: sliverItems,
                );
              },
            ),
          ),

          // Scroll-responsive transparent App Bar Overlay at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, child) {
                return PremiumAppBar(scrollOffset: offset);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatSlug(String slug) {
    if (slug == 'multi_audio') return 'Multi-Audio Hits';
    if (slug == 'hindi') return 'Hindi Movies';
    if (slug == 'english') return 'English Movies';
    if (slug == 'kdrama') return 'K-Drama Hits';
    if (slug == 'anime') return 'Anime Movies';
    if (slug == 'quick_watch') return 'Quick Movies';

    return slug.split('_').map((word) {
      if (word == 'and') return '&';
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
