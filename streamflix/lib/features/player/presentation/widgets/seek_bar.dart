import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';

/// Custom seek bar with buffered range visualization
class SeekBar extends ConsumerStatefulWidget {
  final String movieId;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const SeekBar({
    super.key,
    required this.movieId,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(moviePlayerProvider(widget.movieId));
    final player = playerState.player;

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (context, durationSnapshot) {
            return StreamBuilder<Duration>(
              stream: player.stream.buffer,
              builder: (context, bufferSnapshot) {
                final rawPosition = positionSnapshot.data ?? Duration.zero;
                final rawDuration = durationSnapshot.data ?? Duration.zero;
                final rawBuffer = bufferSnapshot.data ?? Duration.zero;

                final position = playerState.isRemuxing
                    ? rawPosition + Duration(milliseconds: (playerState.seekOffset * 1000).round())
                    : rawPosition;

                final duration = (playerState.isRemuxing && playerState.duration > 0)
                    ? Duration(seconds: playerState.duration.round())
                    : rawDuration;

                final buffer = playerState.isRemuxing
                    ? rawBuffer + Duration(milliseconds: (playerState.seekOffset * 1000).round())
                    : rawBuffer;

                final durationMs = duration.inMilliseconds;
                if (durationMs == 0) {
                  return const LinearProgressIndicator(
                    backgroundColor: AppColors.textTertiary,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.netflixRed,
                    ),
                  );
                }

                final positionValue = position.inMilliseconds / durationMs;
                final bufferValue = buffer.inMilliseconds / durationMs;
                final sliderValue = _dragValue ?? positionValue;

                return SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: AppColors.netflixRed,
                    inactiveTrackColor: AppColors.textTertiary.withValues(alpha: 0.3),
                    thumbColor: AppColors.netflixRed,
                    overlayColor: AppColors.netflixRed.withValues(alpha: 0.3),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Buffered range indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: bufferValue.clamp(0.0, 1.0),
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Main slider
                      Slider(
                        value: sliderValue.clamp(0.0, 1.0),
                        onChanged: (value) {
                          setState(() {
                            _dragValue = value;
                          });
                        },
                        onChangeStart: (value) {
                          widget.onDragStart?.call();
                          setState(() {
                            _dragValue = value;
                          });
                        },
                        onChangeEnd: (value) {
                          final seekPosition = Duration(
                            milliseconds: (value * durationMs).round(),
                          );
                          ref.read(moviePlayerProvider(widget.movieId).notifier)
                              .seekTo(seekPosition);
                          
                          setState(() {
                            _dragValue = null;
                          });
                          
                          widget.onDragEnd?.call();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
