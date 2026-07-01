import 'package:freezed_annotation/freezed_annotation.dart';

part 'stream_track.freezed.dart';
part 'stream_track.g.dart';

/// Individual audio track from backend track probe
@freezed
sealed class AudioTrack with _$AudioTrack {
  const factory AudioTrack({
    required int index,
    required int streamIndex,
    @Default('unknown') String codec,
    @Default('Unknown') String language,
    @Default('und') String languageCode,
    @Default('') String title,
    @Default(0) int channels,
    @Default('') String channelLayout,
    @Default(true) bool browserPlayable,
    @Default(false) bool isDefault,
  }) = _AudioTrack;

  factory AudioTrack.fromJson(Map<String, dynamic> json) =>
      _$AudioTrackFromJson(json);
}

/// Individual subtitle track from backend track probe
@freezed
sealed class SubtitleTrack with _$SubtitleTrack {
  const factory SubtitleTrack({
    required int index,
    required int streamIndex,
    @Default('unknown') String codec,
    @Default('Unknown') String language,
    @Default('und') String languageCode,
    @Default('') String title,
    @Default(false) bool isTextBased,
    @Default(false) bool isImageBased,
    @Default(false) bool extractable,
    @Default(false) bool isDefault,
    @Default(false) bool isForced,
  }) = _SubtitleTrack;

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) =>
      _$SubtitleTrackFromJson(json);
}

/// Response from GET /api/stream/:id/tracks
@freezed
sealed class TrackInfo with _$TrackInfo {
  const factory TrackInfo({
    required String fileId,
    @Default('unknown') String audioCodec,
    @Default(true) bool browserPlayable,
    @Default([]) List<AudioTrack> audioTracks,
    @Default([]) List<SubtitleTrack> subtitleTracks,
    @Default(false) bool hasUnsupportedAudio,
    @Default(0) double duration,
    @Default(true) bool ready,
  }) = _TrackInfo;

  factory TrackInfo.fromJson(Map<String, dynamic> json) =>
      _$TrackInfoFromJson(json);
}
