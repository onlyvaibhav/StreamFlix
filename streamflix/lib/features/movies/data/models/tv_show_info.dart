import 'package:freezed_annotation/freezed_annotation.dart';

part 'tv_show_info.freezed.dart';
part 'tv_show_info.g.dart';

@freezed
sealed class TvShowInfo with _$TvShowInfo {
  const factory TvShowInfo({
    required String showTitle,
    String? originalShowTitle,
    required int seasonNumber,
    required int episodeNumber,
    String? episodeTitle,
    String? episodeOverview,
    required int showTmdbId,
    int? episodeRuntime,
    int? totalSeasons,
    int? totalEpisodes,
  }) = _TvShowInfo;

  factory TvShowInfo.fromJson(Map<String, dynamic> json) =>
      _$TvShowInfoFromJson(json);
}
