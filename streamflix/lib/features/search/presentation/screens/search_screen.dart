import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_card.dart';
import 'package:streamflix/features/shared/presentation/widgets/shimmer_loading.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/core/network/connectivity_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:streamflix/features/movies/presentation/widgets/continue_watching_row.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';
  Timer? _debounce;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  void _loadRecentSearches() {
    final box = Hive.box('authBox');
    final saved = box.get('recent_searches') as List<dynamic>?;
    if (saved != null) {
      _recentSearches = saved.map((e) => e.toString()).toList();
    }
  }

  void _saveRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    final q = query.trim();
    setState(() {
      _recentSearches.removeWhere((s) => s.toLowerCase() == q.toLowerCase());
      _recentSearches.insert(0, q);
      if (_recentSearches.length > 8) {
        _recentSearches = _recentSearches.sublist(0, 8);
      }
    });
    Hive.box('authBox').put('recent_searches', _recentSearches);
  }

  void _clearRecentSearches() {
    setState(() {
      _recentSearches.clear();
    });
    Hive.box('authBox').delete('recent_searches');
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _query = value;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
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
          onRetry: () => ref.invalidate(searchCatalogProvider(_query)),
        ),
      );
    }

    final searchAsync = ref.watch(searchCatalogProvider(_query));
    final curatedAsync = ref.watch(curatedContentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: AppColors.netflixRed,
                  onSubmitted: (value) {
                    _saveRecentSearch(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search movies, TV shows...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

            // Recent Searches row when query is empty
            if (_query.trim().isEmpty && _recentSearches.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Searches', style: AppTextStyles.heading3),
                        TextButton(
                          onPressed: _clearRecentSearches,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Clear All', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _recentSearches.length,
                      itemBuilder: (context, index) {
                        final tag = _recentSearches[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            label: Text(tag),
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            backgroundColor: AppColors.backgroundCard,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onPressed: () {
                              _searchController.text = tag;
                              _saveRecentSearch(tag);
                              setState(() {
                                _query = tag;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Search Results or Recommendations
            Expanded(
              child: _query.trim().isEmpty
                  ? curatedAsync.when(
                      loading: () => _buildGridSkeleton(),
                      error: (err, stack) => const Center(
                        child: Text(
                          'Failed to load recommendations',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      data: (curated) {
                        final trending = curated.homepage.trending;
                        final continueWatchingAsync = ref.watch(continueWatchingProvider);
                        return CustomScrollView(
                          slivers: [
                            continueWatchingAsync.when(
                              data: (items) {
                                if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                                return SliverToBoxAdapter(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        child: Text(
                                          'From your list',
                                          style: AppTextStyles.heading3,
                                        ),
                                      ),
                                      ContinueWatchingRow(items: items),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                );
                              },
                              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                            ),
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text(
                                  'Recommended Searches',
                                  style: AppTextStyles.heading3,
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = trending[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                                    onTap: () {
                                      _saveRecentSearch(item.title);
                                      context.push(RouteNames.movieDetailPath(item.id));
                                    },
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: AppImage(
                                          imageUrl: item.backdrop ?? item.poster ?? '',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      item.title,
                                      style: AppTextStyles.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  );
                                },
                                childCount: trending.length,
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : searchAsync.when(
                      loading: () => _buildGridSkeleton(),
                      error: (err, stack) => Center(
                        child: Text(
                          'Error: $err',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ),
                      data: (results) {
                        if (results.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 64, color: AppColors.textTertiary),
                                SizedBox(height: 16),
                                Text(
                                  'No results found',
                                  style: AppTextStyles.heading3,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Try searching for movies, genres, or TV shows',
                                  style: AppTextStyles.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2 / 3,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                          ),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final item = results[index];
                            return MovieCard(movie: item);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return ShimmerLoading(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}
