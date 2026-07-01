import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix/features/movies/presentation/providers/movies_provider.dart';

part 'genre_provider.g.dart';

/// Provider that extracts unique genres from all movies
@riverpod
Future<List<String>> allGenres(Ref ref) async {
  final movies = await ref.watch(allMoviesProvider.future);
  
  final Set<String> uniqueGenres = {};
  
  for (final movie in movies) {
    if (movie.genres != null) {
      for (final genre in movie.genres!) {
        uniqueGenres.add(genre);
      }
    }
  }
  
  final genres = uniqueGenres.toList();
  genres.sort();
  
  return genres;
}
