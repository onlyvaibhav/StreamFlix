import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';

part 'movie_list_response.freezed.dart';
part 'movie_list_response.g.dart';

@freezed
sealed class MovieListResponse with _$MovieListResponse {
  const factory MovieListResponse({
    required bool success,
    required int count,
    required int nextOffset,
    required List<Movie> movies,
  }) = _MovieListResponse;

  factory MovieListResponse.fromJson(Map<String, dynamic> json) =>
      _$MovieListResponseFromJson(json);
}
