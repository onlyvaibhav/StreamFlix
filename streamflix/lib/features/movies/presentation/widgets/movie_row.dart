import 'package:flutter/material.dart';
import 'package:streamflix/core/constants/app_dimensions.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_card.dart';
import 'package:streamflix/features/shared/presentation/widgets/shimmer_loading.dart';

/// Horizontal scrollable row of movie cards
class MovieRow extends StatelessWidget {
  final String title;
  final List<Movie> movies;

  const MovieRow({
    super.key,
    required this.title,
    required this.movies,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row title
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spaceMedium,
            right: AppDimensions.spaceMedium,
            top: AppDimensions.spaceLarge,
            bottom: AppDimensions.spaceSmall,
          ),
          child: Text(
            title,
            style: AppTextStyles.heading2,
          ),
        ),

        // Horizontal scrollable list
        SizedBox(
          height: AppDimensions.movieCardHeight + 24.0,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMedium,
              vertical: 12.0,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < movies.length - 1
                      ? AppDimensions.spaceSmall
                      : 0,
                ),
                child: MovieCard(movie: movies[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Loading skeleton for movie row using premium ShimmerLoading
class MovieRowSkeleton extends StatelessWidget {
  const MovieRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title skeleton
          Padding(
            padding: const EdgeInsets.only(
              left: AppDimensions.spaceMedium,
              right: AppDimensions.spaceMedium,
              top: AppDimensions.spaceLarge,
              bottom: AppDimensions.spaceSmall,
            ),
            child: Container(
              width: 150,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Cards skeleton
          SizedBox(
            height: AppDimensions.movieCardHeight + 24.0,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMedium,
                vertical: 12.0,
              ),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(
                    right: AppDimensions.spaceSmall,
                  ),
                  child: Container(
                    width: AppDimensions.movieCardWidth,
                    height: AppDimensions.movieCardHeight,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
