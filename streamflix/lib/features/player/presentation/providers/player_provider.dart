import 'dart:async';
import 'dart:io';
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
import 'package:streamflix/core/network/telegram_client_service.dart';
import 'package:streamflix/core/network/local_loopback_server.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';

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
        if (Platform.isAndroid) {
          // Phase 3 Fix: Disable hardware decoding (hwdec=no) entirely on Android 
          // to bypass Mediatek c2.mtk.avc.decoder and gralloc4 format (0x38) allocation crashes.
          // Software decoding (ffmpeg) is fast enough on modern Android CPUs.
          dynPlatform.setProperty('hwdec', 'no');
        } else {
          dynPlatform.setProperty('hwdec', 'auto-safe');
        }
        dynPlatform.setProperty('volume-max', '200');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to apply native hardware properties: $e');
    }

    final videoController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        // Phase 3 Fix: Disable hardware surface rendering on Android to prevent 
        // gralloc4 (0x38) crashes on Mediatek devices.
        enableHardwareAcceleration: !Platform.isAndroid,
      ),
    );

    // Listen to player error stream
    _errorSubscription = player.stream.error.listen((error) {
      final errStr = error.toString();
      final errStrLower = errStr.toLowerCase();
      debugPrint('❌ MediaKit Player error: $errStr');
      
      // Ignore non-fatal play promise interruptions on Web/Chrome
      if (errStrLower.contains('play() request was interrupted') || 
          errStrLower.contains('media was removed from the document') ||
          errStrLower.contains('the play() request was interrupted')) {
        debugPrint('ℹ️ Ignoring benign play promise interruption.');
        return;
      }
      
      if (errStrLower.contains('could not open codec') || 
          errStrLower.contains('decoder') ||
          errStrLower.contains('failed to initialize hardware') ||
          errStrLower.contains('failed to open http')) {
        debugPrint('⚠️ Codec/Stream error detected. Switching to software decoder.');
        try {
          final platform = player.platform;
          if (platform != null) {
            final dynamic dynPlatform = platform;
            dynPlatform.setProperty('hwdec', 'no');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to apply hwdec=no: $e');
        }

        // Restart current media without recreating VideoController
        if (state.movie != null) {
          Future.microtask(() => play(state.movie!, keepSettings: true));
        }
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
      
      // Refresh home screen continue watching row after exiting player
      Future.microtask(() {
        ref.read(continueWatchingProvider.notifier).refresh();
      });
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
  Future<void> play(Movie movie, {bool keepSettings = false, int? explicitStartTime}) async {
    // If playing the exact same media (e.g. from fullscreen toggle), ignore
    if (state.isInitialized && _currentFileId == movie.id && explicitStartTime == null) {
      if (!state.player.state.playing) {
        state.player.play();
      }
      return;
    }
    
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

      // 1. Check if the movie has multiple parts (Seamless Playback Engine)
      try {
        final partInfo = await ref.read(streamRemoteDataSourceProvider).getPartInfo(movie.id);
        if (partInfo['parts'] != null && (partInfo['parts'] as List).length > 1) {
          final partsList = (partInfo['parts'] as List)
              .map((p) => SplitPart.fromJson(p as Map<String, dynamic>))
              .toList();
          mediaToPlay = mediaToPlay.copyWith(
            isSplit: true,
            totalParts: partsList.length,
            parts: partsList,
          );
          debugPrint('🎬 Resolved multipart media: ${partsList.length} parts found for ${movie.id}');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to pre-fetch part-info: $e');
      }

      List<SeasonInfo> tvSeasons = keepSettings ? state.tvSeasons : (movie.seasons ?? []);
      List<SplitPart> splitParts = mediaToPlay.parts ?? [];
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
      if (tvSeasons.isEmpty && (mediaToPlay.type == 'tv' || mediaToPlay.type == 'episode' || mediaToPlay.tv != null)) {
        if (showTmdbId != null) {
          try {
            debugPrint('📺 Pre-fetching seasons mapping for TV TMDB: $showTmdbId');
            final tvShow = await ref.read(movieRepositoryProvider).getTvShowById(showTmdbId.toString());
            tvSeasons = tvShow.seasons;
          } catch (e) {
            debugPrint('⚠️ Failed to pre-fetch TV show details: $e');
          }
        }
        
        if (tvSeasons.isEmpty) {
          // Offline fallback: construct from downloaded episodes
          final allDownloads = DownloadManager().items;
          final showDownloads = allDownloads.where((d) => 
            (showTmdbId != null && d.seriesId == showTmdbId.toString()) || 
            (d.type == 'episode' && (d.showTitle == mediaToPlay.tv?.showTitle || d.showTitle == mediaToPlay.title))
          ).toList();
          
          if (showDownloads.isNotEmpty) {
             final Map<int, List<Movie>> seasonMap = {};
             for (final d in showDownloads) {
                final sNum = d.seasonNumber ?? 1;
                final ep = Movie(
                   id: d.mediaId,
                   title: d.title,
                   type: 'episode',
                   seasonNumber: sNum,
                   episodeNumber: d.episodeNumber ?? 1,
                   poster: d.posterUrl,
                );
                seasonMap.putIfAbsent(sNum, () => []).add(ep);
             }
             tvSeasons = seasonMap.entries.map((e) {
                e.value.sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
                return SeasonInfo(seasonNumber: e.key, episodes: e.value);
             }).toList();
             tvSeasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
             debugPrint('📺 Constructed offline TV seasons from DownloadManager');
          }
        }
      }

      // Determine resume position if present
      Duration? resumePosition;
      
      if (explicitStartTime != null && explicitStartTime > 0) {
        resumePosition = Duration(seconds: explicitStartTime);
        debugPrint('🎯 Using explicit start time: $resumePosition');
      } else {
        final String savedMovieId = (mediaToPlay.tv?.showTmdbId != null)
            ? 'show_${mediaToPlay.tv!.showTmdbId}'
            : mediaToPlay.id;
        final savedProgress = WatchHistoryManager.getProgress(savedMovieId);
        if (savedProgress != null && (savedProgress.episodeId == mediaToPlay.id || mediaToPlay.type == 'movie')) {
          if (savedProgress.position > 2 && savedProgress.position < savedProgress.duration - 5) {
            resumePosition = Duration(seconds: savedProgress.position);
            debugPrint('🎯 Found saved resume position: $resumePosition');
          }
        }
      }

      // If playing a split multipart movie, resolve correct starting part and time offset from virtual position
      if (mediaToPlay.isSplit == true && splitParts.isNotEmpty) {
        // Calculate cumulative durations to map global resume position to specific part
        double accumulated = 0.0;
        int resolvedPartIndex = 0;
        double localResumeSeconds = resumePosition?.inSeconds.toDouble() ?? 0.0;

        bool foundPart = false;
        for (int i = 0; i < splitParts.length; i++) {
          final partDur = splitParts[i].duration?.toDouble() ?? 0.0;
          if (localResumeSeconds < accumulated + partDur) {
            resolvedPartIndex = i;
            localResumeSeconds = localResumeSeconds - accumulated;
            foundPart = true;
            break;
          }
          accumulated += partDur;
        }

        // If seek was beyond the end, clamp to last part
        if (!foundPart) {
          currentPartIndex = splitParts.length - 1;
          resumePosition = Duration(seconds: (splitParts.last.duration ?? 0.0).round());
        } else {
          currentPartIndex = resolvedPartIndex;
          resumePosition = Duration(seconds: localResumeSeconds.round());
        }

        final targetPartFileId = splitParts[currentPartIndex].fileId ?? '';
        _currentFileId = targetPartFileId;
        debugPrint('🎬 Resolved multipart start: Part ${currentPartIndex + 1}/${splitParts.length} (fileId: $_currentFileId, offset: ${resumePosition?.inSeconds}s)');
      } else {
        _currentFileId = mediaToPlay.id;
      }

      debugPrint('🎬 Starting playback for: ${mediaToPlay.title} (id: $_currentFileId)');

      final streamDataSource = ref.read(streamRemoteDataSourceProvider);

      final downloadItem = DownloadManager().getDownload(mediaToPlay.id);
      final isOfflineItem = downloadItem != null && downloadItem.overallStatus == DownloadStatus.completed;

      TrackInfo trackInfo;
      List<ExternalSubtitle> externalSubs;

      if (isOfflineItem && (downloadItem.mediaInfo != null || downloadItem.externalSubtitles != null)) {
        debugPrint('📦 Using cached offline metadata and subtitles');
        trackInfo = downloadItem.mediaInfo != null 
            ? TrackInfo.fromJson(downloadItem.mediaInfo!) 
            : TrackInfo(fileId: _currentFileId!);
            
        externalSubs = (downloadItem.externalSubtitles ?? []).map((s) {
           return ExternalSubtitle.fromJson(s);
        }).toList();
      } else {
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

        trackInfo = results[0] as TrackInfo;
        externalSubs = results[1] as List<ExternalSubtitle>;
      }

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
      String streamUrl = '';
      bool useClientStreaming = false;
      bool isOffline = false;

      if (downloadItem != null && downloadItem.overallStatus == DownloadStatus.completed) {
        if (splitParts.isNotEmpty) {
           final localPart = downloadItem.parts.firstWhere(
             (p) => p.fileId == splitParts[currentPartIndex].fileId, 
             orElse: () => downloadItem.parts[currentPartIndex]
           );
           streamUrl = 'file://${localPart.filePath}';
        } else {
           streamUrl = 'file://${downloadItem.parts.first.filePath}';
        }
        isOffline = true;
        debugPrint('🎬 Offline playback: using local file -> $streamUrl');
      }

      if (!isOffline) {
        try {
          final telegramService = TelegramClientService();
          // With the auth guard in place, if we have a session, use client-side streaming
          if (telegramService.sessionString != null && telegramService.sessionString!.isNotEmpty) {
          final dataSource = ref.read(streamRemoteDataSourceProvider);
          if (splitParts.isNotEmpty) {
             for (final part in splitParts) {
                if (part.fileId == null) continue;
                final fileInfo = await dataSource.getFileInfo(part.fileId!);
                if (fileInfo != null && fileInfo.fileLocation != null) {
                  LocalLoopbackServer().registerFile(
                    fileId: part.fileId!,
                    documentId: fileInfo.fileLocation!.id,
                    accessHash: fileInfo.fileLocation!.accessHash,
                    fileReference: fileInfo.fileLocation!.fileReference,
                    size: fileInfo.fileSize,
                    channelId: fileInfo.channelId,
                  );
                }
             }
             streamUrl = 'http://127.0.0.1:${LocalLoopbackServer().port}/stream/$_currentFileId';
             useClientStreaming = true;
          } else {
             final fileInfo = await dataSource.getFileInfo(_currentFileId!);
             if (fileInfo != null && fileInfo.fileLocation != null) {
                LocalLoopbackServer().registerFile(
                  fileId: _currentFileId!,
                  documentId: fileInfo.fileLocation!.id,
                  accessHash: fileInfo.fileLocation!.accessHash,
                  fileReference: fileInfo.fileLocation!.fileReference,
                  size: fileInfo.fileSize,
                  channelId: fileInfo.channelId,
                );
                streamUrl = 'http://127.0.0.1:${LocalLoopbackServer().port}/stream/$_currentFileId';
                useClientStreaming = true;
             }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Client-Side streaming setup failed, falling back to server: $e');
      }

        if (!useClientStreaming) {
          if (useRemux) {
            streamUrl = StreamRemoteDataSource.buildStreamUrl(
              _currentFileId!,
              audioTrack: selectedAudio,
              startSeconds: 0,
            );
          } else {
            streamUrl = StreamRemoteDataSource.buildStreamUrl(_currentFileId!);
          }
        }
      }

      debugPrint('🎬 Stream URL: $streamUrl (client-side: $useClientStreaming, remux: $useRemux)');

      double totalDuration = trackInfo.duration;
      if (splitParts.isNotEmpty) {
        totalDuration = splitParts.fold(0.0, (sum, p) => sum + (p.duration ?? 0.0));
      }

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
        duration: totalDuration,
      );

      // Open media initially paused to ensure clean seeking
      await state.player.open(
        mk.Media(streamUrl),
        play: false,
      );

      if (resumePosition != null) {
        debugPrint('🎯 Seeking player to saved resume position: $resumePosition');
        
        // media_kit on Android often drops the initial seek if the demuxer hasn't fully loaded the HTTP stream.
        // Waiting for a non-zero duration ensures libmpv is ready to receive seek commands.
        if (state.player.state.duration == Duration.zero) {
          try {
            debugPrint('⏳ Waiting for media demuxer to load before seeking...');
            await state.player.stream.duration
                .firstWhere((d) => d > Duration.zero)
                .timeout(const Duration(seconds: 5));
          } catch (_) {
            debugPrint('⚠️ Timeout waiting for duration. Attempting seek anyway.');
          }
        }
        
        await state.player.seek(resumePosition);
      }

      await state.player.play();
      
      // If we are offline (track probe failed), fallback to native track probing
      if (trackInfo.audioTracks.isEmpty && trackInfo.subtitleTracks.isEmpty) {
         // media_kit on Android often drops the initial seek if the demuxer hasn't fully loaded the HTTP stream.
         // Waiting for a non-zero duration ensures libmpv is ready to receive seek commands.
         if (state.player.state.duration == Duration.zero) {
           try {
             debugPrint('⏳ Waiting for media demuxer to load before offline track probe...');
             await state.player.stream.duration
                 .firstWhere((d) => d > Duration.zero)
                 .timeout(const Duration(seconds: 5));
           } catch (_) { }
         }
         
         final nativeAudio = state.player.state.tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
         final nativeSubs = state.player.state.tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();
         
         final fallbackAudio = nativeAudio.asMap().entries.map((e) => AudioTrack(
            index: e.key,
            streamIndex: e.key,
            language: e.value.language ?? 'Unknown',
            languageCode: e.value.language ?? 'und',
            title: e.value.title ?? '',
            channels: int.tryParse(e.value.channels?.toString() ?? '') ?? 0,
         )).toList();
         
         final fallbackSubs = nativeSubs.asMap().entries.map((e) => SubtitleTrack(
            index: e.key,
            streamIndex: e.key,
            language: e.value.language ?? 'Unknown',
            languageCode: e.value.language ?? 'und',
            title: e.value.title ?? '',
         )).toList();
         
         trackInfo = trackInfo.copyWith(
            audioTracks: fallbackAudio,
            subtitleTracks: fallbackSubs,
         );
         
         if (!keepSettings) {
             selectedAudio = fallbackAudio.isNotEmpty ? 0 : selectedAudio;
             if (fallbackSubs.isNotEmpty) {
                 selectedSub = 0;
             } else if (externalSubs.isNotEmpty) {
                 selectedSub = 100;
             } else {
                 selectedSub = -1;
             }
         }
         
         // Update state with newly discovered fallback tracks
         state = state.copyWith(
            trackInfo: trackInfo,
            currentAudioTrack: selectedAudio,
            currentSubtitleTrack: selectedSub,
         );
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
          preservePosition: false,
        );
      }

      if (selectedAudio > 0) {
        debugPrint('🎵 Applying default audio selection: $selectedAudio');
        await switchAudioTrack(selectedAudio, preservePosition: false);
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
  Future<void> switchAudioTrack(int trackIndex, {bool preservePosition = false}) async {
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
      // Android: use native track selection
      final action = () async {
        final nativeTracks = state.player.state.tracks.audio;
        final actualTracks = nativeTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
        if (trackIndex >= 0 && trackIndex < actualTracks.length) {
          await state.player.setAudioTrack(actualTracks[trackIndex]);
        }
      };

      if (preservePosition) {
        await _withPositionPreservation(action);
      } else {
        await action();
      }
      state = state.copyWith(currentAudioTrack: trackIndex);
    }
  }

  /// Switch subtitle track (both embedded and external)
  Future<void> switchSubtitleTrack(int trackIndex, {bool isExternal = false, bool preservePosition = false}) async {
    if (_currentFileId == null) return;

    if (trackIndex == -1) {
      debugPrint('📝 Turning off subtitles');
      if (preservePosition) {
        await _withPositionPreservation(() async {
          await state.player.setSubtitleTrack(mk.SubtitleTrack.no());
        });
      } else {
        await state.player.setSubtitleTrack(mk.SubtitleTrack.no());
      }
      state = state.copyWith(currentSubtitleTrack: -1);
      return;
    }

    if (isExternal) {
      final extSubs = state.externalSubtitles;
      if (trackIndex < 0 || trackIndex >= extSubs.length) return;
      final sub = extSubs[trackIndex];
      String vttUrl = '';
      
      bool isOffline = false;
      final downloadItem = DownloadManager().getDownload(state.movie?.id ?? '');
      if (downloadItem != null && downloadItem.overallStatus == DownloadStatus.completed) {
        isOffline = true;
      }

      if (sub.localPath != null && isOffline) {
        vttUrl = 'file://${sub.localPath}';
        debugPrint('Subtitle: Loading local offline subtitle: $vttUrl');
      } else {
        vttUrl = '${AppConfig.v1BaseUrl}/api/subtitles/file/${sub.id}';
        debugPrint('Subtitle: Loading external subtitle: $vttUrl');
      }
      
      final action = () async {
        if (!kIsWeb) {
          await state.player.setSubtitleTrack(mk.SubtitleTrack.uri(vttUrl));
        }
      };
      
      if (preservePosition) {
        await _withPositionPreservation(action);
      } else {
        await action();
      }
      state = state.copyWith(currentSubtitleTrack: trackIndex + 100); // 100+ offset representing external index
    } else {
      final embeddedSubs = state.trackInfo?.subtitleTracks ?? [];
      if (trackIndex < 0 || trackIndex >= embeddedSubs.length) return;
      
      final action = () async {
        if (!kIsWeb) {
          final nativeTracks = state.player.state.tracks.subtitle;
          final actualTracks = nativeTracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
          if (trackIndex >= 0 && trackIndex < actualTracks.length) {
            debugPrint('🔤 Loading embedded subtitle natively at index: $trackIndex');
            await state.player.setSubtitleTrack(actualTracks[trackIndex]);
          }
        }
      };

      if (preservePosition) {
        await _withPositionPreservation(action);
      } else {
        await action();
      }
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
    final bool hasValidDurations = state.splitParts.isNotEmpty && 
        state.splitParts.fold(0.0, (sum, p) => sum + (p.duration ?? 0.0)) > 0.0;

    if (hasValidDurations) {
      double globalSeekSeconds = position.inSeconds.toDouble();
      
      // Determine which part the target seek position belongs to
      double accumulated = 0.0;
      int targetPartIndex = 0;
      double localSeekSeconds = globalSeekSeconds;
      
      bool foundPart = false;
      for (int i = 0; i < state.splitParts.length; i++) {
        final partDur = state.splitParts[i].duration ?? 0.0;
        if (globalSeekSeconds < accumulated + partDur) {
          targetPartIndex = i;
          localSeekSeconds = globalSeekSeconds - accumulated;
          foundPart = true;
          break;
        }
        accumulated += partDur;
      }
      
      if (!foundPart) {
         targetPartIndex = state.splitParts.length - 1;
         localSeekSeconds = state.splitParts.last.duration ?? 0.0;
      }

      if (targetPartIndex != state.currentPartIndex) {
        // Cross-part seek detected! Change current file ID and re-open media
        final targetFileId = state.splitParts[targetPartIndex].fileId ?? '';
        debugPrint('🎬 Cross-part seek: switching to part ${targetPartIndex + 1} (offset ${localSeekSeconds}s)');
        
        state = state.copyWith(
          currentPartIndex: targetPartIndex,
          isLoading: true,
        );
        _currentFileId = targetFileId;
        
        String streamUrl = '';
        bool isOffline = false;
        final downloadItem = DownloadManager().getDownload(state.movie?.id ?? '');
        if (downloadItem != null && downloadItem.overallStatus == DownloadStatus.completed) {
           final localPart = downloadItem.parts.firstWhere(
             (p) => p.fileId == targetFileId,
             orElse: () => downloadItem.parts[targetPartIndex]
           );
           streamUrl = 'file://${localPart.filePath}';
           isOffline = true;
        }

        if (!isOffline) {
          if (LocalLoopbackServer().port > 0 && TelegramClientService().sessionString?.isNotEmpty == true) {
            streamUrl = 'http://127.0.0.1:${LocalLoopbackServer().port}/stream/$_currentFileId';
          } else {
            streamUrl = StreamRemoteDataSource.buildStreamUrl(targetFileId);
          }
        }
        
        // Load track info for the new part
        try {
          final trackInfo = await ref.read(streamRemoteDataSourceProvider).getTrackInfo(targetFileId);
          state = state.copyWith(trackInfo: trackInfo, duration: trackInfo.duration);
        } catch (_) {}

        await state.player.open(mk.Media(streamUrl), play: false);
        
        // Wait for demuxer to load before seeking
        if (state.player.state.duration == Duration.zero) {
          try {
            debugPrint('⏳ Waiting for media demuxer to load before cross-part seeking...');
            await state.player.stream.duration
                .firstWhere((d) => d > Duration.zero)
                .timeout(const Duration(seconds: 5));
          } catch (_) {
            debugPrint('⚠️ Timeout waiting for duration. Attempting seek anyway.');
          }
        }
        
        await state.player.seek(Duration(seconds: localSeekSeconds.round()));
        await state.player.play();
        
        _startHeartbeat(targetFileId);
        state = state.copyWith(isLoading: false);
        return;
      } else {
        // In same part
        await state.player.seek(Duration(seconds: localSeekSeconds.round()));
        return;
      }
    }

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
    
    if (state.movie != null) {
      await _saveCurrentProgress(state.movie!, position.inSeconds);
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await state.player.pause();
    _stopHeartbeat();
    if (state.movie != null) {
      final currentSec = state.player.state.position.inSeconds;
      await _saveCurrentProgress(state.movie!, currentSec);
    }
  }

  /// Resume playback
  Future<void> resume() async {
    await state.player.play();
    if (_currentFileId != null) {
      _startHeartbeat(_currentFileId!);
    }
  }

  /// Toggle play/pause
  Future<void> playOrPause() async {
    if (state.player.state.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  /// Set volume (0.0 to 200.0)
  Future<void> setVolume(double volume) async {
    await state.player.setVolume(volume.clamp(0.0, 200.0));
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

  Future<void> _saveCurrentProgress(Movie movie, int currentSec) async {
    final durationSec = state.player.state.duration.inSeconds > 0
        ? state.player.state.duration.inSeconds
        : state.duration.round();
    if (durationSec <= 0) return;

    // Calculate combined virtual progress across all parts for split movies
    int virtualPosition = currentSec;
    int virtualDuration = durationSec;

    final bool hasValidDurations = state.splitParts.isNotEmpty && 
        state.splitParts.fold(0.0, (sum, p) => sum + (p.duration ?? 0.0)) > 0.0;

    if (hasValidDurations) {
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

    // Tell the home screen to refresh the Continue Watching row
    ref.invalidate(continueWatchingProvider);

    try {
      final isTvShow = movie.type == 'tv' || movie.tv != null;
      await ref.read(streamRemoteDataSourceProvider).saveWatchProgress(
        fileId: movie.id,
        positionSeconds: virtualPosition,
        durationSeconds: virtualDuration,
        title: movie.title,
        posterPath: movie.poster,
        mediaType: isTvShow ? 'tv' : 'movie',
        season: movie.tv?.seasonNumber,
        episode: movie.tv?.episodeNumber,
        showId: isTvShow ? movie.tv?.showTmdbId?.toString() : null,
      );
    } catch (e) {
      debugPrint('⚠️ Remote save progress failed: $e');
    }
  }

  void _startPositionTracking(Movie movie) {
    _positionSubscription?.cancel();
    int lastSavedSeconds = 0;

    _positionSubscription = state.player.stream.position.listen((pos) async {
      final currentSec = pos.inSeconds;
      if (currentSec == lastSavedSeconds) return;

      // Save every 15 seconds
      if (currentSec % 15 == 0) {
        lastSavedSeconds = currentSec;
        await _saveCurrentProgress(movie, currentSec);
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
      
      String streamUrl = '';
      bool isOffline = false;
      final downloadItem = DownloadManager().getDownload(state.movie?.id ?? '');
      if (downloadItem != null && downloadItem.overallStatus == DownloadStatus.completed) {
         final localPart = downloadItem.parts.firstWhere(
           (p) => p.fileId == targetFileId,
           orElse: () => downloadItem.parts[nextPartIndex]
         );
         streamUrl = 'file://${localPart.filePath}';
         isOffline = true;
      }

      if (!isOffline) {
        if (LocalLoopbackServer().port > 0 && TelegramClientService().sessionString?.isNotEmpty == true) {
          streamUrl = 'http://127.0.0.1:${LocalLoopbackServer().port}/stream/$targetFileId';
        } else {
          streamUrl = StreamRemoteDataSource.buildStreamUrl(targetFileId);
        }
      }
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
