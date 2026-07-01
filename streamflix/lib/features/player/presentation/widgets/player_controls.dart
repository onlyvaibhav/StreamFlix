import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/constants/app_dimensions.dart';
import 'package:streamflix/core/constants/app_text_styles.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';
import 'package:streamflix/features/player/presentation/widgets/seek_bar.dart';
import 'package:streamflix/features/subtitles/presentation/widgets/subtitle_selector.dart';
import 'package:streamflix/features/player/presentation/widgets/sync_selector.dart';
import 'package:streamflix/features/player/presentation/widgets/episode_list_sheet.dart';

/// Custom video player controls with auto-hide
class PlayerControls extends ConsumerStatefulWidget {
  final String movieId;
  final String movieTitle;
  final bool visible;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onExit;
  final bool isFullscreen;
  final VoidCallback onFullscreenToggle;

  const PlayerControls({
    super.key,
    required this.movieId,
    required this.movieTitle,
    required this.visible,
    required this.onVisibilityChanged,
    required this.onExit,
    required this.isFullscreen,
    required this.onFullscreenToggle,
  });

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  Timer? _hideTimer;
  bool _isDragging = false;

  @override
  void didUpdateWidget(PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _startHideTimer();
    } else if (!widget.visible && oldWidget.visible) {
      _hideTimer?.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isDragging) {
        widget.onVisibilityChanged(false);
      }
    });
  }

  void _onUserInteraction() {
    if (!widget.visible) {
      widget.onVisibilityChanged(true);
    } else {
      _startHideTimer();
    }
  }

  KeyEventResult _handleKeyPress(KeyEvent event) {
    _onUserInteraction();
    final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
    final playerState = ref.read(moviePlayerProvider(widget.movieId));

    if (event.logicalKey == LogicalKeyboardKey.space) {
      notifier.playOrPause();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final currentPos = playerState.player.state.position;
      notifier.seekTo(currentPos - const Duration(seconds: 10));
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final currentPos = playerState.player.state.position;
      notifier.seekTo(currentPos + const Duration(seconds: 10));
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onExit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(moviePlayerProvider(widget.movieId));
    final player = playerState.player;

    // Listen to keyboard events on web
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          return _handleKeyPress(event);
        }
        return KeyEventResult.ignored;
      },
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedOpacity(
          opacity: widget.visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _buildControls(context, player, playerState),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, mk.Player player, PlayerState playerState) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top bar (title + back button)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMedium),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: widget.onExit,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getPlayerTitle(playerState),
                      style: AppTextStyles.heading3.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Center controls: Previous Episode, Rewind 10s, Play/Pause, Fast Forward 10s, Next Episode
          Center(
            child: StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
                
                final prevEp = playerState.previousEpisode;
                final nextEp = playerState.nextEpisode;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // TV Show Previous Episode Button
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, size: 36),
                      color: Colors.white,
                      disabledColor: Colors.white24,
                      onPressed: prevEp == null ? null : () {
                        _onUserInteraction();
                        notifier.playPreviousEpisode();
                      },
                      tooltip: 'Previous Episode',
                    ),
                    const SizedBox(width: 24),

                    // Rewind 10s
                    GestureDetector(
                      onTap: () {
                        _onUserInteraction();
                        final currentPos = playerState.isRemuxing
                            ? player.state.position + Duration(milliseconds: (playerState.seekOffset * 1000).round())
                            : player.state.position;
                        final targetPos = currentPos - const Duration(seconds: 10);
                        notifier.seekTo(targetPos.isNegative ? Duration.zero : targetPos);
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.replay_10_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Play / Pause
                    GestureDetector(
                      onTap: () {
                        _onUserInteraction();
                        notifier.playOrPause();
                      },
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Fast Forward 10s
                    GestureDetector(
                      onTap: () {
                        _onUserInteraction();
                        final currentPos = playerState.isRemuxing
                            ? player.state.position + Duration(milliseconds: (playerState.seekOffset * 1000).round())
                            : player.state.position;
                        final totalDur = playerState.isRemuxing
                            ? Duration(seconds: playerState.duration.round())
                            : player.state.duration;
                        final targetPos = currentPos + const Duration(seconds: 10);
                        notifier.seekTo(targetPos > totalDur ? totalDur : targetPos);
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.forward_10_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // TV Show Next Episode Button
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, size: 36),
                      color: Colors.white,
                      disabledColor: Colors.white24,
                      onPressed: nextEp == null ? null : () {
                        _onUserInteraction();
                        notifier.playNextEpisode();
                      },
                      tooltip: 'Next Episode',
                    ),
                  ],
                );
              },
            ),
          ),

          const Spacer(),

          // Bottom controls (seek bar + buttons)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMedium),
              child: Column(
                children: [
                  // Seek bar
                  SeekBar(
                    movieId: widget.movieId,
                    onDragStart: () {
                      setState(() {
                        _isDragging = true;
                      });
                      _hideTimer?.cancel();
                    },
                    onDragEnd: () {
                      setState(() {
                        _isDragging = false;
                      });
                      _startHideTimer();
                    },
                  ),
                  const SizedBox(height: 8),

                  // Bottom buttons row
                  Row(
                    children: [
                      // Play / Pause mini button
                      StreamBuilder<bool>(
                        stream: player.stream.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              _onUserInteraction();
                              ref.read(moviePlayerProvider(widget.movieId).notifier)
                                  .playOrPause();
                            },
                          );
                        },
                      ),

                      const SizedBox(width: 8),

                      // Time display
                      StreamBuilder<Duration>(
                        stream: player.stream.position,
                        builder: (context, positionSnapshot) {
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            builder: (context, durationSnapshot) {
                              final rawPosition = positionSnapshot.data ?? Duration.zero;
                              final rawDuration = durationSnapshot.data ?? Duration.zero;
                              
                              final position = playerState.isRemuxing
                                  ? rawPosition + Duration(milliseconds: (playerState.seekOffset * 1000).round())
                                  : rawPosition;
                              
                              final duration = (playerState.isRemuxing && playerState.duration > 0)
                                  ? Duration(seconds: playerState.duration.round())
                                  : rawDuration;

                              return Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const Spacer(),

                      // Subtitle selector
                      SubtitleSelector(movieId: widget.movieId),

                      const SizedBox(width: 8),

                      // In-Player TV Episode List navigation
                      if (playerState.tvSeasons.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white, size: 24),
                          onPressed: () {
                            _onUserInteraction();
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => EpisodeListSheet(movieId: widget.movieId),
                            );
                          },
                          tooltip: 'Episodes',
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Sync settings selector
                      IconButton(
                        icon: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 24),
                        onPressed: () {
                          _onUserInteraction();
                          showDialog(
                            context: context,
                            builder: (context) => PlaybackSyncDialog(movieId: widget.movieId),
                          );
                        },
                        tooltip: 'Playback Sync',
                      ),

                      const SizedBox(width: 8),

                      // Volume Control
                      _buildVolumeControl(player),

                      const SizedBox(width: 8),

                      // Playback Speed Selector (Reactive)
                      StreamBuilder<double>(
                        stream: player.stream.rate,
                        builder: (context, rateSnapshot) {
                          final currentSpeed = rateSnapshot.data ?? 1.0;
                          return PopupMenuButton<double>(
                            initialValue: currentSpeed,
                            icon: Text(
                              '${currentSpeed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            tooltip: 'Playback Speed',
                            color: AppColors.backgroundCard,
                            onSelected: (speed) async {
                              _onUserInteraction();
                              await player.setRate(speed);
                            },
                            itemBuilder: (context) => [
                              0.25,
                              0.5,
                              0.75,
                              1.0,
                              1.25,
                              1.5,
                              2.0,
                            ].map((speed) {
                              final isSelected = currentSpeed == speed;
                              return PopupMenuItem<double>(
                                value: speed,
                                child: Text(
                                  speed == 1.0 ? 'Normal' : '${speed}x',
                                  style: TextStyle(
                                    color: isSelected ? AppColors.netflixRed : Colors.white,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(width: 8),

                      // Fullscreen toggle
                      IconButton(
                        icon: Icon(
                          widget.isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _onUserInteraction();
                          widget.onFullscreenToggle();
                        },
                        tooltip: widget.isFullscreen
                            ? 'Exit fullscreen'
                            : 'Fullscreen',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl(mk.Player player) {
    return PopupMenuButton<void>(
      icon: const Icon(Icons.volume_up, color: Colors.white),
      tooltip: 'Volume',
      color: AppColors.backgroundCard,
      offset: const Offset(0, -200),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            height: 150,
            child: StreamBuilder<double>(
              stream: player.stream.volume,
              builder: (context, snapshot) {
                final volume = snapshot.data ?? 100.0;
                
                return RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: const SliderThemeData(
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: volume,
                      min: 0.0,
                      max: 100.0,
                      activeColor: AppColors.netflixRed,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        _onUserInteraction();
                        player.setVolume(val);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString();
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _getPlayerTitle(PlayerState playerState) {
    final movie = playerState.movie;
    if (movie == null) return widget.movieTitle;
    
    if (movie.tv != null) {
      final showName = movie.tv!.showTitle;
      final seasonStr = 'S${movie.tv!.seasonNumber.toString().padLeft(2, '0')}';
      final episodeStr = 'E${movie.tv!.episodeNumber.toString().padLeft(2, '0')}';
      final epTitle = movie.title;
      return '$showName ($seasonStr$episodeStr • $epTitle)';
    } else if (movie.seasonNumber != null && movie.episodeNumber != null) {
      final showName = movie.title;
      final seasonStr = 'S${movie.seasonNumber!.toString().padLeft(2, '0')}';
      final episodeStr = 'E${movie.episodeNumber!.toString().padLeft(2, '0')}';
      return '$showName ($seasonStr$episodeStr)';
    } else {
      return movie.title;
    }
  }
}
