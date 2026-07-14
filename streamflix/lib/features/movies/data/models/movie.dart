import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix/features/movies/data/models/tv_show_info.dart';
import 'package:streamflix/features/movies/data/models/season_info.dart';
import 'package:streamflix/features/movies/data/models/split_part.dart';

part 'movie.freezed.dart';
part 'movie.g.dart';

Object? _readId(Map json, String key) {
  return json['id'] ?? json['fileId'] ?? json['tmdbId']?.toString();
}

Object? _readTitle(Map json, String key) {
  if (json['tv'] != null && json['tv'] is Map) {
    final tvMap = json['tv'] as Map;
    if (tvMap['episodeTitle'] != null && tvMap['episodeTitle'].toString().trim().isNotEmpty) {
      return tvMap['episodeTitle'];
    }
  }
  return json['title'] ?? json['episodeTitle'] ?? json['fileName'] ?? 'Unknown Item';
}

Object? _readOverview(Map json, String key) {
  if (json['tv'] != null && json['tv'] is Map) {
    final tvMap = json['tv'] as Map;
    if (tvMap['episodeOverview'] != null && tvMap['episodeOverview'].toString().trim().isNotEmpty) {
      return tvMap['episodeOverview'];
    }
  }
  return json['overview'] ?? json['episodeOverview'] ?? json['description'];
}

Object? _readPoster(Map json, String key) {
  return json['poster'] ?? json['thumbnail'];
}

Object? _readDateFormatted(Map json, String key) {
  return json['dateFormatted'] ?? json['releaseDate'] ?? json['airDate'] ?? json['tv']?['airDate'];
}

@freezed
sealed class Movie with _$Movie {
  const factory Movie({
    @JsonKey(readValue: _readId) required String id,
    int? messageId,
    @JsonKey(readValue: _readTitle) required String title,
    String? fileName,
    int? size,
    String? sizeFormatted,
    String? mimeType,
    double? duration,
    String? durationFormatted,
    int? width,
    int? height,
    int? date,
    @JsonKey(readValue: _readDateFormatted) String? dateFormatted,
    @JsonKey(readValue: _readOverview) String? overview,
    @JsonKey(readValue: _readOverview) String? description,
    
    // DB enriched fields
    String? type, // 'movie', 'tv', 'tv_show'
    int? year,
    int? runtime,
    List<String>? genres,
    double? rating,
    double? popularity,
    @JsonKey(readValue: _readPoster) String? poster,
    String? backdrop,
    String? logo,
    int? tmdbId,
    String? awards,
    String? certification,
    
    // TV Flat Fields
    int? seasonNumber,
    int? episodeNumber,
    
    // Grouping metadata
    TvShowInfo? tv,
    List<SeasonInfo>? seasons,
    bool? isSplit,
    int? totalParts,
    List<SplitPart>? parts,
    
    // Episode specific metadata
    @JsonKey(name: 'episode_still') String? episodeStill,
  }) = _Movie;

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
}

extension MovieX on Movie {
  /// Full poster URL
  String? get fullPosterUrl {
    if (poster == null) return null;
    if (poster!.startsWith('http')) return poster;
    return poster; // AppImage wrapper handles prefixing the baseUrl
  }

  /// Full backdrop URL
  String? get fullBackdropUrl {
    if (backdrop == null) return null;
    if (backdrop!.startsWith('http')) return backdrop;
    return backdrop;
  }

  /// Full logo URL
  String? get fullLogoUrl {
    if (logo == null) return null;
    if (logo!.startsWith('http')) return logo;
    return logo;
  }

  /// Full episode still URL
  String? get fullEpisodeStillUrl {
    if (episodeStill == null) return null;
    if (episodeStill!.startsWith('http')) return episodeStill;
    return episodeStill; // AppImage wrapper handles prefixing the baseUrl
  }

  /// Release year extracted from release_date
  String? get releaseYear {
    if (year != null) return year.toString();
    return null;
  }

  /// Formatted runtime (e.g., "2h 15m")
  String? get formattedRuntime {
    if (runtime == null) return null;
    final hours = runtime! ~/ 60;
    final minutes = runtime! % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  /// Rating out of 10 formatted to 1 decimal place
  String get formattedRating {
    if (rating == null) return 'N/A';
    return rating!.toStringAsFixed(1);
  }

  /// Genre names as comma-separated string
  String get genreList {
    if (genres == null || genres!.isEmpty) return '';
    return genres!.join(', ');
  }
}
