import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';

part 'curated_response.freezed.dart';
part 'curated_response.g.dart';

@freezed
sealed class CuratedGenreItem with _$CuratedGenreItem {
  const factory CuratedGenreItem({
    required String name,
    required String slug,
    String? image,
    required int count,
  }) = _CuratedGenreItem;

  factory CuratedGenreItem.fromJson(Map<String, dynamic> json) =>
      _$CuratedGenreItemFromJson(json);
}

@freezed
sealed class CuratedGenresPage with _$CuratedGenresPage {
  const factory CuratedGenresPage({
    required List<CuratedGenreItem> genres,
    required Map<String, Map<String, List<Movie>>> sections,
  }) = _CuratedGenresPage;

  factory CuratedGenresPage.fromJson(Map<String, dynamic> json) =>
      _$CuratedGenresPageFromJson(json);
}

@freezed
sealed class CuratedSpecialSections with _$CuratedSpecialSections {
  const factory CuratedSpecialSections({
    required Map<String, List<Movie>> mood,
    required Map<String, List<Movie>> duration,
  }) = _CuratedSpecialSections;

  factory CuratedSpecialSections.fromJson(Map<String, dynamic> json) =>
      _$CuratedSpecialSectionsFromJson(json);
}

@freezed
sealed class CuratedHomepage with _$CuratedHomepage {
  const factory CuratedHomepage({
    required List<Movie> hero,
    required List<Movie> trending,
    @JsonKey(name: 'recently_added') required List<Movie> recentlyAdded,
    @JsonKey(name: 'top_rated') required List<Movie> topRated,
    required Map<String, List<Movie>> rows,
  }) = _CuratedHomepage;

  factory CuratedHomepage.fromJson(Map<String, dynamic> json) =>
      _$CuratedHomepageFromJson(json);
}

@freezed
sealed class CuratedResponse with _$CuratedResponse {
  const factory CuratedResponse({
    required CuratedHomepage homepage,
    @JsonKey(name: 'genres_page') required CuratedGenresPage genresPage,
    @JsonKey(name: 'special_sections') required CuratedSpecialSections specialSections,
  }) = _CuratedResponse;

  factory CuratedResponse.fromJson(Map<String, dynamic> json) =>
      _$CuratedResponseFromJson(json);
}
