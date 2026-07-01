import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/features/movies/data/models/watch_history.dart';

class ContinueWatchingRow extends StatelessWidget {
  final List<WatchHistoryItem> items;

  const ContinueWatchingRow({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: items.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = items[index];
              final progressPct = (item.position / item.duration).clamp(0.0, 1.0);
              final remainingMin = ((item.duration - item.position) / 60).round();
              
              // Tapping the card plays it immediately using the saved episodeId (for TV) or movieId (for Movies)
              final playableId = item.episodeId ?? item.movieId;

              return Container(
                width: 220,
                margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(6.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image part (16:9 aspect ratio)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6.0),
                            topRight: Radius.circular(6.0),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: AppImage(
                              imageUrl: item.backdrop ?? item.poster ?? '',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Circular play button overlay
                        Positioned.fill(
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                context.push('/watch/$playableId');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.4),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Progress bar at the bottom edge of image
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 3.5,
                            color: Colors.white24,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progressPct,
                              child: Container(
                                color: AppColors.netflixRed,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Info/Details panel underneath
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.tvShowName ?? item.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.tvShowName != null
                                        ? 'S${item.seasonNumber} E${item.episodeNumber} • $remainingMin m left'
                                        : '$remainingMin min left',
                                    style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                context.push(RouteNames.movieDetailPath(item.movieId));
                              },
                              tooltip: 'Show details',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
