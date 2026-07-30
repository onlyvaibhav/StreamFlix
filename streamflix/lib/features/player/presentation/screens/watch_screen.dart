import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/core/utils/native_controls.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';
import 'package:streamflix/features/player/presentation/widgets/player_controls.dart';
import 'package:streamflix/features/player/presentation/widgets/next_episode_overlay.dart';

class WatchScreen extends ConsumerStatefulWidget {
  final String movieId;
  final int? startTime;

  const WatchScreen({
    super.key,
    required this.movieId,
    this.startTime,
  });

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  
  // Gesture controls levels
  double _simulatedBrightness = 0.8;
  double _localVolume = 1.0;
  double _nativeBrightness = 1.0;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _hudTimer;

  // Tap accumulation seeking
  bool _showSeekFlash = false;
  bool _isSeekForwardFlash = false;
  Timer? _seekFlashTimer;
  int _accumulatedSeekSeconds = 0;
  Timer? _seekAccumulationTimer;
  DateTime? _lastTapTime;
  
  bool _initRequested = false;

  @override
  void initState() {
    super.initState();
    _setLandscapeOrientation();

    // Fetch initial native brightness on Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      NativeControls.getBrightness().then((val) {
        if (mounted) {
          setState(() {
            _nativeBrightness = val;
            _simulatedBrightness = val;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _seekFlashTimer?.cancel();
    _seekAccumulationTimer?.cancel();
    _restoreOrientation();
    super.dispose();
  }

  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  void _exitPlayer() {
    context.pop();
  }

  // Handle tap on left/right screen halves (Youtube/Netflix style tap accumulation)
  void _handleTap(bool isRightSide, mk.Player player, PlayerState playerState) {
    final now = DateTime.now();
    
    if (_lastTapTime != null && 
        now.difference(_lastTapTime!).inMilliseconds < 350) {
      // Rapid double-tap -> seek instantly, cancel show-controls timer
      _seekAccumulationTimer?.cancel();
      
      _accumulatedSeekSeconds += 10;
      
      setState(() {
        _showSeekFlash = true;
        _isSeekForwardFlash = isRightSide;
        // Keep controls visible during rapid taps, but don't toggle them
        _controlsVisible = true;
      });
      
      _executeImmediateSeek(10, isRightSide, player, playerState);
      
      // Auto-hide the flash indicator after 650ms of inactivity
      _seekFlashTimer?.cancel();
      _seekFlashTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) {
          setState(() {
            _showSeekFlash = false;
            _accumulatedSeekSeconds = 0;
          });
        }
      });
    } else {
      // Single tap -> Start timer. If another tap doesn't arrive in 300ms, toggle controls overlay
      _seekAccumulationTimer = Timer(const Duration(milliseconds: 300), () {
        if (_accumulatedSeekSeconds == 0) {
          _toggleControls();
        }
      });
    }
    _lastTapTime = now;
  }

  // Execute instant seek
  void _executeImmediateSeek(int seconds, bool isForward, mk.Player player, PlayerState playerState) {
    final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
    
    Duration currentPos = playerState.getGlobalPosition(player.state.position);
    Duration totalDur = playerState.getGlobalDuration(player.state.duration);

    Duration targetPos;
    if (isForward) {
      targetPos = currentPos + Duration(seconds: seconds);
      if (targetPos > totalDur) targetPos = totalDur;
    } else {
      targetPos = currentPos - Duration(seconds: seconds);
      if (targetPos.isNegative) targetPos = Duration.zero;
    }
    
    notifier.seekTo(targetPos);
  }

