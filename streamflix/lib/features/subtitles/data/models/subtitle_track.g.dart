// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SubtitleTrack _$SubtitleTrackFromJson(Map<String, dynamic> json) =>
    _SubtitleTrack(
      language: json['language'] as String,
      languageCode: json['languageCode'] as String,
      url: json['url'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$SubtitleTrackToJson(_SubtitleTrack instance) =>
    <String, dynamic>{
      'language': instance.language,
      'languageCode': instance.languageCode,
      'url': instance.url,
      'isDefault': instance.isDefault,
    };
