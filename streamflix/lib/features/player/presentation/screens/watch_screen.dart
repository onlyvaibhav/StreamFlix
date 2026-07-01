import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:streamflix/core/constants/app_colors.dart';
import 'package:streamflix/core/widgets/error_widget.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/player/presentation/providers/player_provider.dart';
import 'package:streamflix/features/player/presentation/widgets/player_controls.dart';
import 'package:streamflix/features/player/presentation/widgets/next_episode_overlay.dart';

class WatchScreen extends ConsumerStatefulWidget {
  final String movieId;

  const WatchScreen({
    super.key,
    required this.movieId,
  });

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  bool _controlsVisible = true;
  bool _isFullscreen = false;
  
  // Gesture controls levels
  double _simulatedBrightness = 0.8; // default simulated brightness level (0.1 to 1.0)
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
  bool _isRightSideTap = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setLandscapeOrientation();
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _seekFlashTimer?.cancel();
    _seekAccumulationTimer?.cancel();
    _restoreOrientation();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    Future.microtask(() {
      if (!mounted) return;
      final movieAsync = ref.read(movieDetailProvider(widget.movieId));
      if (movieAsync is AsyncData<Movie>) {
        final playerNotifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
        playerNotifier.play(movieAsync.value);
      }
    });
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
    _isRightSideTap = isRightSide;
    
    if (_lastTapTime != null && 
        now.difference(_lastTapTime!).inMilliseconds < 350) {
      // Rapid tap -> Accumulate seek duration
      _seekAccumulationTimer?.cancel();
      _accumulatedSeekSeconds += 10;
      
      setState(() {
        _showSeekFlash = true;
        _isSeekForwardFlash = isRightSide;
        _controlsVisible = true; // briefly display seek bar HUD
      });
      
      _seekAccumulationTimer = Timer(const Duration(milliseconds: 550), () {
        _executeAccumulatedSeek(player, playerState);
      });
    } else {
      // Single tap or first tap in session -> Wait to check if a second tap comes
      _seekAccumulationTimer = Timer(const Duration(milliseconds: 250), () {
        if (_accumulatedSeekSeconds == 0) {
          _toggleControls();
        }
      });
    }
    _lastTapTime = now;
  }

  // Execute seek of cumulative duration
  void _executeAccumulatedSeek(mk.Player player, PlayerState playerState) {
    if (_accumulatedSeekSeconds == 0) return;
    
    final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
    final isForward = _isRightSideTap;
    
    final currentPos = playerState.isRemuxing
        ? player.state.position + Duration(milliseconds: (playerState.seekOffset * 1000).round())
        : player.state.position;
    final totalDur = playerState.isRemuxing
        ? Duration(seconds: playerState.duration.round())
        : player.state.duration;

    Duration targetPos;
    if (isForward) {
      targetPos = currentPos + Duration(seconds: _accumulatedSeekSeconds);
      if (targetPos > totalDur) targetPos = totalDur;
      debugPrint('⏩ Seeking forward $_accumulatedSeekSeconds to $targetPos');
    } else {
      targetPos = currentPos - Duration(seconds: _accumulatedSeekSeconds);
      if (targetPos.isNegative) targetPos = Duration.zero;
      debugPrint('⏪ Seeking backward $_accumulatedSeekSeconds to $targetPos');
    }
    
    notifier.seekTo(targetPos);
    
    _seekFlashTimer?.cancel();
    _seekFlashTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        setState(() {
          _showSeekFlash = false;
          _accumulatedSeekSeconds = 0;
        });
      }
    });
  }

  // Handle vertical drag for simulated brightness
  void _handleBrightnessDrag(DragUpdateDetails details) {
    final height = MediaQuery.of(context).size.height;
    final delta = -details.primaryDelta! / height;
    
    setState(() {
      _simulatedBrightness = (_simulatedBrightness + delta).clamp(0.1, 1.0);
      _showBrightnessIndicator = true;
      _showVolumeIndicator = false;
    });
    
    _startHudTimer();
  }

  // Handle vertical drag for player volume
  void _handleVolumeDrag(DragUpdateDetails details, mk.Player player) {
    final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
    final currentVol = player.state.volume;
    
    final delta = -details.primaryDelta! / 4.0;
    final newVol = (currentVol + delta).clamp(0.0, 100.0);
    
    notifier.setVolume(newVol);
    
    setState(() {
      _showVolumeIndicator = true;
      _showBrightnessIndicator = false;
    });
    
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
            _initializePlayer();
          },
        ),
        data: (movie) {
          if (playerState.movie == null && playerState.error == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(moviePlayerProvider(widget.movieId).notifier).play(movie);
            });
          }

          if (playerState.error != null) {
            return AppErrorWidget(
              error: playerState.error!,
              onRetry: () async {
                final notifier = ref.read(moviePlayerProvider(widget.movieId).notifier);
                await notifier.play(movie);
              },
            );
          }

          final playingMovie = playerState.movie ?? movie;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Native Video Player Layer
              Center(
                child: Video(
                  controller: playerState.videoController,
                  controls: NoVideoControls,
                ),
              ),

              // 2. Gesture Detector Touch Halves Overlay
              Row(
                children: [
                  // Left half: Brightness swipe & Double-tap Rewind
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleTap(false, playerState.player, playerState),
                      onVerticalDragUpdate: _handleBrightnessDrag,
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Right half: Volume swipe & Double-tap Fast-Forward
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleTap(true, playerState.player, playerState),
                      onVerticalDragUpdate: (details) => _handleVolumeDrag(
                        details,
                        playerState.player,
                      ),
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
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
                              _isSeekForwardFlash
                                  ? '+${_accumulatedSeekSeconds}s ⏩'
                                  : '⏪ -${_accumulatedSeekSeconds}s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. Simulated Dark-Overlay Brightness Filter
              IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: (1.0 - _simulatedBrightness).clamp(0.0, 0.85),
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
                    value: playerState.player.state.volume / 100.0,
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
                  ),
                ),

              // 7. Next Episode countdown card overlay
              StreamBuilder<Duration>(
                stream: playerState.player.stream.position,
                builder: (context, posSnapshot) {
                  final position = posSnapshot.data ?? Duration.zero;
                  final duration = playerState.isRemuxing && playerState.duration > 0
                      ? Duration(seconds: playerState.duration.round())
                      : playerState.player.state.duration;
                  
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
          );
        },
      ),
    );
  }

  Widget _buildHudIndicator({required IconData icon, required double value}) {
    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 12),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.netflixRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
