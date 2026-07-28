// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curated_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CuratedRow _$CuratedRowFromJson(Map<String, dynamic> json) => _CuratedRow(
  title: _readRowTitle(json, 'title') as String,
  logo: json['logo'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$CuratedRowToJson(_CuratedRow instance) =>
    <String, dynamic>{
      'title': instance.title,
      'logo': instance.logo,
      'items': instance.items,
    };
