import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_dimensions.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/watch_history.dart';
import 'package:streamflix/features/downloads/presentation/widgets/download_button.dart';

class MovieDetailInfo extends StatefulWidget {
  final Movie movie;

  const MovieDetailInfo({
    super.key,
    required this.movie,
  });

  @override
  State<MovieDetailInfo> createState() => _MovieDetailInfoState();
}

class _MovieDetailInfoState extends State<MovieDetailInfo> {
  bool _isDescriptionExpanded = false;
  int _selectedSeasonIndex = 0;
  bool _isAddedToMyList = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final overviewText = widget.movie.overview ?? widget.movie.description ?? '';
    
    final progress = WatchHistoryManager.getProgress(widget.movie.id);
    final isResume = progress != null;

    String primaryActionText;
    String primaryActionPath;

    if (isResume) {
      if (widget.movie.type == 'tv' && progress.seasonNumber != null && progress.episodeNumber != null) {
        primaryActionText = 'Resume S${progress.seasonNumber} E${progress.episodeNumber}';
      } else {
        primaryActionText = 'Resume';
      }
      primaryActionPath = RouteNames.watchPath(progress.episodeId ?? widget.movie.id);
    } else {
      if (widget.movie.type == 'tv' &&
          widget.movie.seasons != null &&
          widget.movie.seasons!.isNotEmpty) {
        final selectedSeason = widget.movie.seasons![_selectedSeasonIndex];
        primaryActionText = 'Play S${selectedSeason.seasonNumber}E1';
        final firstEp = selectedSeason.episodes.firstOrNull;
        primaryActionPath = firstEp != null ? RouteNames.watchPath(firstEp.id) : RouteNames.watchPath(widget.movie.id);
      } else {
        primaryActionText = 'Play';
        primaryActionPath = RouteNames.watchPath(widget.movie.id);
      }
    }

    return Padding(
      padding: EdgeInsets.all(
        isMobile ? AppDimensions.spaceMedium : AppDimensions.spaceLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Styled Metadata Badges Row (Year, Rating, Quality)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.movie.releaseYear != null)
                _buildBadge(widget.movie.releaseYear!),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    widget.movie.formattedRating,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              
              if (widget.movie.formattedRuntime != null)
                _buildBadge(widget.movie.formattedRuntime!),
              
              // Premium quality tags
              _buildBadge('HD'),
              _buildBadge('HDR'),
              
              if (widget.movie.type == 'tv')
                _buildBadge('TV Series', isAccent: true),
            ],
          ),

          const SizedBox(height: 16),

          // Genre chips
          if (widget.movie.genres != null && widget.movie.genres!.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.movie.genres!.map((genre) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    genre,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 20),

          // Overview description
          Text(
            overviewText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
            maxLines: _isDescriptionExpanded ? null : 3,
            overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),

          if (overviewText.length > 150)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isDescriptionExpanded = !_isDescriptionExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  _isDescriptionExpanded ? 'Show Less' : 'Read More',
                  style: const TextStyle(
                    color: AppColors.netflixRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 28),

          // Action buttons (Play and Download)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push(primaryActionPath);
                    },
                    icon: Icon(isResume ? Icons.play_circle_fill_rounded : Icons.play_arrow_rounded, size: 28, color: Colors.black),
                    label: Text(
                      primaryActionText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.movie.type != 'tv' && widget.movie.type != 'tv_show') ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: DownloadButton(movie: widget.movie, compact: false),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // Vertical stacked action buttons (Netflix-style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildVerticalAction(
                icon: _isAddedToMyList ? Icons.check_rounded : Icons.add_rounded,
                label: 'My List',
                onTap: () {
                  setState(() {
                    _isAddedToMyList = !_isAddedToMyList;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isAddedToMyList ? 'Added to My List' : 'Removed from My List'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _buildVerticalAction(
                icon: Icons.thumb_up_alt_outlined,
                label: 'Rate',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rated movie! Thank you.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              _buildVerticalAction(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied share link to clipboard!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),

          // TV Show Season Selector and Episodes list
          if (widget.movie.type == 'tv' &&
              widget.movie.seasons != null &&
              widget.movie.seasons!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 40),
            Row(
              children: [
                const Text(
                  'Episodes',
                  style: AppTextStyles.heading2,
                ),
                const Spacer(),
                // Padded custom Season selector button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedSeasonIndex,
                      dropdownColor: Colors.black.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                      items: List.generate(widget.movie.seasons!.length, (index) {
                        final season = widget.movie.seasons![index];
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text('Season ${season.seasonNumber}'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSeasonIndex = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.movie.seasons![_selectedSeasonIndex].episodes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final episode = widget.movie.seasons![_selectedSeasonIndex].episodes[index];
                return GestureDetector(
                  onTap: () {
                    context.push(RouteNames.watchPath(episode.id));
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Episode thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 130,
                          height: 75,
                          child: Stack(
                            children: [
                              AppImage(
                                imageUrl: episode.episodeStill ?? '/api/movies/${episode.id}/thumbnail',
                                fit: BoxFit.cover,
                                width: 130,
                                height: 75,
                                errorWidget: AppImage(
                                  imageUrl: widget.movie.backdrop ??
                                      widget.movie.poster ??
                                      '',
                                  fit: BoxFit.cover,
                                  width: 130,
                                  height: 75,
                                ),
                              ),
                              Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Episode metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${episode.episodeNumber ?? (index + 1)}. ${episode.title}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (episode.formattedRuntime != null || episode.runtime != null)
                                  Text(
                                    episode.formattedRuntime ?? '${episode.runtime}m',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                if ((episode.formattedRuntime != null || episode.runtime != null) && episode.dateFormatted != null)
                                  const Text('  •  ', style: TextStyle(color: Colors.white24)),
                                if (episode.dateFormatted != null)
                                  Text(
                                    episode.dateFormatted!,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              episode.overview ?? episode.description ?? 'No overview available.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Download button for episode
                      DownloadButton(movie: episode, compact: true),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String label, {bool isAccent = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isAccent ? AppColors.netflixRed.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAccent ? AppColors.netflixRed : Colors.white24,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        label,
        style: TextStyle(
          color: isAccent ? AppColors.netflixRed : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildVerticalAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
