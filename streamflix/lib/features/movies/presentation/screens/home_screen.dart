import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/core/network/connectivity_service.dart';
import 'package:streamflix/features/movies/presentation/widgets/continue_watching_row.dart';
import 'package:streamflix/features/movies/presentation/widgets/hero_banner.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_row.dart';
import 'package:streamflix/features/movies/presentation/widgets/premium_app_bar.dart';

/// Netflix-style home screen with scroll-responsive transparent app bar,
/// Hero banner, Continue Watching, and curated grids.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    final continueWatching = ref.watch(continueWatchingProvider);

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
                final heroItems = homepage.hero;
                
                final List<Widget> sliverItems = [];

                // 1. Hero Banner Carousel
                sliverItems.add(
                  SliverToBoxAdapter(
                    child: heroItems.isEmpty
                        ? const SizedBox(
                            height: 400,
                            child: Center(
                              child: Text('No featured content available'),
                            ),
                          )
                        : HeroBanner(movies: heroItems),
                  ),
                );

                // 2. Continue Watching (netflix-style progress overlay immediately below Hero)
                continueWatching.when(
                  data: (items) {
                    if (items.isNotEmpty) {
                      sliverItems.add(
                        SliverToBoxAdapter(
                          child: ContinueWatchingRow(items: items),
                        ),
                      );
                    }
                  },
                  loading: () {}, // Optional: Add a skeleton here if desired
                  error: (_, __) {}, // Silently fail on error
                );

                // 3. Trending Now
                if (homepage.trending.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(
                        title: 'Trending Now',
                        movies: homepage.trending,
                      ),
                    ),
                  );
                }

                // 4. Recently Added
                if (homepage.recentlyAdded.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(
                        title: 'Recently Added',
                        movies: homepage.recentlyAdded,
                      ),
                    ),
                  );
                }

                // 5. Top Rated
                if (homepage.topRated.isNotEmpty) {
                  sliverItems.add(
                    SliverToBoxAdapter(
                      child: MovieRow(
                        title: 'Top Rated',
                        movies: homepage.topRated,
                      ),
                    ),
                  );
                }

                // Define special dynamic rows
                final rows = homepage.rows;
                const specialKeys = [
                  'multi_audio',
                  'hindi',
                  'english',
                  'kdrama',
                  'anime',
                  'quick_watch',
                  'recently_fixed',
                  'needs_attention'
                ];

                // Render special collections
                for (final key in specialKeys) {
                  final list = rows[key];
                  if (list != null && list.isNotEmpty) {
                    sliverItems.add(
                      SliverToBoxAdapter(
                        child: MovieRow(
                          title: _formatSlug(key),
                          movies: list,
                        ),
                      ),
                    );
                  }
                }

                // Render other genres alphabetically
                final otherKeys = rows.keys.where((k) => !specialKeys.contains(k)).toList();
                otherKeys.sort((a, b) => _formatSlug(a).compareTo(_formatSlug(b)));

                for (final key in otherKeys) {
                  final list = rows[key];
                  if (list != null && list.isNotEmpty) {
                    sliverItems.add(
                      SliverToBoxAdapter(
                        child: MovieRow(
                          title: _formatSlug(key),
                          movies: list,
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
    if (slug == 'kdrama') return 'K-Drama Collection';
    if (slug == 'anime') return 'Anime Collection';
    if (slug == 'quick_watch') return 'Quick Watches';
    if (slug == 'recently_fixed') return 'Recently Restored';
    if (slug == 'needs_attention') return 'Needs Attention';

    return slug.split('_').map((word) {
      if (word == 'and') return '&';
      if (word == 'sci') return 'Sci-Fi';
      if (word == 'fi') return 'Fantasy';
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ').replaceAll('Sci-Fi Fantasy', 'Sci-Fi & Fantasy');
  }
}
