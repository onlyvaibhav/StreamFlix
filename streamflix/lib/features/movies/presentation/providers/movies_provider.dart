import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/tv_show.dart';
import 'package:streamflix/features/movies/data/models/curated_response.dart';
import 'package:streamflix/features/movies/data/repositories/movie_repository_impl.dart';

import 'package:streamflix/features/movies/data/models/watch_history.dart';

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

/// Provider for single movie detail or TV show detail adapted to Movie model
@riverpod
Future<Movie> movieDetail(Ref ref, String movieId) async {
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
      logo: tvShow.logo,
      year: tvShow.year,
      rating: tvShow.rating,
      popularity: tvShow.popularity,
      genres: tvShow.genres,
      type: 'tv',
      seasons: tvShow.seasons,
    );
  } else {
    return await repository.getMovieById(movieId);
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
  List<WatchHistoryItem> build() {
    return WatchHistoryManager.getContinueWatchingList();
  }

  void refresh() {
    state = WatchHistoryManager.getContinueWatchingList();
  }
}
