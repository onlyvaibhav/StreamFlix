import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/features/movies/data/datasources/movie_remote_datasource.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/tv_show.dart';
import 'package:streamflix/features/movies/data/models/curated_response.dart';
import 'package:streamflix/features/movies/domain/repositories/movie_repository.dart';

/// Concrete implementation of MovieRepository
class MovieRepositoryImpl implements MovieRepository {
  final MovieRemoteDataSource _remoteDataSource;

  MovieRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Movie>> getAllMovies() async {
    return await _remoteDataSource.getAllMovies();
  }

  @override
  Future<Movie> getMovieById(String movieId) async {
    return await _remoteDataSource.getMovieById(movieId);
  }

  @override
  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    return await _remoteDataSource.getMoviesByGenre(genreId);
  }

  @override
  Future<List<Movie>> getFeaturedMovies() async {
    return await _remoteDataSource.getFeaturedMovies();
  }

  @override
  Future<CuratedResponse> getCuratedContent() async {
    return await _remoteDataSource.getCuratedContent();
  }

  @override
  Future<TvShow> getTvShowById(String showTmdbId) async {
    return await _remoteDataSource.getTvShowById(showTmdbId);
  }

  @override
  Future<List<Movie>> getAllTvShows() async {
    return await _remoteDataSource.getAllTvShows();
  }

  @override
  Future<List<Movie>> searchCatalog(String query) async {
    return await _remoteDataSource.searchCatalog(query);
  }
}

/// Provider for MovieRepository
final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  return MovieRepositoryImpl(
    ref.watch(movieRemoteDataSourceProvider),
  );
});
