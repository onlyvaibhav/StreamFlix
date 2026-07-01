import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/core/widgets/gradient_overlay.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/presentation/widgets/movie_detail_info.dart';
import 'package:streamflix/features/movies/presentation/widgets/more_like_this_section.dart';
import 'package:streamflix/features/shared/presentation/widgets/shimmer_loading.dart';

/// Full-screen movie detail page
class MovieDetailScreen extends ConsumerWidget {
  final String movieId;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieAsync = ref.watch(movieDetailProvider(movieId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: movieAsync.when(
        loading: () => ShimmerLoading(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  color: Colors.white10,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(width: 220, height: 28, color: Colors.white10),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(width: 140, height: 16, color: Colors.white10),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(height: 48, color: Colors.white10),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(height: 120, color: Colors.white10),
                ),
              ],
            ),
          ),
        ),
        error: (error, stack) => AppErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(movieDetailProvider(movieId)),
        ),
        data: (movie) {
          return CustomScrollView(
            slivers: [
              // Backdrop header with gradient
              SliverAppBar(
                expandedHeight: _getBackdropHeight(context),
                pinned: true,
                backgroundColor: AppColors.background,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                  tooltip: 'Back',
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Backdrop image
                      if (movie.fullBackdropUrl != null)
                        AppImage(
                          imageUrl: movie.fullBackdropUrl!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(color: AppColors.backgroundCard),

                      // Gradient overlay
                      const GradientOverlay.bottomDark(),

                      // Logo positioned at bottom of backdrop
                      if (movie.fullLogoUrl != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: AppImage(
                            imageUrl: movie.fullLogoUrl!,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: Text(
                            movie.title,
                            style: AppTextStyles.heroTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Movie info section
              SliverToBoxAdapter(
                child: MovieDetailInfo(movie: movie),
              ),

              // "More Like This" section
              SliverToBoxAdapter(
                child: MoreLikeThisSection(movie: movie),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 48),
              ),
            ],
          );
        },
      ),
    );
  }

  double _getBackdropHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width > 1200) return size.height * 0.6;
    if (size.width > 800) return size.height * 0.5;
    return size.height * 0.4;
  }
}
