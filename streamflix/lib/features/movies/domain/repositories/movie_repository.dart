import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/tv_show.dart';
import 'package:streamflix/features/movies/data/models/curated_response.dart';

/// Abstract repository interface for StreamFlix media items
abstract class MovieRepository {
  Future<List<Movie>> getAllMovies();
  Future<Movie> getMovieById(String movieId);
  Future<List<Movie>> getMoviesByGenre(String genreId);
  Future<List<Map<String, dynamic>>> getGenres();
  Future<List<Movie>> getFeaturedMovies();

  // Curated Content & Catalog Upgrades (Phase 3)
  Future<CuratedResponse> getCuratedContent();
  Future<TvShow> getTvShowById(String showTmdbId);
  Future<List<Movie>> getAllTvShows();
  Future<List<Movie>> searchCatalog(String query);
}
