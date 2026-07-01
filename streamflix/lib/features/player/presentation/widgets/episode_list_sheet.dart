import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/core/widgets/app_image.dart';
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
      return Container(
        height: 200,
        color: AppColors.backgroundCard,
        child: const Center(
          child: Text(
            'No episodes available for this series',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ),
      );
    }

    final currentSeason = playerState.tvSeasons[_selectedSeasonIndex];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header season selection dropdown
          Row(
            children: [
              const Text('Episodes', style: AppTextStyles.heading2),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedSeasonIndex,
                    dropdownColor: AppColors.backgroundCard,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
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
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Scrollable Episode card rows list
          Expanded(
            child: ListView.separated(
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Episode Thumbnail with check play overlay
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 120,
                            height: 70,
                            child: Stack(
                              children: [
                                AppImage(
                                  imageUrl: '/api/movies/${episode.id}/thumbnail',
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 70,
                                  errorWidget: AppImage(
                                    imageUrl: playerState.movie?.backdrop ?? '',
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 70,
                                  ),
                                ),
                                if (isPlaying)
                                  Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: Icon(Icons.play_circle_fill, color: AppColors.netflixRed, size: 32),
                                    ),
                                  )
                                else
                                  Container(
                                    color: Colors.black26,
                                    child: const Center(
                                      child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 28),
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
                                  fontSize: 13.5,
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
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
    );
  }
}
