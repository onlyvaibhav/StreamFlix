import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:streamflix/core/config/app_config.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/split_part.dart';
import 'package:streamflix/features/player/data/models/stream_track.dart';
import 'package:streamflix/features/player/data/models/external_subtitle.dart';
import 'package:streamflix/features/movies/data/models/season_info.dart';
import 'package:streamflix/features/movies/data/models/watch_history.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';
import 'package:streamflix/features/movies/data/repositories/movie_repository_impl.dart';
import 'package:streamflix/features/player/data/datasources/stream_remote_datasource.dart';

part 'player_provider.g.dart';

/// Complete player state including track info, subtitles, delays, tv show info, and streaming mode
class PlayerState {
  final mk.Player player;
  final VideoController videoController;
  final bool isInitialized;
  final bool isLoading;
  final String? error;

  // Active movie details
  final Movie? movie;
  final List<SeasonInfo> tvSeasons;

  // Track probe results
  final TrackInfo? trackInfo;
  final List<ExternalSubtitle> externalSubtitles;

  // Current selections
  final int currentAudioTrack;
  final int currentSubtitleTrack; // -1 = off, >=0 = embedded index, >=100 = external subtitle

  // Synchronization offsets
  final double subtitleDelay; // in seconds
  final double audioDelay;    // in seconds
  
  // Subtitle font size
  final double subtitleFontSize;
  
  // Multipart movie details
  final List<SplitPart> splitParts;
  final int currentPartIndex;
  
  // Streaming mode
  final bool isRemuxing;
  final double seekOffset; // Virtual offset for remux seek
  final double duration;   // Total duration from track probe

  PlayerState({
    required this.player,
    required this.videoController,
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.movie,
    this.tvSeasons = const [],
    this.trackInfo,
    this.externalSubtitles = const [],
    this.currentAudioTrack = 0,
    this.currentSubtitleTrack = -1,
    this.subtitleDelay = 0.0,
    this.audioDelay = 0.0,
    this.subtitleFontSize = 44.0,
    this.splitParts = const [],
    this.currentPartIndex = 0,
    this.isRemuxing = false,
    this.seekOffset = 0,
    this.duration = 0,
  });

  PlayerState copyWith({
    mk.Player? player,
    VideoController? videoController,
    bool? isInitialized,
    bool? isLoading,
    String? error,
    Movie? movie,
    List<SeasonInfo>? tvSeasons,
    TrackInfo? trackInfo,
    List<ExternalSubtitle>? externalSubtitles,
    int? currentAudioTrack,
    int? currentSubtitleTrack,
    double? subtitleDelay,
    double? audioDelay,
    double? subtitleFontSize,
    List<SplitPart>? splitParts,
    int? currentPartIndex,
    bool? isRemuxing,
    double? seekOffset,
    double? duration,
  }) {
    return PlayerState(
      player: player ?? this.player,
      videoController: videoController ?? this.videoController,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      movie: movie ?? this.movie,
      tvSeasons: tvSeasons ?? this.tvSeasons,
      trackInfo: trackInfo ?? this.trackInfo,
      externalSubtitles: externalSubtitles ?? this.externalSubtitles,
      currentAudioTrack: currentAudioTrack ?? this.currentAudioTrack,
      currentSubtitleTrack: currentSubtitleTrack ?? this.currentSubtitleTrack,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      audioDelay: audioDelay ?? this.audioDelay,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      splitParts: splitParts ?? this.splitParts,
      currentPartIndex: currentPartIndex ?? this.currentPartIndex,
      isRemuxing: isRemuxing ?? this.isRemuxing,
      seekOffset: seekOffset ?? this.seekOffset,
      duration: duration ?? this.duration,
    );
  }

  // Getters to resolve current episode, next episode, and previous episode
  Movie? get currentEpisode {
    if (movie == null || tvSeasons.isEmpty) return null;
    for (final season in tvSeasons) {
      for (final ep in season.episodes) {
        if (ep.id == movie!.id) return ep;
      }
    }
    return null;
  }

  Movie? get nextEpisode {
    if (movie == null || tvSeasons.isEmpty) return null;
    final flatEpisodes = tvSeasons.expand((s) => s.episodes).toList();
    final idx = flatEpisodes.indexWhere((ep) => ep.id == movie!.id);
    if (idx >= 0 && idx < flatEpisodes.length - 1) {
      return flatEpisodes[idx + 1];
    }
    return null;
  }

