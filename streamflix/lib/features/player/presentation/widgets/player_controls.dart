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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmallScreen = constraints.maxWidth < 600;
        final bool isVerySmallHeight = constraints.maxHeight < 400;
        
        final double playBtnSize = isSmallScreen || isVerySmallHeight ? 56.0 : 76.0;
        final double playIconSize = isSmallScreen || isVerySmallHeight ? 36.0 : 48.0;
        
        final double sideBtnSize = isSmallScreen || isVerySmallHeight ? 44.0 : 54.0;
        final double sideIconSize = isSmallScreen || isVerySmallHeight ? 28.0 : 32.0;
        
        final double centerSpacing = isSmallScreen || isVerySmallHeight ? 32.0 : 64.0;

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
          // Top bar (back button)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMedium),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: widget.onExit,
                  tooltip: 'Back',
                ),
              ),
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
                  // Seek bar + Time display
                  Row(
                    children: [
                      Expanded(
                        child: SeekBar(
                          movieId: widget.movieId,
                          onDragStart: () {
                            setState(() { _isDragging = true; });
                            _hideTimer?.cancel();
                          },
                          onDragEnd: () {
                            setState(() { _isDragging = false; });
                            _startHideTimer();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Time display
                      StreamBuilder<Duration>(
                        stream: player.stream.position,
                        builder: (context, positionSnapshot) {
                          return StreamBuilder<Duration>(
                            stream: player.stream.duration,
                            builder: (context, durationSnapshot) {
                              final rawPosition = positionSnapshot.data ?? Duration.zero;
                              final rawDuration = durationSnapshot.data ?? Duration.zero;
                              
                              bool isMultipart = playerState.splitParts.isNotEmpty;
                              
                              Duration position = rawPosition;
                              Duration duration = rawDuration;

                              if (isMultipart) {
                                double accumulated = 0.0;
                                for (int i = 0; i < playerState.currentPartIndex; i++) {
                                  accumulated += playerState.splitParts[i].duration ?? 0.0;
                                }
                                position = rawPosition + Duration(milliseconds: (accumulated * 1000).round());
                                duration = Duration(seconds: playerState.duration.round());
                              } else if (playerState.isRemuxing) {
                                position = rawPosition + Duration(milliseconds: (playerState.seekOffset * 1000).round());
                                if (playerState.duration > 0) {
                                  duration = Duration(seconds: playerState.duration.round());
                                }
                              }

                              return Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bottom buttons row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // LEFT CONTROLS
                      Expanded(
                        child: StreamBuilder<bool>(
                          stream: player.stream.playing,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
                            
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Play / Pause
                                playerState.isLoading 
                                  ? Container(
                                      width: 40,
                                      height: 40,
                                      padding: const EdgeInsets.all(8),
                                      child: const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      icon: Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                      onPressed: () {
                                        _onUserInteraction();
                                        notifier.playOrPause();
                                      },
                                    ),
                                
                                const SizedBox(width: 4),
                                
                                // Rewind 10s
                                IconButton(
                                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                                  onPressed: () {
                                    _onUserInteraction();
                                    final currentPos = playerState.isRemuxing
                                        ? player.state.position + Duration(milliseconds: (playerState.seekOffset * 1000).round())
                                        : player.state.position;
                                    final targetPos = currentPos - const Duration(seconds: 10);
                                    notifier.seekTo(targetPos.isNegative ? Duration.zero : targetPos);
                                  },
                                ),
                                
                                const SizedBox(width: 4),
                                
                                // Fast Forward 10s
                                IconButton(
                                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                                  onPressed: () {
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
                                ),
                                
                                const SizedBox(width: 8),
                                
                                // Volume Control
                                _buildVolumeControl(player, isSmallScreen),

                                if (!isSmallScreen) ...[
                                  const SizedBox(width: 24),
                                  
                                  // Title
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: _buildTitleSection(playerState),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      
                      // RIGHT CONTROLS
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Next Episode button
                          if (playerState.tvSeasons.isNotEmpty && playerState.nextEpisode != null) ...[
                            IconButton(
                              onPressed: () {
                                _onUserInteraction();
                                ref.read(moviePlayerProvider(widget.movieId).notifier).playNextEpisode();
                              },
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
                              tooltip: 'Next Episode',
                            ),
                            const SizedBox(width: 4),
                          ],

                          // Episodes List
                          if (playerState.tvSeasons.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.library_books_rounded, color: Colors.white, size: 24),
                              onPressed: () {
                                _onUserInteraction();
                                showGeneralDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  barrierLabel: 'Dismiss',
                                  barrierColor: Colors.black.withValues(alpha: 0.4),
                                  pageBuilder: (context, anim1, anim2) => EpisodeListSheet(movieId: widget.movieId),
                                );
                              },
                              tooltip: 'Episodes',
                            ),
                            const SizedBox(width: 4),
                          ],

                          // Subtitle selector
                          SubtitleSelector(movieId: widget.movieId),
                          
                          const SizedBox(width: 4),

                          // Playback Speed
                          StreamBuilder<double>(
                            stream: player.stream.rate,
                            builder: (context, rateSnapshot) {
                              final currentSpeed = rateSnapshot.data ?? 1.0;
                              return PopupMenuButton<double>(
                                initialValue: currentSpeed,
                                icon: const Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                                tooltip: 'Playback Speed',
                                color: AppColors.backgroundCard,
                                onSelected: (speed) async {
                                  _onUserInteraction();
                                  await player.setRate(speed);
                                },
                                itemBuilder: (context) => [
                                  0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0,
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

                          const SizedBox(width: 4),

                          // Fullscreen toggle
                          IconButton(
                            icon: Icon(
                              widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              _onUserInteraction();
                              widget.onFullscreenToggle();
                            },
                            tooltip: widget.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                          ),
                        ],
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
      },
    );
  }

  Widget _buildVolumeControl(mk.Player player, bool isSmallScreen) {
    if (isSmallScreen) {
      // Show only mute button on very small screens to save space
      return StreamBuilder<double>(
        stream: player.stream.volume,
        builder: (context, snapshot) {
          final volume = snapshot.data ?? 100.0;
          final isMuted = volume == 0.0;
          return IconButton(
            icon: Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              _onUserInteraction();
              player.setVolume(isMuted ? 80.0 : 0.0);
            },
            tooltip: isMuted ? 'Unmute' : 'Mute',
          );
        },
      );
    }

    return StreamBuilder<double>(
      stream: player.stream.volume,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 100.0;
        final isMuted = volume == 0.0;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isMuted
                    ? Icons.volume_off_rounded
                    : volume < 50
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {
                _onUserInteraction();
                player.setVolume(isMuted ? 80.0 : 0.0);
              },
              tooltip: isMuted ? 'Unmute' : 'Mute',
            ),
            SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: AppColors.netflixRed,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: AppColors.netflixRed,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                ),
                child: Slider(
                  value: volume.clamp(0.0, 150.0),
                  min: 0.0,
                  max: 150.0,
                  onChanged: (val) {
                    _onUserInteraction();
                    player.setVolume(val);
                  },
                ),
              ),
            ),
          ],
        );
      },
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

  List<Widget> _buildTitleSection(PlayerState playerState) {
    final movie = playerState.movie;
    if (movie == null) {
      return [
        Text(
          widget.movieTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ];
    }

    String? mainTitle;
    String? subTitle;

    if (movie.tv != null) {
      mainTitle = movie.tv!.showTitle;
      subTitle = 'S${movie.tv!.seasonNumber}:E${movie.tv!.episodeNumber} (${movie.title})';
    } else if (movie.seasonNumber != null && movie.episodeNumber != null) {
      mainTitle = movie.title;
      subTitle = 'S${movie.seasonNumber}:E${movie.episodeNumber}';
    } else {
      mainTitle = movie.title;
    }

    return [
      Text(
        mainTitle,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (subTitle != null) ...[
        const SizedBox(height: 4),
        Text(
          subTitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ];
  }
}
