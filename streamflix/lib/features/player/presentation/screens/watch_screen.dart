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
  double _simulatedBrightness = 0.8;
  double _nativeVolume = 0.5;
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

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setLandscapeOrientation();

    // Fetch initial native volume & brightness on Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      NativeControls.getVolume().then((val) {
        if (mounted) setState(() => _nativeVolume = val);
      });
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
    
    final currentPos = playerState.isRemuxing
        ? player.state.position + Duration(milliseconds: (playerState.seekOffset * 1000).round())
        : player.state.position;
    final totalDur = playerState.isRemuxing
        ? Duration(seconds: playerState.duration.round())
        : player.state.duration;

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

  // Handle vertical drag for player volume (native or local)
  void _handleVolumeDragStart(DragStartDetails details, mk.Player player) async {
    _hudTimer?.cancel();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final currentVol = await NativeControls.getVolume();
      setState(() {
        _nativeVolume = currentVol;
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
      });
    } else {
      setState(() {
        _nativeVolume = player.state.volume / 100.0;
        _showVolumeIndicator = true;
        _showBrightnessIndicator = false;
      });
    }
  }

  void _handleVolumeDragUpdate(DragUpdateDetails details, mk.Player player) {
    final height = MediaQuery.of(context).size.height;
    // A vertical drag of 50% of the screen height covers the full volume range
    final delta = -details.primaryDelta! / (height * 0.5);
    final newVol = (_nativeVolume + delta).clamp(0.0, 1.0);
    
    _nativeVolume = newVol;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      NativeControls.setVolume(newVol);
      // Sync media-kit player volume
      ref.read(moviePlayerProvider(widget.movieId).notifier).setVolume(newVol * 100.0);
    } else {
      ref.read(moviePlayerProvider(widget.movieId).notifier).setVolume(newVol * 100.0);
    }
    
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
        data: (playingMovie) {
          if (playerState.movie == null && playerState.error == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(moviePlayerProvider(widget.movieId).notifier).play(playingMovie);
            });
          }

          if (playerState.error != null) {
            return Center(
              child: AppErrorWidget(
                error: playerState.error!,
                onRetry: () {
                  ref.invalidate(moviePlayerProvider(widget.movieId));
                  ref.read(moviePlayerProvider(widget.movieId).notifier).play(playingMovie);
                },
              ),
            );
          }

          return Stack(
            children: [
              // 1. Video view with custom Subtitle style
              Positioned.fill(
                child: Video(
                  controller: playerState.videoController,
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

              // 2. Gesture Detector halves (Swapped: Left for Volume, Right for Brightness)
              Row(
                children: [
                  // Left half: Volume drag
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleTap(false, playerState.player, playerState),
                      onVerticalDragStart: (details) => _handleVolumeDragStart(
                        details,
                        playerState.player,
                      ),
                      onVerticalDragUpdate: (details) => _handleVolumeDragUpdate(
                        details,
                        playerState.player,
                      ),
                      behavior: HitTestBehavior.translucent,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Right half: Brightness drag
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleTap(true, playerState.player, playerState),
                      onVerticalDragStart: _handleBrightnessDragStart,
                      onVerticalDragUpdate: _handleBrightnessDragUpdate,
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
                    value: _nativeVolume,
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
      width: 50,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.netflixRed,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.netflixRed.withValues(alpha: 0.5),
                        blurRadius: 6,
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
