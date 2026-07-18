import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:streamflix/features/movies/data/repositories/movie_repository_impl.dart';
import 'package:streamflix/features/movies/data/models/curated_response.dart';

part 'api_genres_provider.g.dart';

@riverpod
Future<List<CuratedGenreItem>> apiGenres(Ref ref) async {
  final repository = ref.watch(movieRepositoryProvider);
  final curated = await repository.getCuratedContent();
  return curated.genresPage.genres
      .where((g) => g.count >= 2)
      .toList();
}
