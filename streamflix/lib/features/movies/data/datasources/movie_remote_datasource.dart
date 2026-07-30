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

  /// Fetch movies by genre using curated local data (bypasses TMDB blocks)
  Future<List<Movie>> getMoviesByGenre(String genreId) async {
    try {
      final curated = await getCuratedContent();
      final sections = curated.genresPage.sections[genreId];
      
      if (sections != null) {
        // Return popular or combine them
        final popular = sections['popular'] ?? [];
        if (popular.isNotEmpty) return popular;
        
        // Fallback to top_rated or anything else available
        return sections.values.expand((element) => element).toList();
      }
      return [];
    } catch (e) {
      if (e is DioException) throw _handleDioError(e);
      throw Exception('Failed to load genre movies: $e');
    }
  }

  /// Fetch list of genres
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      final response = await _dio.get(ApiEndpoints.genresList);
      final genres = response.data['genres'] as List? ?? [];
      return genres.cast<Map<String, dynamic>>();
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
        final sanitized = _sanitizeCuratedJson(response.data as Map<String, dynamic>);
        return CuratedResponse.fromJson(sanitized);
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
            logo: tvShow.logo ?? ApiEndpoints.movieLogoStatic('show_${tvShow.showTmdbId}'),
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
    
    // Fix missing or mismatched fields from backend for TV Shows
    if (copy['showTmdbId'] == null) {
      final fallbackId = copy['tmdbId'] ?? copy['id'] ?? 0;
      copy['showTmdbId'] = fallbackId is num ? fallbackId.toInt() : int.tryParse(fallbackId.toString()) ?? 0;
    } else if (copy['showTmdbId'] is! num) {
      copy['showTmdbId'] = int.tryParse(copy['showTmdbId'].toString()) ?? 0;
    }
    
    if (copy['showTitle'] == null) {
      copy['showTitle'] = copy['title'] ?? 'Unknown TV Show';
    }
    
    // 1. Extract ALL episodes from whatever structure the backend sent
    final seasonsRaw = copy['seasons'];
    final episodesRaw = copy['episodes'];
    final List<dynamic> allEpisodes = [];

    if (seasonsRaw is List) {
      for (final s in seasonsRaw) {
        if (s is Map<String, dynamic> && s['episodes'] is List) {
          allEpisodes.addAll(s['episodes'] as List);
        }
      }
    } else if (seasonsRaw is Map) {
      seasonsRaw.forEach((key, value) {
        if (value is List) {
          allEpisodes.addAll(value);
        }
      });
    }

    if (episodesRaw is List) {
      allEpisodes.addAll(episodesRaw);
    }

    // 2. Regroup all extracted episodes by their ACTUAL season number
    final Map<int, List<dynamic>> grouped = {};
    for (final ep in allEpisodes) {
      if (ep is Map<String, dynamic>) {
        final sNum = ep['seasonNumber'] ?? ep['tv']?['seasonNumber'] ?? 1;
        grouped.putIfAbsent(sNum, () => []).add(ep);
      }
    }

    // 3. Build sanitized seasons list and sort
    List<Map<String, dynamic>> sanitizedSeasons = [];
    grouped.forEach((seasonNumber, episodes) {
      // Sort episodes numerically within the season
      episodes.sort((a, b) {
         final aNum = a['episodeNumber'] ?? a['tv']?['episodeNumber'] ?? 0;
         final bNum = b['episodeNumber'] ?? b['tv']?['episodeNumber'] ?? 0;
         return (aNum as int).compareTo(bNum as int);
      });
      sanitizedSeasons.add({
        'seasonNumber': seasonNumber,
        'episodes': episodes,
      });
    });
    sanitizedSeasons.sort((a, b) => (a['seasonNumber'] as int).compareTo(b['seasonNumber'] as int));
    
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

  /// Deeply sanitizes the CuratedResponse JSON to ensure empty maps aren't accidentally decoded as empty lists.
  /// This fixes the "type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>' in type cast" error.
  Map<String, dynamic> _sanitizeCuratedJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);

    // Fix homepage.rows
    if (copy['homepage'] is Map) {
      final homepage = Map<String, dynamic>.from(copy['homepage']);
      if (homepage['rows'] is List && (homepage['rows'] as List).isEmpty) {
        homepage['rows'] = <String, dynamic>{};
      }
      copy['homepage'] = homepage;
    }

    // Fix genres_page.sections and nested section maps
    if (copy['genres_page'] is Map) {
      final genresPage = Map<String, dynamic>.from(copy['genres_page']);
      if (genresPage['sections'] is List && (genresPage['sections'] as List).isEmpty) {
        genresPage['sections'] = <String, dynamic>{};
      } else if (genresPage['sections'] is Map) {
        final sections = Map<String, dynamic>.from(genresPage['sections']);
        for (final key in sections.keys) {
          if (sections[key] is List && (sections[key] as List).isEmpty) {
            sections[key] = <String, dynamic>{};
          }
        }
        genresPage['sections'] = sections;
      }
      copy['genres_page'] = genresPage;
    }

    // Fix special_sections
    if (copy['special_sections'] is Map) {
      final specialSections = Map<String, dynamic>.from(copy['special_sections']);
      if (specialSections['mood'] is List && (specialSections['mood'] as List).isEmpty) {
        specialSections['mood'] = <String, dynamic>{};
      }
      if (specialSections['duration'] is List && (specialSections['duration'] as List).isEmpty) {
        specialSections['duration'] = <String, dynamic>{};
      }
      copy['special_sections'] = specialSections;
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

  /// Fetch More Like This recommendations
  Future<List<Movie>> getMoreLikeThis(String id, String type) async {
    try {
      final cleanId = id.replaceAll('show_', '');
      final endpoint = type == 'tv' 
          ? ApiEndpoints.moreLikeThisTv.replaceAll(':id', cleanId)
          : ApiEndpoints.moreLikeThisMovie.replaceAll(':id', cleanId);
          
      final response = await _dio.get(endpoint);
      
      if (response.data is Map<String, dynamic> && response.data['success'] == true) {
        final results = response.data['results'] as List? ?? [];
        return results
            .map((json) => Movie.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      // Don't throw for recommendations, just return empty list to hide the row
      return [];
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
