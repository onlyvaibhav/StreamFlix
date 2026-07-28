import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_row.dart';

/// "More Like This" recommendations section
class MoreLikeThisSection extends ConsumerWidget {
  final Movie movie;

  const MoreLikeThisSection({
    super.key,
    required this.movie,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine type for the API call (tv vs movie)
    final type = movie.type == 'tv' ? 'tv' : 'movie';
    // For TV, use showTmdbId if available or fallback to id
    final String lookupId = type == 'tv' && movie.tv != null 
        ? movie.tv!.showTmdbId.toString() 
        : movie.id;

    final recommendationsAsync = ref.watch(moreLikeThisProvider(lookupId, type));

    return recommendationsAsync.when(
      loading: () => const MovieRowSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return MovieRow(
          title: 'More Like This',
          movies: recommendations,
        );
      },
    );
  }
}
