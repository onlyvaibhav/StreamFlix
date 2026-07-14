import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/app_image.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';

class EpisodeListSheet extends ConsumerStatefulWidget {
  final String movieId;

  const EpisodeListSheet({
    super.key,
    required this.movieId,
  });

  @override
  ConsumerState<EpisodeListSheet> createState() => _EpisodeListSheetState();
}

class _EpisodeListSheetState extends ConsumerState<EpisodeListSheet> {
  int _selectedSeasonIndex = 0;

  @override
  void initState() {
    super.initState();
    // Default select current episode season index
    final playerState = ref.read(moviePlayerProvider(widget.movieId));
    final currentEp = playerState.movie;
    if (currentEp != null && playerState.tvSeasons.isNotEmpty) {
      final currentSeasonNum = currentEp.seasonNumber ?? currentEp.tv?.seasonNumber ?? 1;
      final idx = playerState.tvSeasons.indexWhere((s) => s.seasonNumber == currentSeasonNum);
      if (idx >= 0) {
        _selectedSeasonIndex = idx;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(moviePlayerProvider(widget.movieId));
    final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);

    if (playerState.tvSeasons.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        body: const Center(
          child: Text(
            'No episodes available for this series',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }

    final currentSeason = playerState.tvSeasons[_selectedSeasonIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Glassmorphic backdrop blur covering the entire screen
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),

          // Main content container
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row with Season selector and Close button
                  Row(
                    children: [
                      const Text(
                        'Episodes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 24),
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
                            items: List.generate(playerState.tvSeasons.length, (idx) {
                              final season = playerState.tvSeasons[idx];
                              return DropdownMenuItem<int>(
                                value: idx,
                                child: Text('Season ${season.seasonNumber}'),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSeasonIndex = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),

                  // Scrollable Episode card rows list
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: currentSeason.episodes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, idx) {
                        final episode = currentSeason.episodes[idx];
                        final isPlaying = playerState.movie?.id == episode.id;

                        return InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            notifier.play(episode, keepSettings: true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isPlaying ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Episode Thumbnail with check play overlay
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 140,
                                    height: 80,
                                    child: Stack(
                                      children: [
                                        AppImage(
                                          imageUrl: episode.episodeStill ?? '/api/movies/${episode.id}/thumbnail',
                                          fit: BoxFit.cover,
                                          width: 140,
                                          height: 80,
                                          errorWidget: AppImage(
                                            imageUrl: playerState.movie?.backdrop ?? '',
                                            fit: BoxFit.cover,
                                            width: 140,
                                            height: 80,
                                          ),
                                        ),
                                        if (isPlaying)
                                          Container(
                                            color: Colors.black54,
                                            child: const Center(
                                              child: Icon(Icons.play_circle_fill, color: AppColors.netflixRed, size: 36),
                                            ),
                                          )
                                        else
                                          Container(
                                            color: Colors.black26,
                                            child: const Center(
                                              child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 32),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Episode details description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${episode.episodeNumber ?? (idx + 1)}. ${episode.title}',
                                        style: TextStyle(
                                          color: isPlaying ? AppColors.netflixRed : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      if (episode.runtime != null)
                                        Text(
                                          '${episode.runtime} min',
                                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        episode.overview ?? episode.description ?? 'No episode description available.',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
