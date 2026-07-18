import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_card.dart';
import 'package:streamflix/features/shared/presentation/widgets/shimmer_loading.dart';

class GenreMovieList extends ConsumerWidget {
  final String genreId;

  const GenreMovieList({
    super.key,
    required this.genreId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moviesAsync = ref.watch(moviesByGenreProvider(genreId));

    return moviesAsync.when(
      data: (movies) {
        if (movies.isEmpty) {
          return const Center(
            child: Text(
              'No titles found for this genre.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2 / 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return GestureDetector(
              onTap: () {
                context.push(RouteNames.movieDetail.replaceAll(':id', movie.id));
              },
              child: MovieCard(
                movie: movie,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          },
        );
      },
      loading: () => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: 15,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const ShimmerLoading(child: SizedBox(width: double.infinity, height: double.infinity)),
          );
        },
      ),
      error: (error, stack) => AppErrorWidget(
        error: error.toString(),
        onRetry: () => ref.invalidate(moviesByGenreProvider(genreId)),
      ),
    );
  }
}
