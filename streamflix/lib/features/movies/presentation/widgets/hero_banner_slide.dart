import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/core/widgets/gradient_overlay.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';

/// Individual slide component of the Hero Banner
class HeroBannerSlide extends StatelessWidget {
  final Movie movie;
  final double height;

  const HeroBannerSlide({
    super.key,
    required this.movie,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (movie.fullBackdropUrl != null)
          AppImage(
            imageUrl: movie.fullBackdropUrl!,
            fit: BoxFit.cover,
          )
        else
          Container(color: AppColors.backgroundCard),
        const GradientOverlay.bottomDark(),
        Positioned(
          left: isMobile ? 16 : 48,
          right: isMobile ? 16 : size.width * 0.4,
          bottom: isMobile ? 80 : 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (movie.fullLogoUrl != null) ...[
                AppImage(
                  imageUrl: movie.fullLogoUrl!,
                  height: isMobile ? 80 : 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  movie.title.toUpperCase(),
                  style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: isMobile ? 42 : 62,
                    letterSpacing: 1.5,
                    height: 0.95,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  if (movie.rating != null && movie.rating! > 0) ...[
                    Text(
                      '${(movie.rating! * 10).round()}% Match',
                      style: const TextStyle(
                        color: Color(0xFF46D369), // Netflix green match percentage
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (movie.year != null && movie.year! > 0) ...[
                    Text(
                      movie.year.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      movie.type == 'tv' ? 'TV' : 'HD',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (movie.genres != null && movie.genres!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    movie.genres!.take(3).join('  •  '),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (!isMobile && movie.overview != null)
                Text(
                  movie.overview!,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push(RouteNames.watchPath(movie.id));
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 28, color: Colors.black),
                    label: const Text(
                      'Play',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 24 : 36,
                        vertical: isMobile ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push(RouteNames.movieDetailPath(movie.id));
                    },
                    icon: const Icon(Icons.info_outline_rounded, size: 24, color: Colors.white),
                    label: const Text(
                      'More Info',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 28,
                        vertical: isMobile ? 12 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
