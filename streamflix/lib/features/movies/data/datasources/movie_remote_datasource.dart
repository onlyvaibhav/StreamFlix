import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streamflix/core/network/api_endpoints.dart';
import 'package:streamflix/core/network/dio_client.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';
import 'package:streamflix/features/movies/data/models/tv_show.dart';
import 'package:streamflix/features/movies/data/models/curated_response.dart';

/// Remote data source for movie-related API calls
class MovieRemoteDataSource {
  final Dio _dio;

  MovieRemoteDataSource(this._dio);

  /// Fetch all movies from V1
  Future<List<Movie>> getAllMovies() async {
    try {
      final response = await _dio.get(ApiEndpoints.movies);
      
      if (response.data is List) {
        // Plain array response
        return (response.data as List)
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map<String, dynamic>) {
        // Wrapped response
        final movies = response.data['movies'] ?? response.data['data'] ?? [];
        return (movies as List)
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      throw Exception('Unexpected response format from V1');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch single movie details by ID
  Future<Movie> getMovieById(String movieId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.movieDetail.replaceAll(':id', movieId),
      );
      
      if (response.data is Map<String, dynamic>) {
        final movieData = response.data['movie'] ?? response.data;
        return Movie.fromJson(movieData as Map<String, dynamic>);
      }
      
      throw Exception('Unexpected response format from V1');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch movies by genre
  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.moviesByGenre.replaceAll(':id', genreId),
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      final movies = response.data['movies'] ?? response.data['data'] ?? response.data['results'] ?? [];
      return (movies as List)
          .map((json) => Movie.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch featured movies for hero banner
  Future<List<Movie>> getFeaturedMovies() async {
    try {
      // V1 does not have /api/movies/featured. We fall back directly to sorting all movies.
      final allMovies = await getAllMovies();
      // Return top 5 by popularity or rating
      allMovies.sort((a, b) {
        final aScore = (a.popularity ?? 0) + (a.rating ?? 0) * 10;
        final bScore = (b.popularity ?? 0) + (b.rating ?? 0) * 10;
        return bScore.compareTo(aScore);
      });
      return allMovies.take(5).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch movie metadata.json directly
  Future<Movie> getMovieMetadata(String movieId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.movieMetadata.replaceAll(':id', movieId),
      );
      final metaData = response.data['metadata'] ?? response.data;
      return Movie.fromJson(metaData as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch curated content (homepage layouts)
  Future<CuratedResponse> getCuratedContent() async {
    try {
      final response = await _dio.get(ApiEndpoints.curated);
      if (response.data is Map<String, dynamic>) {
        return CuratedResponse.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Unexpected response format for curated content');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch TV show details (seasons, episodes)
  Future<TvShow> getTvShowById(String showTmdbId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.tvDetail.replaceAll(':id', showTmdbId),
      );
      if (response.data is Map<String, dynamic>) {
        final sanitized = _sanitizeTvShowJson(response.data as Map<String, dynamic>);
        return TvShow.fromJson(sanitized);
      }
      throw Exception('Unexpected response format for TV show details');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetch all TV shows catalog from metadata
  Future<List<Movie>> getAllTvShows() async {
    try {
      final response = await _dio.get(ApiEndpoints.metadata);
      if (response.data is Map<String, dynamic>) {
        final List<dynamic> tvShowsJson = response.data['tvShows'] ?? [];
        return tvShowsJson.map((json) {
          final sanitized = _sanitizeTvShowJson(json as Map<String, dynamic>);
          final tvShow = TvShow.fromJson(sanitized);
          return Movie(
            id: 'show_${tvShow.showTmdbId}',
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
        }).toList();
      }
      throw Exception('Unexpected response format for TV shows catalog');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Intercept and sanitize incoming TV Show JSON to prevent schema structure crashes.
  Map<String, dynamic> _sanitizeTvShowJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    
    // 1. Sanitize seasons Map/List
    final seasonsRaw = copy['seasons'];
    List<dynamic> sanitizedSeasons = [];
    
    if (seasonsRaw is List) {
      sanitizedSeasons = seasonsRaw.map((s) {
        if (s is Map<String, dynamic>) {
          final sCopy = Map<String, dynamic>.from(s);
          sCopy['episodes'] = sCopy['episodes'] as List? ?? [];
          return sCopy;
        }
        return s;
      }).toList();
    } else if (seasonsRaw is Map) {
      final List<Map<String, dynamic>> list = [];
      seasonsRaw.forEach((key, value) {
        final seasonNumber = int.tryParse(key.toString()) ?? 0;
        if (value is List) {
          list.add({
            'seasonNumber': seasonNumber,
            'episodes': value,
          });
        }
      });
      list.sort((a, b) => (a['seasonNumber'] as int).compareTo(b['seasonNumber'] as int));
      sanitizedSeasons = list;
    } else {
      // If seasons is missing, try to build from flat episodes list
      final episodesRaw = copy['episodes'];
      if (episodesRaw is List) {
        final Map<int, List<dynamic>> grouped = {};
        for (final ep in episodesRaw) {
          if (ep is Map<String, dynamic>) {
            final sNum = ep['seasonNumber'] ?? ep['tv']?['seasonNumber'] ?? 0;
            grouped.putIfAbsent(sNum, () => []).add(ep);
          }
        }
        final List<Map<String, dynamic>> list = [];
        grouped.forEach((seasonNumber, episodes) {
          list.add({
            'seasonNumber': seasonNumber,
            'episodes': episodes,
          });
        });
        list.sort((a, b) => (a['seasonNumber'] as int).compareTo(b['seasonNumber'] as int));
        sanitizedSeasons = list;
      }
    }
    
    copy['seasons'] = sanitizedSeasons;
    
    // 2. Sanitize availableSeasons
    final availableSeasonsRaw = copy['availableSeasons'];
    if (availableSeasonsRaw is List) {
      copy['availableSeasons'] = availableSeasonsRaw.map((e) => (e as num).toInt()).toList();
    } else {
      copy['availableSeasons'] = sanitizedSeasons.map((s) => s['seasonNumber'] as int).toList();
    }
    
    // 3. Sanitize availableEpisodeCount
    final availableEpisodeCountRaw = copy['availableEpisodeCount'];
    if (availableEpisodeCountRaw is num) {
      copy['availableEpisodeCount'] = availableEpisodeCountRaw.toInt();
    } else {
      copy['availableEpisodeCount'] = sanitizedSeasons.fold<int>(0, (sum, s) => sum + (s['episodes'] as List).length);
    }
    
    return copy;
  }

  /// Relevance Search catalog
  Future<List<Movie>> searchCatalog(String query) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.search,
        queryParameters: {'q': query},
      );
      if (response.data is Map<String, dynamic> && response.data['results'] is List) {
        final results = response.data['results'] as List;
        return results
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw Exception('Unexpected response format for search catalog');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Convert DioException to user-friendly error message
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet connection.');
      
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          return Exception('Movie not found.');
        } else if (statusCode == 500) {
          return Exception('Server error. Please try again later.');
        }
        return Exception('Failed to load movies (${statusCode ?? 'unknown error'}).');
      
      case DioExceptionType.connectionError:
        return Exception('Cannot connect to server. Please check if the backend is running.');
      
      default:
        return Exception('An unexpected error occurred: ${e.message}');
    }
  }
}

/// Provider for MovieRemoteDataSource
final movieRemoteDataSourceProvider = Provider<MovieRemoteDataSource>((ref) {
  return MovieRemoteDataSource(ref.watch(dioProvider));
});
