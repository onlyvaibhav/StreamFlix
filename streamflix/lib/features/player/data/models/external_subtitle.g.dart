// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'external_subtitle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExternalSubtitle _$ExternalSubtitleFromJson(Map<String, dynamic> json) =>
    _ExternalSubtitle(
      id: json['id'] as String,
      label: json['label'] as String?,
      language: json['language'] as String?,
      rating: json['rating'] as String?,
      source: json['source'] as String? ?? 'SubDL',
      endpoint: json['endpoint'] as String?,
    );

Map<String, dynamic> _$ExternalSubtitleToJson(_ExternalSubtitle instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'language': instance.language,
      'rating': instance.rating,
      'source': instance.source,
      'endpoint': instance.endpoint,
    };
