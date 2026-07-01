import 'package:freezed_annotation/freezed_annotation.dart';

part 'external_subtitle.freezed.dart';
part 'external_subtitle.g.dart';

/// External subtitle entry from GET /api/subtitles/movie/:movieId
@freezed
sealed class ExternalSubtitle with _$ExternalSubtitle {
  const factory ExternalSubtitle({
    required String id,
    String? label,
    String? language,
    String? rating,
    @Default('SubDL') String source,
    String? endpoint,
  }) = _ExternalSubtitle;

  factory ExternalSubtitle.fromJson(Map<String, dynamic> json) =>
      _$ExternalSubtitleFromJson(json);
}
