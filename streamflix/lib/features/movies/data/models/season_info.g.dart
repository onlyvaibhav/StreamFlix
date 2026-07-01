// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'season_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SeasonInfo _$SeasonInfoFromJson(Map<String, dynamic> json) => _SeasonInfo(
  seasonNumber: (json['seasonNumber'] as num).toInt(),
  episodes: (json['episodes'] as List<dynamic>)
      .map((e) => Movie.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SeasonInfoToJson(_SeasonInfo instance) =>
    <String, dynamic>{
      'seasonNumber': instance.seasonNumber,
      'episodes': instance.episodes,
    };
