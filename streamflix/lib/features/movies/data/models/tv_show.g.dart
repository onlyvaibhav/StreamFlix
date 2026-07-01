// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_show.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TvShow _$TvShowFromJson(Map<String, dynamic> json) => _TvShow(
  showTmdbId: (json['showTmdbId'] as num).toInt(),
  showTitle: json['showTitle'] as String,
  originalShowTitle: json['originalShowTitle'] as String?,
  overview: json['overview'] as String?,
  genres: (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
  rating: (json['rating'] as num?)?.toDouble(),
  popularity: (json['popularity'] as num?)?.toDouble(),
  poster: json['poster'] as String?,
  backdrop: json['backdrop'] as String?,
  logo: json['logo'] as String?,
  year: (json['year'] as num?)?.toInt(),
  totalSeasons: (json['totalSeasons'] as num?)?.toInt(),
  totalEpisodes: (json['totalEpisodes'] as num?)?.toInt(),
  availableSeasons: (json['availableSeasons'] as List<dynamic>)
      .map((e) => (e as num).toInt())
      .toList(),
  availableEpisodeCount: (json['availableEpisodeCount'] as num).toInt(),
  seasons: (json['seasons'] as List<dynamic>)
      .map((e) => SeasonInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TvShowToJson(_TvShow instance) => <String, dynamic>{
  'showTmdbId': instance.showTmdbId,
  'showTitle': instance.showTitle,
  'originalShowTitle': instance.originalShowTitle,
  'overview': instance.overview,
  'genres': instance.genres,
  'rating': instance.rating,
  'popularity': instance.popularity,
  'poster': instance.poster,
  'backdrop': instance.backdrop,
  'logo': instance.logo,
  'year': instance.year,
  'totalSeasons': instance.totalSeasons,
  'totalEpisodes': instance.totalEpisodes,
  'availableSeasons': instance.availableSeasons,
  'availableEpisodeCount': instance.availableEpisodeCount,
  'seasons': instance.seasons,
};
