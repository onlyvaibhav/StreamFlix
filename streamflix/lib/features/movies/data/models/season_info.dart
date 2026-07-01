import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';

part 'season_info.freezed.dart';
part 'season_info.g.dart';

@freezed
sealed class SeasonInfo with _$SeasonInfo {
  const factory SeasonInfo({
    required int seasonNumber,
    required List<Movie> episodes,
  }) = _SeasonInfo;

  factory SeasonInfo.fromJson(Map<String, dynamic> json) =>
      _$SeasonInfoFromJson(json);
}
