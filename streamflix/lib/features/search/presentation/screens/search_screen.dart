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

  final List<String> _popularTags = [
    'Action',
    'Comedy',
    'Drama',
    'Sci-Fi',
    'Anime',
    'Hindi',
    'English',
    'KDrama',
  ];

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
                  onChanged: _onSearchChanged,
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
                ),
              ),
            ),

            // Popular tags row when query is empty
            if (_query.trim().isEmpty)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _popularTags.length,
                  itemBuilder: (context, index) {
                    final tag = _popularTags[index];
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
                          setState(() {
                            _query = tag;
                          });
                        },
                      ),
                    );
                  },
                ),
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
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                'Recommended Searches',
                                style: AppTextStyles.heading3,
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: trending.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                itemBuilder: (context, index) {
                                  final item = trending[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                                    onTap: () {
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
