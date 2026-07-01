// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MovieListResponse _$MovieListResponseFromJson(Map<String, dynamic> json) =>
    _MovieListResponse(
      success: json['success'] as bool,
      count: (json['count'] as num).toInt(),
      nextOffset: (json['nextOffset'] as num).toInt(),
      movies: (json['movies'] as List<dynamic>)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$MovieListResponseToJson(_MovieListResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'count': instance.count,
      'nextOffset': instance.nextOffset,
      'movies': instance.movies,
    };
