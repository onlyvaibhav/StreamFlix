import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';

class PlaybackSyncDialog extends ConsumerWidget {
  final String movieId;

  const PlaybackSyncDialog({
    super.key,
    required this.movieId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(moviePlayerProvider(movieId));
    final notifier = ref.read(moviePlayerProvider(movieId).notifier);

    final subDelay = playerState.subtitleDelay;
    final audioDelay = playerState.audioDelay;
    final currentSpeed = playerState.player.state.rate;

    final signSub = subDelay >= 0 ? '+' : '';
    final signAudio = audioDelay >= 0 ? '+' : '';

    return AlertDialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.sync_alt_rounded, color: AppColors.netflixRed),
          const SizedBox(width: 10),
          const Text('Playback Sync', style: AppTextStyles.heading3),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle delay offset row
            const Text(
              'Subtitle Delay',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Offset: $signSub${subDelay.toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSyncAdjustButton(
                  label: '-0.5s',
                  onTap: () => notifier.setSubtitleDelay(subDelay - 0.5),
                ),
                _buildSyncAdjustButton(
                  label: '-0.1s',
                  onTap: () => notifier.setSubtitleDelay(subDelay - 0.1),
                ),
                _buildSyncResetButton(
                  onTap: subDelay == 0.0 ? null : () => notifier.setSubtitleDelay(0.0),
                ),
                _buildSyncAdjustButton(
                  label: '+0.1s',
                  onTap: () => notifier.setSubtitleDelay(subDelay + 0.1),
                ),
                _buildSyncAdjustButton(
                  label: '+0.5s',
                  onTap: () => notifier.setSubtitleDelay(subDelay + 0.5),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            // Audio delay offset row
            const Text(
              'Audio Sync Delay',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Offset: $signAudio${audioDelay.toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSyncAdjustButton(
                  label: '-0.5s',
                  onTap: () => notifier.setAudioDelay(audioDelay - 0.5),
                ),
                _buildSyncAdjustButton(
                  label: '-0.1s',
                  onTap: () => notifier.setAudioDelay(audioDelay - 0.1),
                ),
                _buildSyncResetButton(
                  onTap: audioDelay == 0.0 ? null : () => notifier.setAudioDelay(0.0),
                ),
                _buildSyncAdjustButton(
                  label: '+0.1s',
                  onTap: () => notifier.setAudioDelay(audioDelay + 0.1),
                ),
                _buildSyncAdjustButton(
                  label: '+0.5s',
                  onTap: () => notifier.setAudioDelay(audioDelay + 0.5),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),

            // Playback speed rate slider row
            const Text(
              'Playback Speed',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                  final isSelected = currentSpeed == speed;
                  return GestureDetector(
                    onTap: () => playerState.player.setRate(speed),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.netflixRed : Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: AppColors.netflixRed, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSyncAdjustButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSyncResetButton({required VoidCallback? onTap}) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.transparent : Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isDisabled ? Colors.white10 : Colors.white24),
        ),
        child: Icon(
          Icons.refresh_rounded,
          color: isDisabled ? Colors.white24 : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
