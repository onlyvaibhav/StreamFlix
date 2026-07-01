// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Movie _$MovieFromJson(Map<String, dynamic> json) => _Movie(
  id: _readId(json, 'id') as String,
  messageId: (json['messageId'] as num?)?.toInt(),
  title: _readTitle(json, 'title') as String,
  fileName: json['fileName'] as String?,
  size: (json['size'] as num?)?.toInt(),
  sizeFormatted: json['sizeFormatted'] as String?,
  mimeType: json['mimeType'] as String?,
  duration: (json['duration'] as num?)?.toDouble(),
  durationFormatted: json['durationFormatted'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  date: (json['date'] as num?)?.toInt(),
  dateFormatted: _readDateFormatted(json, 'dateFormatted') as String?,
  overview: _readOverview(json, 'overview') as String?,
  description: _readOverview(json, 'description') as String?,
  type: json['type'] as String?,
  year: (json['year'] as num?)?.toInt(),
  runtime: (json['runtime'] as num?)?.toInt(),
  genres: (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
  rating: (json['rating'] as num?)?.toDouble(),
  popularity: (json['popularity'] as num?)?.toDouble(),
  poster: _readPoster(json, 'poster') as String?,
  backdrop: json['backdrop'] as String?,
  logo: json['logo'] as String?,
  tmdbId: (json['tmdbId'] as num?)?.toInt(),
  awards: json['awards'] as String?,
  certification: json['certification'] as String?,
  seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
  episodeNumber: (json['episodeNumber'] as num?)?.toInt(),
  tv: json['tv'] == null
      ? null
      : TvShowInfo.fromJson(json['tv'] as Map<String, dynamic>),
  seasons: (json['seasons'] as List<dynamic>?)
      ?.map((e) => SeasonInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  isSplit: json['isSplit'] as bool?,
  totalParts: (json['totalParts'] as num?)?.toInt(),
  parts: (json['parts'] as List<dynamic>?)
      ?.map((e) => SplitPart.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$MovieToJson(_Movie instance) => <String, dynamic>{
  'id': instance.id,
  'messageId': instance.messageId,
  'title': instance.title,
  'fileName': instance.fileName,
  'size': instance.size,
  'sizeFormatted': instance.sizeFormatted,
  'mimeType': instance.mimeType,
  'duration': instance.duration,
  'durationFormatted': instance.durationFormatted,
  'width': instance.width,
  'height': instance.height,
  'date': instance.date,
  'dateFormatted': instance.dateFormatted,
  'overview': instance.overview,
  'description': instance.description,
  'type': instance.type,
  'year': instance.year,
  'runtime': instance.runtime,
  'genres': instance.genres,
  'rating': instance.rating,
  'popularity': instance.popularity,
  'poster': instance.poster,
  'backdrop': instance.backdrop,
  'logo': instance.logo,
  'tmdbId': instance.tmdbId,
  'awards': instance.awards,
  'certification': instance.certification,
  'seasonNumber': instance.seasonNumber,
  'episodeNumber': instance.episodeNumber,
  'tv': instance.tv,
  'seasons': instance.seasons,
  'isSplit': instance.isSplit,
  'totalParts': instance.totalParts,
  'parts': instance.parts,
};
