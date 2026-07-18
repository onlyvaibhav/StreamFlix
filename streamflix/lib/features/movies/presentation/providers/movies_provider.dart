import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/tv_show.dart';
import 'package:streamflix/features/movies/data/models/curated_response.dart';
import 'package:streamflix/features/movies/data/repositories/movie_repository_impl.dart';
import 'package:streamflix/core/network/api_endpoints.dart';

import 'package:streamflix/features/movies/data/models/watch_history.dart';
import 'package:flutter/foundation.dart';
import 'package:streamflix/features/player/data/datasources/stream_remote_datasource.dart';
import 'package:streamflix/features/downloads/data/download_manager.dart';
import 'package:streamflix/features/downloads/data/download_item.dart';
import 'package:streamflix/features/movies/data/models/split_part.dart';
import 'package:streamflix/features/movies/data/models/season_info.dart';
import 'package:streamflix/features/movies/data/models/tv_show_info.dart';
part 'movies_provider.g.dart';

/// Provider for all movies list
@riverpod
Future<List<Movie>> allMovies(Ref ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getAllMovies();
}

/// Provider for featured movies (hero banner)
@riverpod
Future<List<Movie>> featuredMovies(Ref ref) async {
  final allMovies = await ref.watch(allMoviesProvider.future);
  final List<Movie> sorted = List.from(allMovies);
  sorted.sort((a, b) {
    final aScore = (a.popularity ?? 0) + (a.rating ?? 0) * 10;
    final bScore = (b.popularity ?? 0) + (b.rating ?? 0) * 10;
    return bScore.compareTo(aScore);
  });
  return sorted.take(5).toList();
}

/// Provider for movies by genre
@riverpod
Future<List<Movie>> moviesByGenre(Ref ref, String genreId) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getMoviesByGenre(genreId);
}

@riverpod
Future<Movie> movieDetail(Ref ref, String movieId) async {
  // 1. Check if the movie/episode is downloaded for offline playback
  final downloadManager = ref.read(downloadManagerProvider);
  final downloadedItem = downloadManager.getDownload(movieId);
  if (downloadedItem != null && downloadedItem.overallStatus == DownloadStatus.completed) {
    debugPrint('🎬 Serving movie details from offline registry for: $movieId');
    
    List<SeasonInfo>? reconstructedSeasons;
    if (downloadedItem.type == 'episode' && downloadedItem.seriesId != null) {
      // Find all completed downloads for this specific TV show
      final allSeriesDownloads = downloadManager.sortedItems
          .where((item) => item.seriesId == downloadedItem.seriesId && item.overallStatus == DownloadStatus.completed)
          .toList();
          
      // Group them by season number
      final seasonMap = <int, List<Movie>>{};
      for (final item in allSeriesDownloads) {
        final sNum = item.seasonNumber ?? 1;
        seasonMap.putIfAbsent(sNum, () => []);
        seasonMap[sNum]!.add(Movie(
          id: item.mediaId,
          title: item.title,
          poster: item.posterUrl,
          backdrop: item.backdropUrl,
          type: item.type,
          seasonNumber: item.seasonNumber,
          episodeNumber: item.episodeNumber,
          isSplit: item.parts.length > 1,
          totalParts: item.parts.length,
          parts: item.parts.map((p) => SplitPart(fileId: p.fileId, size: p.sizeBytes)).toList(),
        ));
      }
      
      // Convert to SeasonInfo list and sort
      reconstructedSeasons = seasonMap.entries.map((e) {
        final eps = e.value;
        // Sort episodes numerically within the season
        eps.sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
        return SeasonInfo(seasonNumber: e.key, episodes: eps);
      }).toList();
      
      // Sort seasons numerically
      reconstructedSeasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    }

    return Movie(
      id: downloadedItem.mediaId,
      title: downloadedItem.title,
      poster: downloadedItem.posterUrl,
      backdrop: downloadedItem.backdropUrl,
      type: downloadedItem.type,
      seasonNumber: downloadedItem.seasonNumber,
      episodeNumber: downloadedItem.episodeNumber,
      isSplit: downloadedItem.parts.length > 1,
      totalParts: downloadedItem.parts.length,
      seasons: reconstructedSeasons,
      tv: downloadedItem.type == 'episode' && downloadedItem.seriesId != null
          ? TvShowInfo(
              showTmdbId: int.tryParse(downloadedItem.seriesId!) ?? 0,
              showTitle: downloadedItem.showTitle ?? 'Unknown Series',
              seasonNumber: downloadedItem.seasonNumber ?? 1,
              episodeNumber: downloadedItem.episodeNumber ?? 1,
              episodeTitle: downloadedItem.title,
            )
          : null,
      parts: downloadedItem.parts.map((p) => SplitPart(
        fileId: p.fileId,
        size: p.sizeBytes,
      )).toList(),
    );
  }

  // 2. Fallback to network
  final repository = ref.watch(movieRepositoryProvider);
  if (movieId.startsWith('show_')) {
    final showTmdbId = movieId.replaceAll('show_', '');
    final tvShow = await repository.getTvShowById(showTmdbId);

    return Movie(
      id: movieId,
      title: tvShow.showTitle,
      overview: tvShow.overview,
      poster: tvShow.poster,
      backdrop: tvShow.backdrop,
      logo: tvShow.logo ?? ApiEndpoints.movieLogoStatic('show_$showTmdbId'),
      year: tvShow.year,
      rating: tvShow.rating,
      popularity: tvShow.popularity,
      genres: tvShow.genres,
      type: 'tv',
      seasons: tvShow.seasons,
    );
  } else {
    final movie = await repository.getMovieById(movieId);
    
    // If the fetched item is a TV episode, seamlessly upgrade to the full TV show
    if (movie.tv != null) {
      final showTmdbId = movie.tv!.showTmdbId;
      final tvShow = await repository.getTvShowById(showTmdbId.toString());

      return Movie(
        id: 'show_$showTmdbId',
        title: tvShow.showTitle,
        overview: tvShow.overview,
        poster: tvShow.poster,
        backdrop: tvShow.backdrop,
        logo: tvShow.logo ?? ApiEndpoints.movieLogoStatic('show_$showTmdbId'),
        year: tvShow.year,
        rating: tvShow.rating,
        popularity: tvShow.popularity,
        genres: tvShow.genres,
        type: 'tv',
        seasons: tvShow.seasons,
      );
    }
    
    return movie;
  }
}

