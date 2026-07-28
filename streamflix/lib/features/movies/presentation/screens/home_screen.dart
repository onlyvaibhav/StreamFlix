import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/core/network/connectivity_service.dart';
import 'package:streamflix/features/movies/data/models/curated_row.dart';
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

                      // 2.5 Because You Watched
                      final latestItem = items.first;
                      final isTv = latestItem.movieId.startsWith('show_');
                      final cleanId = isTv ? latestItem.movieId.replaceAll('show_', '') : latestItem.movieId;
                      final type = isTv ? 'tv' : 'movie';
                      final String cleanTitle = isTv ? (latestItem.tvShowName ?? latestItem.title) : latestItem.title;

                      sliverItems.add(
                        SliverToBoxAdapter(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final recommendationsAsync = ref.watch(moreLikeThisProvider(cleanId, type));
                              return recommendationsAsync.when(
                                loading: () => const MovieRowSkeleton(),
                                error: (_, __) => const SizedBox.shrink(),
                                data: (recommendations) {
                                  if (recommendations.isEmpty) return const SizedBox.shrink();
                                  return MovieRow(
                                    title: 'Because You Watched $cleanTitle',
                                    movies: recommendations,
                                  );
                                },
                              );
                            },
                          ),
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

                // Dynamic Bucketing and Interleaving
                final Map<String, List<CuratedRow>> buckets = {
                  'special': [],
                  'discover': [],
                  'provider': [],
                  'collection': [],
                  'keyword': [],
                  'original': [],
                  'genre': [],
                };

                final rows = homepage.rows;
                
                rows.forEach((key, rowData) {
                  final items = rowData.items;
                  if (items.isEmpty) return;
                  int minItems = 3;
                  String type = 'special';
                  
                  if (key.startsWith('provider_')) { type = 'provider'; }
                  else if (key.startsWith('original_')) { type = 'original'; }
                  else if (key.startsWith('collection_')) { type = 'collection'; minItems = 2; }
                  else if (key.startsWith('keyword_')) { type = 'keyword'; minItems = 2; }
                  else if (key.startsWith('genre_')) { type = 'genre'; }
                  else if (key.startsWith('special_') || ['hindi', 'english', 'multi_audio', 'quick_watch', 'recently_fixed'].contains(key)) { type = 'special'; }
                  else if (['kdrama', 'anime'].contains(key)) { type = 'special'; minItems = 2; }
                  else { return; }
                  
                  if (items.length >= minItems) {
                    buckets[type]!.add(rowData);
                  }
                });

                // Flush Originals explicitly at the top
                if (buckets['original']!.isNotEmpty) {
                  for (final originalRow in buckets['original']!) {
                    sliverItems.add(
                      SliverToBoxAdapter(
                        child: MovieRow(
                          title: originalRow.title,
                          movies: originalRow.items,
                        ),
                      ),
                    );
                  }
                  buckets['original']!.clear();
                }
                
                // Shuffle buckets for variety
                for (final key in buckets.keys) {
                  buckets[key]!.shuffle();
                }
                
                // Interleave naturally
                final pattern = ['special', 'discover', 'provider', 'collection', 'keyword', 'original', 'special', 'genre', 'discover', 'collection'];
                int patternIdx = 0;
                
                while (buckets.values.any((b) => b.isNotEmpty)) {
                  final type = pattern[patternIdx % pattern.length];
                  
                  if (buckets[type]!.isNotEmpty) {
                    final row = buckets[type]!.removeLast();
                    sliverItems.add(
                      SliverToBoxAdapter(
                        child: MovieRow(
                          title: row.title,
                          logo: row.logo,
                          movies: row.items,
                        ),
                      ),
                    );
                  } else {
                    int maxLen = 0;
                    String? maxKey;
                    for (final k in buckets.keys) {
                      if (buckets[k]!.length > maxLen) {
                        maxLen = buckets[k]!.length;
                        maxKey = k;
                      }
                    }
                    if (maxKey != null) {
                      final row = buckets[maxKey]!.removeLast();
                      sliverItems.add(
                        SliverToBoxAdapter(
                          child: MovieRow(
                            title: row.title,
                            movies: row.items,
                          ),
                        ),
                      );
                    }
                  }
                  patternIdx++;
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
}
