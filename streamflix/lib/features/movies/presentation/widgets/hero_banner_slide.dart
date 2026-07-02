import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';

/// Individual slide component of the Hero Banner.
/// Uses the complete poster image as the full-slide background,
/// overlayed with the bottom gradient, centered buttons, and aligned dots.
class HeroBannerSlide extends StatelessWidget {
  final Movie movie;
  final double height;
  final Widget pageIndicator;

  const HeroBannerSlide({
    super.key,
    required this.movie,
    required this.height,
    required this.pageIndicator,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Complete Poster as Full-Slide Background
        AppImage(
          imageUrl: movie.fullPosterUrl ?? movie.fullBackdropUrl ?? '',
          fit: BoxFit.cover,
        ),
        
        // 2. Dark overlay gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.8),
                  AppColors.background,
                ],
                stops: const [0.0, 0.4, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // 3. Main centered content column
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Series / Movie tag
                if (movie.type == 'tv')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.netflixRed,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                        child: const Text(
                          'N',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'S E R I E S',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                // Movie/Show Logo or Title
                if (movie.fullLogoUrl != null)
                  AppImage(
                    imageUrl: movie.fullLogoUrl!,
                    height: isLandscape ? 40 : 54,
                    fit: BoxFit.contain,
                    errorWidget: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        movie.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: isLandscape ? 28 : 34,
                          letterSpacing: 1.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      movie.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: isLandscape ? 28 : 34,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                const SizedBox(height: 10),

                // Genres list
                if (movie.genres != null && movie.genres!.isNotEmpty)
                  Text(
                    movie.genres!.take(3).join('  •  '),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isLandscape ? 10.5 : 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),

                const SizedBox(height: 16),

                // Action Buttons (Play & Info)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Play Button
                    SizedBox(
                      width: isLandscape ? 115 : 135,
                      height: isLandscape ? 34 : 38,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(RouteNames.watchPath(movie.id));
                        },
                        icon: Icon(Icons.play_arrow_rounded, size: isLandscape ? 20 : 24, color: Colors.black),
                        label: const Text(
                          'Play',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),

                    // Info Button
                    SizedBox(
                      width: isLandscape ? 115 : 135,
                      height: isLandscape ? 34 : 38,
                      child: TextButton.icon(
                        onPressed: () {
                          context.push(RouteNames.movieDetailPath(movie.id));
                        },
                        icon: Icon(Icons.info_outline_rounded, size: isLandscape ? 16 : 18, color: Colors.white),
                        label: const Text(
                          'Info',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 18),
                pageIndicator,
                SizedBox(height: isLandscape ? 16 : 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