/// Provider for grouped movies by genre
@riverpod
Future<Map<String, List<Movie>>> moviesGroupedByGenre(Ref ref) async {
  final allMovies = await ref.watch(allMoviesProvider.future);
  
  final Map<String, List<Movie>> grouped = {};
  
  for (final movie in allMovies) {
    if (movie.genres == null || movie.genres!.isEmpty) continue;
    
    for (final genre in movie.genres!) {
      grouped.putIfAbsent(genre, () => []).add(movie);
    }
  }

  for (final genreMovies in grouped.values) {
    genreMovies.sort((a, b) {
      final aScore = (a.popularity ?? 0) + (a.rating ?? 0) * 10;
      final bScore = (b.popularity ?? 0) + (b.rating ?? 0) * 10;
      return bScore.compareTo(aScore);
    });
  }
  
  return grouped;
}

/// Provider for curated content (homepage sections)
@riverpod
Future<CuratedResponse> curatedContent(Ref ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getCuratedContent();
}

/// Provider for TV show details
@riverpod
Future<TvShow> tvShowDetail(Ref ref, String showTmdbId) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getTvShowById(showTmdbId);
}

/// Provider for relevance catalog searching
@riverpod
Future<List<Movie>> searchCatalog(Ref ref, String query) async {
  if (query.trim().length < 2) return [];
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.searchCatalog(query);
}

/// Provider for list of all TV shows grouped from metadata index
@riverpod
Future<List<Movie>> allTvShows(Ref ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  return await repository.getAllTvShows();
}

/// Provider for managing and retrieving watch progress history
@riverpod
class ContinueWatching extends _$ContinueWatching {
  @override
  FutureOr<List<WatchHistoryItem>> build() async {
    try {
      final backendProgress = await ref.watch(streamRemoteDataSourceProvider).getWatchProgress();
      for (final p in backendProgress) {
        final isTv = p['media_type'] == 'tv';
        final String savedMovieId = isTv ? 'show_${p['show_id']}' : p['file_id'].toString();
        
        String? showName;
        String? epTitle;
        if (isTv) {
          final titleStr = p['title']?.toString() ?? 'Continue Watching';
          // Try to extract show name from "Show Name S01E02" format
          final match = RegExp(r'^(.*?)\s*S\d+E\d+.*$').firstMatch(titleStr);
          if (match != null) {
            showName = match.group(1)?.trim();
            epTitle = titleStr;
          } else {
            showName = titleStr;
            epTitle = titleStr;
          }
        }
        
        await WatchHistoryManager.saveProgress(
          movieId: savedMovieId,
          episodeId: p['file_id']?.toString(),
          title: p['title'] ?? 'Continue Watching',
          poster: p['poster_path'],
          position: p['position_seconds'] ?? 0,
          duration: p['duration_seconds'] ?? 0,
          seasonNumber: p['season'],
          episodeNumber: p['episode'],
          tvShowName: showName,
          episodeTitle: epTitle,
          updatedAt: p['updated_at'] != null ? DateTime.tryParse(p['updated_at']) : null,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to sync continue watching from backend: $e');
    }
    return WatchHistoryManager.getContinueWatchingList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final backendProgress = await ref.read(streamRemoteDataSourceProvider).getWatchProgress();
      for (final p in backendProgress) {
        final isTv = p['media_type'] == 'tv';
        final String savedMovieId = isTv ? 'show_${p['show_id']}' : p['file_id'].toString();
        
        String? showName;
        String? epTitle;
        if (isTv) {
          final titleStr = p['title']?.toString() ?? 'Continue Watching';
          // Try to extract show name from "Show Name S01E02" format
          final match = RegExp(r'^(.*?)\s*S\d+E\d+.*$').firstMatch(titleStr);
          if (match != null) {
            showName = match.group(1)?.trim();
            epTitle = titleStr;
          } else {
            showName = titleStr;
            epTitle = titleStr;
          }
        }
        
        await WatchHistoryManager.saveProgress(
          movieId: savedMovieId,
          episodeId: p['file_id']?.toString(),
          title: p['title'] ?? 'Continue Watching',
          poster: p['poster_path'],
          position: p['position_seconds'] ?? 0,
          duration: p['duration_seconds'] ?? 0,
          seasonNumber: p['season'],
          episodeNumber: p['episode'],
          tvShowName: showName,
          episodeTitle: epTitle,
          updatedAt: p['updated_at'] != null ? DateTime.tryParse(p['updated_at']) : null,
        );
      }
      return WatchHistoryManager.getContinueWatchingList();
    });
  }
}
