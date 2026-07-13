import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_dimensions.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_card.dart';

/// "More Like This" recommendations section
class MoreLikeThisSection extends ConsumerWidget {
  final Movie movie;

  const MoreLikeThisSection({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMoviesAsync = ref.watch(allMoviesProvider);

    return allMoviesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (allMovies) {
        final recommendations = _getRecommendations(allMovies);

        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'More Like This',
                style: AppTextStyles.heading2,
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio: 2 / 3, // Perfect poster ratio
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                ),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  return MovieCard(movie: recommendations[index]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Get recommended movies based on genre overlap
  List<Movie> _getRecommendations(List<Movie> allMovies) {
    if (movie.genres == null || movie.genres!.isEmpty) {
      // No genres - return popular movies
      final sorted = List<Movie>.from(allMovies);
      sorted.sort((a, b) {
        final aScore = (a.popularity ?? 0) + (a.rating ?? 0) * 10;
        final bScore = (b.popularity ?? 0) + (b.rating ?? 0) * 10;
        return bScore.compareTo(aScore);
      });
      return sorted.where((m) => m.id != movie.id).take(6).toList();
    }

    final genreSet = movie.genres!.toSet();

    // Score each movie by genre overlap
    final scored = allMovies
        .where((m) => m.id != movie.id) // Exclude current movie
        .map((m) {
      if (m.genres == null || m.genres!.isEmpty) return MapEntry(m, 0.0);

      final overlap = m.genres!.where((g) => genreSet.contains(g)).length;
      final score = overlap.toDouble() +
          (m.rating ?? 0) / 10 +
          (m.popularity ?? 0) / 100;
      return MapEntry(m, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored.take(6).map((e) => e.key).toList();
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 800) return 4;
    return 3;
  }
}
