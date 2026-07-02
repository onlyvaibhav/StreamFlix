import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/presentation/widgets/hero_banner.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_row.dart';
import 'package:streamflix/features/movies/presentation/widgets/premium_app_bar.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';

class TvCatalogScreen extends ConsumerStatefulWidget {
  const TvCatalogScreen({super.key});

  @override
  ConsumerState<TvCatalogScreen> createState() => _TvCatalogScreenState();
}

class _TvCatalogScreenState extends ConsumerState<TvCatalogScreen> {
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
    final tvShowsAsync = ref.watch(allTvShowsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main scrollable content
          Positioned.fill(
            child: tvShowsAsync.when(
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
                onRetry: () => ref.invalidate(allTvShowsProvider),
              ),
              data: (shows) {
                if (shows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No TV shows available in catalog',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }

                // Client-side curation mapping for 100% catalog representation
                
                // 1. Hero banner shows (popular items with backdrops)
                final heroShows = shows.where((s) => s.backdrop != null).toList();
                final finalHeroShows = heroShows.isEmpty ? shows.take(5).toList() : heroShows.take(8).toList();

                // 2. Trending Series (sorted by popularity desc)
                final trendingShows = [...shows]..sort((a, b) => (b.popularity ?? 0.0).compareTo(a.popularity ?? 0.0));

                // 3. Top Rated Series (rating >= 7.0 desc)
                final topRatedShows = shows.where((s) => (s.rating ?? 0.0) >= 6.5).toList()
                  ..sort((a, b) => (b.rating ?? 0.0).compareTo(a.rating ?? 0.0));

                // 4. Genre rows grouping helper
                List<Movie> filterByGenre(String genreName) {
                  final name = genreName.toLowerCase();
                  return shows.where((s) {
                    final genres = s.genres ?? [];
                    return genres.any((g) {
                      final gLower = g.toLowerCase();
                      return gLower.contains(name) || name.contains(gLower);
                    });
                  }).toList();
                }

                final List<Widget> sliverItems = [];

                // Hero Banner
                sliverItems.add(
                  SliverToBoxAdapter(
                    child: HeroBanner(movies: finalHeroShows),
                  ),
                );

                // Trending Series Row
                if (trendingShows.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(
                        title: 'Trending Series',
                        movies: trendingShows.take(15).toList(),
                      ),
                    ),
                  );
                }

                // Top Rated Series Row
                if (topRatedShows.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(
                        title: 'Top Rated Series',
                        movies: topRatedShows.take(15).toList(),
                      ),
                    ),
                  );
                }

                // Genre collections
                final genresToCurate = [
                  'Drama',
                  'Comedy',
                  'Action',
                  'Sci-Fi',
                  'Crime',
                  'Mystery',
                  'Animation',
                ];

                for (final genre in genresToCurate) {
                  final genreList = filterByGenre(genre);
                  if (genreList.isNotEmpty) {
                    sliverItems.add(
                      SliverToBoxAdapter(
                        child: MovieRow(
                          title: genre == 'Sci-Fi' ? 'Sci-Fi & Fantasy' : '$genre Series',
                          movies: genreList.take(15).toList(),
                        ),
                      ),
                    );
                  }
                }

                sliverItems.add(
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 60),
                  ),
                );

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: sliverItems,
                );
              },
            ),
          ),

          // Scroll-responsive transparent App Bar Overlay
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
}