  Movie? get previousEpisode {
    if (movie == null || tvSeasons.isEmpty) return null;
    final flatEpisodes = tvSeasons.expand((s) => s.episodes).toList();
    final idx = flatEpisodes.indexWhere((ep) => ep.id == movie!.id);
    if (idx > 0) {
      return flatEpisodes[idx - 1];
    }
    return null;
  }
}

/// Provider for video player instance with full streaming pipeline
@riverpod
class MoviePlayer extends _$MoviePlayer {
  Timer? _heartbeatTimer;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _positionSubscription;
  String? _currentFileId;

  @override
  PlayerState build(String movieId) {
    // Initialize MediaKit Player
    final player = mk.Player();
    
    // Explicitly set start volume to 100% (full scale)
    player.setVolume(100.0);
    
    // Set safe native properties for stability (auto-safe hardware acceleration with fallback)
    try {
      final platform = player.platform;
      if (platform != null) {
        final dynamic dynPlatform = platform;
        dynPlatform.setProperty('hwdec', 'auto-safe');
        dynPlatform.setProperty('volume-max', '150');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to apply native hardware properties: $e');
    }

    final videoController = VideoController(player);

    // Listen to player error stream
    _errorSubscription = player.stream.error.listen((error) {
      final errStr = error.toString();
      debugPrint('❌ MediaKit Player error: $errStr');
      
      // Ignore non-fatal play promise interruptions on Web/Chrome
      if (errStr.contains('play() request was interrupted') || 
          errStr.contains('media was removed from the document')) {
        debugPrint('ℹ️ Ignoring benign play promise interruption.');
        return;
      }
      
      state = state.copyWith(error: errStr);
    });

    // Clean up when provider is disposed
    ref.onDispose(() {
      debugPrint('🎬 Disposing player for movie $movieId');
      _stopHeartbeat();
      _errorSubscription?.cancel();
      _positionSubscription?.cancel();
      player.dispose();
    });

    // Register completion listener for sequential playback of split parts
    player.stream.completed.listen((completed) {
      if (completed) {
        _handlePlaybackCompleted();
      }
    });

    return PlayerState(
      player: player,
      videoController: videoController,
    );
  }

  /// Full player startup: probe tracks, fetch subtitles, determine mode, start stream
  Future<void> play(Movie movie, {bool keepSettings = false}) async {
    // Store configurations if we want to carry settings forward
    final prevSubDelay = state.subtitleDelay;
    final prevAudioDelay = state.audioDelay;
    final prevRate = state.player.state.rate;
    final prevAudioIndex = state.currentAudioTrack;
    final prevSubtitleIndex = state.currentSubtitleTrack;

    String? prevAudioLang;
    String? prevSubLang;
    bool wasSubExternal = false;

    if (keepSettings && state.trackInfo != null) {
      wasSubExternal = prevSubtitleIndex >= 100;
      if (prevAudioIndex >= 0 && prevAudioIndex < state.trackInfo!.audioTracks.length) {
        prevAudioLang = state.trackInfo!.audioTracks[prevAudioIndex].language;
      }
      if (prevSubtitleIndex >= 0) {
        if (wasSubExternal) {
          final extIdx = prevSubtitleIndex - 100;
          if (extIdx < state.externalSubtitles.length) {
            prevSubLang = state.externalSubtitles[extIdx].language;
          }
        } else if (prevSubtitleIndex < (state.trackInfo?.subtitleTracks.length ?? 0)) {
          prevSubLang = state.trackInfo!.subtitleTracks[prevSubtitleIndex].language;
        }
      }
    }

    try {
      state = state.copyWith(isLoading: true, error: null);

      Movie mediaToPlay = movie;
      List<SeasonInfo> tvSeasons = keepSettings ? state.tvSeasons : [];
      List<SplitPart> splitParts = movie.parts ?? [];
      int currentPartIndex = 0;

      // If playing a TV show series container (NOT an individual episode), auto-resolve to S1E1
      if (movie.type == 'tv' && movie.tv == null && (movie.seasons == null || movie.seasons!.isEmpty)) {
        debugPrint('📺 Play request for TV Show series ${movie.id} - Fetching show details...');
        final showTmdbId = movie.tv?.showTmdbId ?? movie.tmdbId;
        if (showTmdbId != null) {
          try {
            final tvShow = await ref.read(movieRepositoryProvider).getTvShowById(showTmdbId.toString());
            tvSeasons = tvShow.seasons;
            if (tvSeasons.isNotEmpty) {
              final firstEp = tvSeasons.first.episodes.firstOrNull;
              if (firstEp != null) {
                mediaToPlay = firstEp;
                debugPrint('📺 Resolved TV Show ${movie.title} to S1E1: ${firstEp.title}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Failed to pre-fetch TV show details: $e');
          }
        }
      } else if (movie.type == 'tv' && movie.tv == null && movie.seasons != null && movie.seasons!.isNotEmpty) {
        tvSeasons = movie.seasons!;
        final firstEp = tvSeasons.first.episodes.firstOrNull;
        if (firstEp != null) {
          mediaToPlay = firstEp;
          debugPrint('📺 Resolved TV Show ${movie.title} (offline) to S1E1: ${firstEp.title}');
        }
      }

      // Fetch seasons for TV show episode if seasons list is empty
      final showTmdbId = mediaToPlay.tv?.showTmdbId ?? mediaToPlay.tmdbId;
      if (tvSeasons.isEmpty && showTmdbId != null && (mediaToPlay.type == 'tv' || mediaToPlay.tv != null)) {
        try {
          debugPrint('📺 Pre-fetching seasons mapping for TV TMDB: $showTmdbId');
          final tvShow = await ref.read(movieRepositoryProvider).getTvShowById(showTmdbId.toString());
          tvSeasons = tvShow.seasons;
        } catch (e) {
          debugPrint('⚠️ Failed to pre-fetch TV show details: $e');
        }
      }

      // Determine resume position if present
      final String savedMovieId = (mediaToPlay.tv?.showTmdbId != null)
          ? 'show_${mediaToPlay.tv!.showTmdbId}'
          : mediaToPlay.id;
      final savedProgress = WatchHistoryManager.getProgress(savedMovieId);
      Duration? resumePosition;
      if (savedProgress != null && (savedProgress.episodeId == mediaToPlay.id || mediaToPlay.type == 'movie')) {
        if (savedProgress.position > 2 && savedProgress.position < savedProgress.duration - 5) {
          resumePosition = Duration(seconds: savedProgress.position);
          debugPrint('🎯 Found saved resume position: $resumePosition');
        }
      }

      // If playing a split multipart movie, resolve correct starting part and time offset from virtual position
      if (movie.isSplit == true && splitParts.isNotEmpty) {
        double accumulated = 0.0;
        final double savedSeconds = resumePosition?.inSeconds.toDouble() ?? 0.0;
        
        for (int i = 0; i < splitParts.length; i++) {
          final partDur = splitParts[i].duration?.toDouble() ?? 0.0;
          if (savedSeconds >= accumulated && savedSeconds < accumulated + partDur) {
            currentPartIndex = i;
            resumePosition = Duration(seconds: (savedSeconds - accumulated).round());
            break;
          }
          accumulated += partDur;
        }

        if (savedSeconds >= accumulated) {
          currentPartIndex = splitParts.length - 1;
          resumePosition = Duration(seconds: (splitParts.last.duration ?? 0.0).round());
        }

        final targetPartFileId = splitParts[currentPartIndex].fileId ?? '';
        _currentFileId = targetPartFileId;
        debugPrint('🎬 Resolved multipart start: Part ${currentPartIndex + 1}/${splitParts.length} (fileId: $_currentFileId, offset: ${resumePosition?.inSeconds}s)');
      } else {
        _currentFileId = mediaToPlay.id;
      }

      debugPrint('🎬 Starting playback for: ${mediaToPlay.title} (id: $_currentFileId)');

      final streamDataSource = ref.read(streamRemoteDataSourceProvider);

      // Parallel fetch: track probe + external subtitles
      final List<dynamic> results = await Future.wait<dynamic>([
        streamDataSource.getTrackInfo(_currentFileId!).catchError((e) {
          debugPrint('⚠️ Track probe failed: $e');
          return TrackInfo(fileId: _currentFileId!);
        }),
        streamDataSource.getExternalSubtitles(_currentFileId!).catchError((e) {
          debugPrint('⚠️ External subtitle fetch failed: $e');
          return <ExternalSubtitle>[];
        }),
      ]);

      final trackInfo = results[0] as TrackInfo;
      final externalSubs = results[1] as List<ExternalSubtitle>;

      // Sort external subtitles prioritising HI/SDH tracks to match V1 logic
      externalSubs.sort((a, b) {
        final aLabel = a.label?.toUpperCase() ?? '';
        final bLabel = b.label?.toUpperCase() ?? '';
        
        final aHI = a.rating == '🔇 HI' || 
                    aLabel.contains('HI') || 
                    aLabel.contains('HEARING IMPAIRED') || 
                    aLabel.contains('SDH');
        final bHI = b.rating == '🔇 HI' || 
                    bLabel.contains('HI') || 
                    bLabel.contains('HEARING IMPAIRED') || 
                    bLabel.contains('SDH');
        
        if (aHI && !bHI) return -1;
        if (!aHI && bHI) return 1;
        return 0;
      });

      debugPrint('🎵 Audio tracks: ${trackInfo.audioTracks.length}');
      debugPrint('📝 Embedded subtitle tracks: ${trackInfo.subtitleTracks.length}');
      debugPrint('📝 External subtitles (sorted): ${externalSubs.length}');
      debugPrint('⏱️ Duration: ${trackInfo.duration}s');

      // Match and restore settings
      int selectedAudio = 0;
      int selectedSub = -1;

      if (keepSettings) {
        // Restore delays & speed rate
        await _setPropertySafe('sub-delay', prevSubDelay.toString());
        await _setPropertySafe('audio-delay', prevAudioDelay.toString());
        await state.player.setRate(prevRate);

        // Auto select matching audio track
        if (prevAudioLang != null) {
          final idx = trackInfo.audioTracks.indexWhere((t) => t.language == prevAudioLang);
          if (idx >= 0) selectedAudio = idx;
        }

        // Auto select matching subtitle track
        if (prevSubLang != null) {
          if (wasSubExternal) {
            final idx = externalSubs.indexWhere((s) => s.language == prevSubLang);
            if (idx >= 0) {
              selectedSub = idx + 100;
            }
          } else {
            final idx = trackInfo.subtitleTracks.indexWhere((t) => t.language == prevSubLang);
            if (idx >= 0) {
              selectedSub = idx;
            }
          }
        }
      } else {
        final defaultAudioIdx = trackInfo.audioTracks.indexWhere((t) => t.isDefault);
        selectedAudio = defaultAudioIdx >= 0 ? defaultAudioIdx : 0;
        await _setPropertySafe('sub-delay', '0.0');
        await _setPropertySafe('audio-delay', '0.0');

        final embeddedSubs = trackInfo.subtitleTracks;
        if (embeddedSubs.isNotEmpty) {
          final defaultSubIdx = embeddedSubs.indexWhere((t) => t.isDefault);
          selectedSub = defaultSubIdx >= 0 ? defaultSubIdx : 0;
        } else if (externalSubs.isNotEmpty) {
          selectedSub = 100;
        } else {
          selectedSub = -1;
        }
      }

      // Determine streaming mode
      final bool useRemux = kIsWeb;

      // Build stream URL
      final String streamUrl;
      if (useRemux) {
        streamUrl = StreamRemoteDataSource.buildStreamUrl(
          _currentFileId!,
          audioTrack: selectedAudio,
          startSeconds: 0,
        );
      } else {
        streamUrl = StreamRemoteDataSource.buildStreamUrl(_currentFileId!);
      }

      debugPrint('🎬 Stream URL: $streamUrl (remux: $useRemux)');

      // Update state with track info before playback starts
      state = state.copyWith(
        movie: mediaToPlay,
        tvSeasons: tvSeasons,
        trackInfo: trackInfo,
        externalSubtitles: externalSubs,
        currentAudioTrack: selectedAudio,
        currentSubtitleTrack: selectedSub,
        subtitleDelay: keepSettings ? prevSubDelay : 0.0,
        audioDelay: keepSettings ? prevAudioDelay : 0.0,
        splitParts: splitParts,
        currentPartIndex: currentPartIndex,
        isRemuxing: useRemux,
        seekOffset: 0,
        duration: trackInfo.duration,
      );

      // Open media
      await state.player.open(
        mk.Media(streamUrl),
        play: true,
      );

      if (resumePosition != null) {
        debugPrint('🎯 Seeking player to saved resume position: $resumePosition');
        await state.player.seek(resumePosition);
      }

      state = state.copyWith(isInitialized: true, isLoading: false);
      debugPrint('🎬 Playback started successfully');

      // Set/apply the tracks after the demuxer loads
      await Future.delayed(const Duration(milliseconds: 700));

      if (selectedSub == -1) {
        debugPrint('📝 Explicitly disabling subtitles at playback start');
        await state.player.setSubtitleTrack(mk.SubtitleTrack.no());
      } else {
        debugPrint('📝 Applying default subtitle selection: $selectedSub');
        await switchSubtitleTrack(
          selectedSub >= 100 ? selectedSub - 100 : selectedSub,
          isExternal: selectedSub >= 100,
        );
      }

      if (selectedAudio > 0) {
        debugPrint('🎵 Applying default audio selection: $selectedAudio');
        await switchAudioTrack(selectedAudio);
      }

      // Start heartbeat (every 20 seconds, matching web reference)
      _startHeartbeat(_currentFileId!);
      _startPositionTracking(mediaToPlay);
    } catch (e, stackTrace) {
      debugPrint('❌ Player error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        error: 'Failed to load video: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  /// Play next episode of the TV show carrying forward options
  Future<void> playNextEpisode() async {
    final nextEp = state.nextEpisode;
    if (nextEp != null) {
      debugPrint('📺 Auto advancing to next episode: S${nextEp.tv?.seasonNumber}E${nextEp.tv?.episodeNumber}');
      await play(nextEp, keepSettings: true);
    }
  }

  /// Play previous episode of the TV show carrying forward options
  Future<void> playPreviousEpisode() async {
    final prevEp = state.previousEpisode;
    if (prevEp != null) {
      debugPrint('📺 Regressing to previous episode: S${prevEp.tv?.seasonNumber}E${prevEp.tv?.episodeNumber}');
      await play(prevEp, keepSettings: true);
    }
  }

  /// Helper to switch track/stream while strictly maintaining position and playing state
  Future<void> _withPositionPreservation(Future<void> Function() action) async {
    final wasPlaying = state.player.state.playing;
    final savedPosition = state.player.state.position;
    debugPrint('💾 Preserving position: $savedPosition (playing: $wasPlaying)');

    state = state.copyWith(isLoading: true);

    try {
      if (wasPlaying) {
        await state.player.pause();
      }
      await action();
    } catch (e) {
      debugPrint('⚠️ Error executing action: $e');
    }

    // Wait slightly for demuxer reload/handshake to complete
    await Future.delayed(const Duration(milliseconds: 350));

    try {
      await state.player.seek(savedPosition);
      // Wait another 150ms for decoder buffers to reload and align audio track!
      await Future.delayed(const Duration(milliseconds: 150));
      if (wasPlaying) {
        await state.player.play();
      }
    } catch (e) {
      debugPrint('⚠️ Error restoring position: $e');
    }

    state = state.copyWith(isLoading: false);
  }

  /// Switch audio track
  Future<void> switchAudioTrack(int trackIndex) async {
    if (_currentFileId == null) return;
    
    final tracks = state.trackInfo?.audioTracks ?? [];
    if (trackIndex < 0 || trackIndex >= tracks.length) return;
    if (trackIndex == state.currentAudioTrack) return;

    debugPrint('🎵 Switching audio track to $trackIndex');

    if (kIsWeb) {
      // Web: must rebuild stream URL with new audioTrack param
      final currentPos = state.player.state.position.inMilliseconds / 1000.0;
      final globalPos = currentPos + state.seekOffset;
      
      final streamUrl = StreamRemoteDataSource.buildStreamUrl(
        _currentFileId!,
        audioTrack: trackIndex,
        startSeconds: globalPos,
      );

      state = state.copyWith(
        currentAudioTrack: trackIndex,
        isRemuxing: true,
        seekOffset: globalPos,
      );

      await state.player.open(mk.Media(streamUrl), play: true);
    } else {
      // Android: use native track selection wrapped with position preservation!
      await _withPositionPreservation(() async {
        final nativeTracks = state.player.state.tracks.audio;
        final actualTracks = nativeTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
        if (trackIndex >= 0 && trackIndex < actualTracks.length) {
          await state.player.setAudioTrack(actualTracks[trackIndex]);
        }
      });
      state = state.copyWith(currentAudioTrack: trackIndex);
    }
  }

  /// Switch subtitle track (both embedded and external)
  Future<void> switchSubtitleTrack(int trackIndex, {bool isExternal = false}) async {
    if (_currentFileId == null) return;

    if (trackIndex == -1) {
      debugPrint('📝 Turning off subtitles');
      await _withPositionPreservation(() async {
        await state.player.setSubtitleTrack(mk.SubtitleTrack.no());
      });
      state = state.copyWith(currentSubtitleTrack: -1);
      return;
    }

    if (isExternal) {
      final extSubs = state.externalSubtitles;
      if (trackIndex < 0 || trackIndex >= extSubs.length) return;
      final sub = extSubs[trackIndex];
      final vttUrl = '${AppConfig.v1BaseUrl}/api/subtitles/file/${sub.id}';
      debugPrint('🔤 Loading external subtitle: $vttUrl');
      
      await _withPositionPreservation(() async {
        if (!kIsWeb) {
          await state.player.setSubtitleTrack(mk.SubtitleTrack.uri(vttUrl));
        }
      });
      state = state.copyWith(currentSubtitleTrack: trackIndex + 100); // 100+ offset representing external index
    } else {
      final embeddedSubs = state.trackInfo?.subtitleTracks ?? [];
      if (trackIndex < 0 || trackIndex >= embeddedSubs.length) return;
      
      await _withPositionPreservation(() async {
        if (!kIsWeb) {
          debugPrint('🔤 Loading embedded subtitle natively at index: $trackIndex');
          final nativeTracks = state.player.state.tracks.subtitle;
          final actualTracks = nativeTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
          if (trackIndex >= 0 && trackIndex < actualTracks.length) {
            await state.player.setSubtitleTrack(actualTracks[trackIndex]);
          }
        }
      });
      state = state.copyWith(currentSubtitleTrack: trackIndex);
    }
  }

  /// Set native subtitle delay in seconds (mpv sub-delay property)
  Future<void> setSubtitleDelay(double delaySeconds) async {
    await _setPropertySafe('sub-delay', delaySeconds.toString());
    state = state.copyWith(subtitleDelay: delaySeconds);
    debugPrint('🔤 Native subtitle delay offset set to: ${delaySeconds}s');
  }

  /// Set native audio delay in seconds (mpv audio-delay property)
  Future<void> setAudioDelay(double delaySeconds) async {
    await _setPropertySafe('audio-delay', delaySeconds.toString());
    state = state.copyWith(audioDelay: delaySeconds);
    debugPrint('🎵 Native audio delay offset set to: ${delaySeconds}s');
  }

  /// Safe helper to call setProperty dynamically on NativePlayer
  Future<void> _setPropertySafe(String key, String value) async {
    try {
      final platform = state.player.platform;
      if (platform != null) {
        final dynamic dynPlatform = platform;
        await dynPlatform.setProperty(key, value);
      }
    } catch (e) {
      debugPrint('⚠️ setPropertySafe failed for $key: $e');
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    if (state.isRemuxing && _currentFileId != null) {
      final targetSeconds = position.inMilliseconds / 1000.0;
      debugPrint('🔍 Remux seek to ${targetSeconds}s');

      final streamUrl = StreamRemoteDataSource.buildStreamUrl(
        _currentFileId!,
        audioTrack: state.currentAudioTrack,
        startSeconds: targetSeconds,
      );

      state = state.copyWith(seekOffset: targetSeconds);
      await state.player.open(mk.Media(streamUrl), play: true);
    } else {
      await state.player.seek(position);
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await state.player.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await state.player.play();
  }

  /// Toggle play/pause
  Future<void> playOrPause() async {
    if (state.player.state.playing) {
      await state.player.pause();
    } else {
      await state.player.play();
    }
  }

  /// Set volume (0.0 to 100.0)
  Future<void> setVolume(double volume) async {
    await state.player.setVolume(volume.clamp(0.0, 100.0));
  }

  /// Set subtitle font size (reactively updates HUD and watch screen configuration)
  void setSubtitleFontSize(double size) {
    state = state.copyWith(subtitleFontSize: size.clamp(14.0, 48.0));
    debugPrint('🔤 Subtitle font size state updated: ${size}px');
  }

  // ==================== Heartbeat ====================

  void _startHeartbeat(String fileId) {
    _stopHeartbeat();
    final streamDataSource = ref.read(streamRemoteDataSourceProvider);
    
    // Send immediately
    streamDataSource.sendHeartbeat(fileId);
    
    // Then every 20 seconds (matching web reference)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      streamDataSource.sendHeartbeat(fileId);
    });
    
    debugPrint('💓 Heartbeat started for $fileId (every 20s)');
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _startPositionTracking(Movie movie) {
    _positionSubscription?.cancel();
    int lastSavedSeconds = 0;

    _positionSubscription = state.player.stream.position.listen((pos) async {
      final currentSec = pos.inSeconds;
      if (currentSec == lastSavedSeconds) return;

      // Save every 5 seconds or whenever they seek/pause
      if (currentSec % 5 == 0) {
        lastSavedSeconds = currentSec;
        final durationSec = state.player.state.duration.inSeconds;
        if (durationSec <= 0) return;

        // Calculate combined virtual progress across all parts for split movies
        int virtualPosition = currentSec;
        int virtualDuration = durationSec;

        if (state.splitParts.isNotEmpty) {
          double accumulated = 0.0;
          for (int i = 0; i < state.currentPartIndex; i++) {
            accumulated += state.splitParts[i].duration ?? 0.0;
          }
          virtualPosition = (accumulated + currentSec).round();
          
          double totalPartsDuration = 0.0;
          for (final p in state.splitParts) {
            totalPartsDuration += p.duration ?? 0.0;
          }
          virtualDuration = totalPartsDuration.round();
        }

        final String savedMovieId = (movie.tv?.showTmdbId != null)
            ? 'show_${movie.tv!.showTmdbId}'
            : movie.id;

        await WatchHistoryManager.saveProgress(
          movieId: savedMovieId,
          episodeId: movie.id,
          title: movie.title,
          poster: movie.poster,
          backdrop: movie.backdrop,
          position: virtualPosition,
          duration: virtualDuration,
          tvShowName: movie.tv?.showTitle,
          seasonNumber: movie.tv?.seasonNumber,
          episodeNumber: movie.tv?.episodeNumber,
          episodeTitle: movie.title,
        );
        
        // Notify Riverpod continueWatchingProvider listeners
        ref.read(continueWatchingProvider.notifier).refresh();
      }
    });
  }

  /// Automatically advance and stream the next part of split movies sequentially
  Future<void> _handlePlaybackCompleted() async {
    final hasNextPart = state.splitParts.isNotEmpty && 
                         state.currentPartIndex < state.splitParts.length - 1;
                         
    if (hasNextPart) {
      final nextPartIndex = state.currentPartIndex + 1;
      final nextPart = state.splitParts[nextPartIndex];
      final targetFileId = nextPart.fileId ?? '';
      debugPrint('🎬 Multipart: Part ${state.currentPartIndex + 1} completed! Auto-advancing to Part ${nextPart.partNumber} (fileId: $targetFileId)');
      
      state = state.copyWith(
        currentPartIndex: nextPartIndex,
        isLoading: true,
      );
      
      final streamUrl = StreamRemoteDataSource.buildStreamUrl(targetFileId);
      _currentFileId = targetFileId;
      
      // Probe new track info for this part
      final streamDataSource = ref.read(streamRemoteDataSourceProvider);
      try {
        final trackInfo = await streamDataSource.getTrackInfo(targetFileId);
        state = state.copyWith(
          trackInfo: trackInfo,
          duration: trackInfo.duration,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to probe next part track info: $e');
      }

      await state.player.open(mk.Media(streamUrl), play: true);
      state = state.copyWith(isLoading: false);
      
      _startHeartbeat(targetFileId);
    } else {
      debugPrint('🎬 Playback completed (no next parts).');
    }
  }
}
