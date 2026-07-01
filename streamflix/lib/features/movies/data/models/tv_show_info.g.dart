// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_show_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TvShowInfo _$TvShowInfoFromJson(Map<String, dynamic> json) => _TvShowInfo(
  showTitle: json['showTitle'] as String,
  originalShowTitle: json['originalShowTitle'] as String?,
  seasonNumber: (json['seasonNumber'] as num).toInt(),
  episodeNumber: (json['episodeNumber'] as num).toInt(),
  episodeTitle: json['episodeTitle'] as String?,
  episodeOverview: json['episodeOverview'] as String?,
  showTmdbId: (json['showTmdbId'] as num).toInt(),
  episodeRuntime: (json['episodeRuntime'] as num?)?.toInt(),
  totalSeasons: (json['totalSeasons'] as num?)?.toInt(),
  totalEpisodes: (json['totalEpisodes'] as num?)?.toInt(),
);

Map<String, dynamic> _$TvShowInfoToJson(_TvShowInfo instance) =>
    <String, dynamic>{
      'showTitle': instance.showTitle,
      'originalShowTitle': instance.originalShowTitle,
      'seasonNumber': instance.seasonNumber,
      'episodeNumber': instance.episodeNumber,
      'episodeTitle': instance.episodeTitle,
      'episodeOverview': instance.episodeOverview,
      'showTmdbId': instance.showTmdbId,
      'episodeRuntime': instance.episodeRuntime,
      'totalSeasons': instance.totalSeasons,
      'totalEpisodes': instance.totalEpisodes,
    };
