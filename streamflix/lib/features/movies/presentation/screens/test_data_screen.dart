import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';

/// Temporary screen to test data fetching
class TestDataScreen extends ConsumerWidget {
  const TestDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(allMoviesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Data Layer Test'),
        backgroundColor: AppColors.backgroundLight,
      ),
      body: moviesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.netflixRed,
          ),
        ),
        error: (error, stack) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(allMoviesProvider),
        ),
        data: (movies) {
          if (movies.isEmpty) {
            return const Center(
              child: Text(
                'No movies found',
                style: AppTextStyles.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            itemCount: movies.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final movie = movies[index];
              return Card(
                color: AppColors.backgroundCard,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      if (movie.fullPosterUrl != null)
                        AppImage(
                          imageUrl: movie.fullPosterUrl!,
                          width: 80,
                          height: 120,
                          borderRadius: BorderRadius.circular(4),
                        )
                      else
                        Container(
                          width: 80,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.movie,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      const SizedBox(width: 12),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              style: AppTextStyles.heading3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (movie.releaseYear != null)
                              Text(
                                movie.releaseYear!,
                                style: AppTextStyles.bodySmall,
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  movie.formattedRating,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (movie.genres != null && movie.genres!.isNotEmpty)
                              Text(
                                movie.genreList,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              movie.overview ?? movie.description ?? '',
                              style: AppTextStyles.bodySmall,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Debug info
                            Text(
                              'ID: ${movie.id} | Runtime: ${movie.formattedRuntime ?? 'N/A'}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
