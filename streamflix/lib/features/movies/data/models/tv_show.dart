import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix/features/movies/data/models/season_info.dart';

part 'tv_show.freezed.dart';
part 'tv_show.g.dart';

@freezed
sealed class TvShow with _$TvShow {
  const factory TvShow({
    required int showTmdbId,
    required String showTitle,
    String? originalShowTitle,
    String? overview,
    List<String>? genres,
    double? rating,
    double? popularity,
    String? poster,
    String? backdrop,
    String? logo,
    int? year,
    int? totalSeasons,
    int? totalEpisodes,
    required List<int> availableSeasons,
    required int availableEpisodeCount,
    required List<SeasonInfo> seasons,
  }) = _TvShow;

  factory TvShow.fromJson(Map<String, dynamic> json) =>
      _$TvShowFromJson(json);
}

extension TvShowX on TvShow {
  /// Full poster URL
  String? get fullPosterUrl {
    if (poster == null) return null;
    return poster;
  }

  /// Full backdrop URL
  String? get fullBackdropUrl {
    if (backdrop == null) return null;
    return backdrop;
  }

  /// Full logo URL
  String? get fullLogoUrl {
    if (logo == null) return null;
    return logo;
  }

  /// Formatted rating (e.g. "8.2")
  String get formattedRating {
    if (rating == null) return 'N/A';
    return rating!.toStringAsFixed(1);
  }

  /// Genre list formatted as a string
  String get genreList {
    if (genres == null || genres!.isEmpty) return '';
    return genres!.join(', ');
  }
}
