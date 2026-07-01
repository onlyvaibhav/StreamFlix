import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtitle_track.freezed.dart';
part 'subtitle_track.g.dart';

/// Available subtitle track
@freezed
sealed class SubtitleTrack with _$SubtitleTrack {
  const factory SubtitleTrack({
    required String language,
    required String languageCode,
    required String url,
    @Default(false) bool isDefault,
  }) = _SubtitleTrack;

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) =>
      _$SubtitleTrackFromJson(json);
}
