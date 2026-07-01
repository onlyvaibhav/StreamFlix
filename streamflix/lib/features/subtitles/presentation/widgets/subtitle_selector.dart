import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';

class SubtitleSelector extends ConsumerWidget {
  final String movieId;

  const SubtitleSelector({
    super.key,
    required this.movieId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.subtitles_rounded, color: Colors.white, size: 26),
      onPressed: () {
        _showTracksDialog(context, ref);
      },
      tooltip: 'Audio & Subtitles',
    );
  }

  void _showTracksDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final playerState = ref.watch(moviePlayerProvider(movieId));
            final notifier = ref.read(moviePlayerProvider(movieId).notifier);
            
            final audioTracks = playerState.trackInfo?.audioTracks ?? [];
            final embeddedSubs = playerState.trackInfo?.subtitleTracks ?? [];
            final externalSubs = playerState.externalSubtitles;

            return AlertDialog(
              backgroundColor: AppColors.backgroundCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.netflixRed),
                  const SizedBox(width: 10),
                  const Text('Audio & Subtitles', style: AppTextStyles.heading3),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1: Audio Selection
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Audio Track',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Divider(color: Colors.white12, height: 1),
                            const SizedBox(height: 8),
                            ...List.generate(audioTracks.length, (idx) {
                              final track = audioTracks[idx];
                              final isSelected = playerState.currentAudioTrack == idx;
                              final trackLabel = _formatAudioTrackLabel(track, idx);
                              
                              return _buildSelectorItem(
                                label: trackLabel,
                                isSelected: isSelected,
                                onTap: () => notifier.switchAudioTrack(idx),
                              );
                            }),
                            if (audioTracks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No extra audio tracks available', style: TextStyle(color: Colors.white38, fontSize: 13)),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 32),
                      
                      // Column 2: Subtitle Selection
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Subtitles',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Divider(color: Colors.white12, height: 1),
                            const SizedBox(height: 8),
                            
                            // Subtitles Off option
                            _buildSelectorItem(
                              label: 'Off',
                              isSelected: playerState.currentSubtitleTrack == -1,
                              onTap: () => notifier.switchSubtitleTrack(-1),
                            ),
                            
                            // Embedded subtitle grouping
                            if (embeddedSubs.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'EMBEDDED',
                                style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              ...List.generate(embeddedSubs.length, (idx) {
                                final track = embeddedSubs[idx];
                                final isSelected = playerState.currentSubtitleTrack == idx;
                                final trackLabel = _formatEmbeddedSubLabel(track, idx);
                                
                                return _buildSelectorItem(
                                  label: trackLabel,
                                  isSelected: isSelected,
                                  onTap: () => notifier.switchSubtitleTrack(idx, isExternal: false),
                                );
                              }),
                            ],
                            
                            // External subtitle grouping (priority sorted)
                            if (externalSubs.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'EXTERNAL (DOWNLOADED)',
                                style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                              ),
                              const SizedBox(height: 4),
                              ...List.generate(externalSubs.length, (idx) {
                                final sub = externalSubs[idx];
                                final virtualIndex = idx + 100;
                                final isSelected = playerState.currentSubtitleTrack == virtualIndex;
                                final trackLabel = _formatExternalSubLabel(sub);
                                
                                return _buildSelectorItem(
                                  label: trackLabel,
                                  isSelected: isSelected,
                                  onTap: () => notifier.switchSubtitleTrack(idx, isExternal: true),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: AppColors.netflixRed, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSelectorItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.netflixRed,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  String _formatAudioTrackLabel(dynamic track, int idx) {
    final parts = <String>[];
    
    // 1. Language
    parts.add(track.language != null && track.language.isNotEmpty ? track.language : 'Audio ${idx + 1}');
    
    // 2. Codec (uppercase)
    if (track.codec != null && track.codec.isNotEmpty && track.codec != 'unknown') {
      parts.add(track.codec.toUpperCase());
    }
    
    // 3. Channels / Layout
    if (track.channelLayout != null && track.channelLayout.isNotEmpty) {
      parts.add(track.channelLayout);
    } else if (track.channels > 0) {
      if (track.channels == 6) {
        parts.add('5.1');
      } else if (track.channels == 8) {
        parts.add('7.1');
      } else if (track.channels == 2) {
        parts.add('Stereo');
      } else {
        parts.add('${track.channels} ch');
      }
    }
    
    var label = parts.join(' • ');
    
    // 4. Default / Commentary tags
    final tags = <String>[];
    if (track.isDefault == true) {
      tags.add('Default');
    }
    if (track.title != null && track.title.toLowerCase().contains('commentary')) {
      tags.add('Commentary');
    }
    
    if (tags.isNotEmpty) {
      label += ' (${tags.join(', ')})';
    }
    
    return label;
  }

  String _formatEmbeddedSubLabel(dynamic track, int idx) {
    final parts = <String>[];
    parts.add(track.language != null && track.language.isNotEmpty ? track.language : 'Sub ${idx + 1}');
    
    if (track.codec != null && track.codec.isNotEmpty && track.codec != 'unknown') {
      parts.add(track.codec.toUpperCase());
    }
    
    var label = parts.join(' • ');
    final tags = <String>[];
    if (track.isDefault == true) tags.add('Default');
    if (track.isForced == true) tags.add('Forced');
    
    if (tags.isNotEmpty) {
      label += ' (${tags.join(', ')})';
    }
    
    return label;
  }

  String _formatExternalSubLabel(dynamic sub) {
    final label = sub.label ?? sub.language ?? 'External Subtitle';
    final details = <String>[];
    details.add(sub.source);
    
    if (sub.rating != null && sub.rating.isNotEmpty) {
      details.add(sub.rating);
    }
    
    return '$label • ${details.join(' • ')}';
  }
}
