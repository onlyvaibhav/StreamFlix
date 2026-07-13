import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/router/route_names.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
    final box = Hive.box('authBox');
    final user = box.get('user') as Map<dynamic, dynamic>?;
    final firstName = user?['firstName'] ?? user?['first_name'] ?? user?['username'] ?? '';
    final headerText = firstName.toString().isNotEmpty 
        ? 'Continue Watching for $firstName'
        : 'Continue Watching';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            headerText,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
        SizedBox(
          height: 230,
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
                width: 125,
                margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Column(
                  children: [
                    // Image part (2:3 aspect ratio)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                          child: AspectRatio(
                            aspectRatio: 2 / 3,
                            child: AppImage(
                              imageUrl: item.poster ?? item.backdrop ?? '',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Circular play button overlay
                        Positioned.fill(
                          child: Center(
                            child: GestureDetector(
                              onTap: () {
                                context.push('/watch/$playableId?startTime=${item.position}');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.5),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
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
                            height: 4.0,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                (item.seasonNumber != null && item.episodeNumber != null)
                                    ? 'S${item.seasonNumber}:E${item.episodeNumber}'
                                    : '$remainingMin m left',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