  // Handle vertical drag for simulated or native brightness
  void _handleBrightnessDragStart(DragStartDetails details) async {
    _hudTimer?.cancel();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final currentBrightness = await NativeControls.getBrightness();
      setState(() {
        _nativeBrightness = currentBrightness;
        _simulatedBrightness = currentBrightness;
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
      });
    } else {
      setState(() {
        _showBrightnessIndicator = true;
        _showVolumeIndicator = false;
      });
    }
  }

  void _handleBrightnessDragUpdate(DragUpdateDetails details) {
    final height = MediaQuery.of(context).size.height;
    // A vertical drag of 50% of the screen height covers the full brightness range
    final delta = -details.primaryDelta! / (height * 0.5);
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      final newBrightness = (_nativeBrightness + delta).clamp(0.01, 1.0);
      _nativeBrightness = newBrightness;
      _simulatedBrightness = newBrightness;
      NativeControls.setBrightness(newBrightness);
    } else {
      _simulatedBrightness = (_simulatedBrightness + delta).clamp(0.1, 1.0);
    }
    
    setState(() {});
    _startHudTimer();
  }

  // Handle vertical drag for player volume
  void _handleVolumeDragStart(DragStartDetails details, mk.Player player) async {
    _hudTimer?.cancel();
    setState(() {
      _localVolume = player.state.volume / 100.0;
      _showVolumeIndicator = true;
      _showBrightnessIndicator = false;
    });
  }

  void _handleVolumeDragUpdate(DragUpdateDetails details, mk.Player player) {
    final height = MediaQuery.of(context).size.height;
    // A vertical drag of 50% of the screen height covers 100% volume
    final delta = -details.primaryDelta! / (height * 0.5);
    final newVol = (_localVolume + delta).clamp(0.0, 2.0); // Allow up to 200%
    
    _localVolume = newVol;
    
    ref.read(moviePlayerProvider(widget.movieId).notifier).setVolume(newVol * 100.0);
    
    setState(() {});
    _startHudTimer();
  }

  void _startHudTimer() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showVolumeIndicator = false;
          _showBrightnessIndicator = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final movieAsync = ref.watch(movieDetailProvider(widget.movieId));
    final playerState = ref.watch(moviePlayerProvider(widget.movieId));

    // Listen for non-fatal errors to show a toast instead of a full page error
    ref.listen(moviePlayerProvider(widget.movieId).select((state) => state.nonFatalError), (previous, String? current) {
      if (current != null && current != previous) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(current, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.netflixRed,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Clear it so it can fire again if needed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(moviePlayerProvider(widget.movieId).notifier).clearNonFatalError();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: movieAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.netflixRed),
        ),
        error: (error, stack) => AppErrorWidget(
          error: error,
          onRetry: () {
            ref.invalidate(movieDetailProvider(widget.movieId));
            setState(() {
              _initRequested = false;
            });
          },
        ),
        data: (playingMovie) {
          if (!_initRequested && playerState.movie == null && playerState.error == null && !playerState.isLoading) {
            _initRequested = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(moviePlayerProvider(widget.movieId).notifier).play(
                playingMovie, 
                explicitStartTime: widget.startTime,
                targetEpisodeId: widget.movieId,
              );
            });
          }

          if (playerState.error != null) {
            return Center(
              child: AppErrorWidget(
                error: playerState.error!,
                onRetry: () {
                  ref.invalidate(moviePlayerProvider(widget.movieId));
                  ref.read(moviePlayerProvider(widget.movieId).notifier).play(
                    playingMovie, 
                    explicitStartTime: widget.startTime,
                    targetEpisodeId: widget.movieId,
                  );
                },
              ),
            );
          }

          return GestureDetector(
            onTapUp: (details) {
              final isRightSide = details.globalPosition.dx > MediaQuery.of(context).size.width / 2;
              _handleTap(isRightSide, playerState.player, playerState);
            },
            onVerticalDragStart: (details) {
              final isRightSide = details.globalPosition.dx > MediaQuery.of(context).size.width / 2;
              if (isRightSide) {
                _handleBrightnessDragStart(details);
              } else {
                _handleVolumeDragStart(details, playerState.player);
              }
            },
            onVerticalDragUpdate: (details) {
              final isRightSide = details.globalPosition.dx > MediaQuery.of(context).size.width / 2;
              if (isRightSide) {
                _handleBrightnessDragUpdate(details);
              } else {
                _handleVolumeDragUpdate(details, playerState.player);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // 1. Video view with custom Subtitle style
                Positioned.fill(
                  child: Video(
                    controller: playerState.videoController,
                    controls: NoVideoControls,
                    subtitleViewConfiguration: SubtitleViewConfiguration(
                      style: TextStyle(
                        fontSize: playerState.subtitleFontSize, // dynamically bound and increased by 2
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.black.withValues(alpha: 0.85), // black background box for high legibility
                      ),
                    ),
                  ),
                ),
              // 2. Loading overlay during part transitions and buffering
              StreamBuilder<bool>(
                stream: playerState.player.stream.buffering,
                builder: (context, snapshot) {
                  final isBuffering = snapshot.data ?? playerState.player.state.buffering;
                  if (playerState.isLoading || isBuffering) {
                    return Positioned.fill(
                      child: Container(
                        color: playerState.isLoading ? Colors.black : Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.netflixRed),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // 3. Double-Tap Seek Pulse Indicators
              if (_showSeekFlash)
                IgnorePointer(
                  child: Align(
                    alignment: _isSeekForwardFlash ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.35,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isSeekForwardFlash
                              ? [Colors.transparent, Colors.white12]
                              : [Colors.white12, Colors.transparent],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSeekForwardFlash ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_isSeekForwardFlash ? '+' : '-'}${_accumulatedSeekSeconds}s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. Simulated Dark-Overlay Brightness Filter (Only active on non-Android)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: defaultTargetPlatform == TargetPlatform.android
                        ? 0.0
                        : (1.0 - _simulatedBrightness).clamp(0.0, 0.85),
                  ),
                ),
              ),

              // 5. Volume HUD Slider Overlay
              if (_showVolumeIndicator)
                Positioned(
                  right: 48,
                  top: MediaQuery.of(context).size.height * 0.25,
                  bottom: MediaQuery.of(context).size.height * 0.25,
                  child: _buildHudIndicator(
                    icon: Icons.volume_up_rounded,
                    value: _localVolume,
                    isVolume: true,
                  ),
                ),

              // 6. Brightness HUD Slider Overlay
              if (_showBrightnessIndicator)
                Positioned(
                  left: 48,
                  top: MediaQuery.of(context).size.height * 0.25,
                  bottom: MediaQuery.of(context).size.height * 0.25,
                  child: _buildHudIndicator(
                    icon: Icons.brightness_6_rounded,
                    value: _simulatedBrightness,
                    isVolume: false,
                  ),
                ),

              // 7. Next Episode countdown card overlay
              StreamBuilder<Duration>(
                stream: playerState.player.stream.position,
                builder: (context, posSnapshot) {
                  final rawPosition = posSnapshot.data ?? Duration.zero;
                  final rawDuration = playerState.player.state.duration;
                  final position = playerState.getGlobalPosition(rawPosition);
                  final duration = playerState.getGlobalDuration(rawDuration);
                  
                  final nextEp = playerState.nextEpisode;
                  if (duration.inSeconds > 45 && 
                      position.inSeconds >= duration.inSeconds - 30 && 
                      nextEp != null) {
                    return Positioned(
                      bottom: 84,
                      right: 24,
                      child: NextEpisodeOverlay(
                        nextEpisode: nextEp,
                        movieId: widget.movieId,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // 8. Custom HUD Controls panel
              PlayerControls(
                movieId: widget.movieId,
                movieTitle: playingMovie.title,
                visible: _controlsVisible,
                onVisibilityChanged: (visible) {
                  setState(() {
                    _controlsVisible = visible;
                  });
                },
                onExit: _exitPlayer,
                isFullscreen: _isFullscreen,
                onFullscreenToggle: () {
                  setState(() {
                    _isFullscreen = !_isFullscreen;
                  });
                },
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHudIndicator({required IconData icon, required double value, required bool isVolume}) {
    IconData dynamicIcon = icon;
    Color accentColor = AppColors.netflixRed;
    
    if (isVolume) {
      if (value == 0) {
        dynamicIcon = Icons.volume_off_rounded;
      } else if (value > 1.0) {
        dynamicIcon = Icons.volume_up_rounded;
        accentColor = Colors.orangeAccent; // Highlight audio boost
      } else {
        dynamicIcon = Icons.volume_down_rounded;
      }
    }

    double fillRatio = isVolume ? (value / 2.0).clamp(0.0, 1.0) : value.clamp(0.0, 1.0);

    return Container(
      width: 48,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(dynamicIcon, color: Colors.white, size: 22),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fillRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
