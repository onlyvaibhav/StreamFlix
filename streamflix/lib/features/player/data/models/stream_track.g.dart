// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stream_track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AudioTrack _$AudioTrackFromJson(Map<String, dynamic> json) => _AudioTrack(
  index: (json['index'] as num).toInt(),
  streamIndex: (json['streamIndex'] as num).toInt(),
  codec: json['codec'] as String? ?? 'unknown',
  language: json['language'] as String? ?? 'Unknown',
  languageCode: json['languageCode'] as String? ?? 'und',
  title: json['title'] as String? ?? '',
  channels: (json['channels'] as num?)?.toInt() ?? 0,
  channelLayout: json['channelLayout'] as String? ?? '',
  browserPlayable: json['browserPlayable'] as bool? ?? true,
  isDefault: json['isDefault'] as bool? ?? false,
);

Map<String, dynamic> _$AudioTrackToJson(_AudioTrack instance) =>
    <String, dynamic>{
      'index': instance.index,
      'streamIndex': instance.streamIndex,
      'codec': instance.codec,
      'language': instance.language,
      'languageCode': instance.languageCode,
      'title': instance.title,
      'channels': instance.channels,
      'channelLayout': instance.channelLayout,
      'browserPlayable': instance.browserPlayable,
      'isDefault': instance.isDefault,
    };

_SubtitleTrack _$SubtitleTrackFromJson(Map<String, dynamic> json) =>
    _SubtitleTrack(
      index: (json['index'] as num).toInt(),
      streamIndex: (json['streamIndex'] as num).toInt(),
      codec: json['codec'] as String? ?? 'unknown',
      language: json['language'] as String? ?? 'Unknown',
      languageCode: json['languageCode'] as String? ?? 'und',
      title: json['title'] as String? ?? '',
      isTextBased: json['isTextBased'] as bool? ?? false,
      isImageBased: json['isImageBased'] as bool? ?? false,
      extractable: json['extractable'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
      isForced: json['isForced'] as bool? ?? false,
    );

Map<String, dynamic> _$SubtitleTrackToJson(_SubtitleTrack instance) =>
    <String, dynamic>{
      'index': instance.index,
      'streamIndex': instance.streamIndex,
      'codec': instance.codec,
      'language': instance.language,
      'languageCode': instance.languageCode,
      'title': instance.title,
      'isTextBased': instance.isTextBased,
      'isImageBased': instance.isImageBased,
      'extractable': instance.extractable,
      'isDefault': instance.isDefault,
      'isForced': instance.isForced,
    };

_TrackInfo _$TrackInfoFromJson(Map<String, dynamic> json) => _TrackInfo(
  fileId: json['fileId'] as String,
  audioCodec: json['audioCodec'] as String? ?? 'unknown',
  browserPlayable: json['browserPlayable'] as bool? ?? true,
  audioTracks:
      (json['audioTracks'] as List<dynamic>?)
          ?.map((e) => AudioTrack.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  subtitleTracks:
      (json['subtitleTracks'] as List<dynamic>?)
          ?.map((e) => SubtitleTrack.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  hasUnsupportedAudio: json['hasUnsupportedAudio'] as bool? ?? false,
  duration: (json['duration'] as num?)?.toDouble() ?? 0,
  ready: json['ready'] as bool? ?? true,
);

Map<String, dynamic> _$TrackInfoToJson(_TrackInfo instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'audioCodec': instance.audioCodec,
      'browserPlayable': instance.browserPlayable,
      'audioTracks': instance.audioTracks,
      'subtitleTracks': instance.subtitleTracks,
      'hasUnsupportedAudio': instance.hasUnsupportedAudio,
      'duration': instance.duration,
      'ready': instance.ready,
    };
