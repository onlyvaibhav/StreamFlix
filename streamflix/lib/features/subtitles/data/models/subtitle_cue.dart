import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtitle_cue.freezed.dart';

/// Individual subtitle cue with timing
@freezed
sealed class SubtitleCue with _$SubtitleCue {
  const factory SubtitleCue({
    required int index,
    required Duration start,
    required Duration end,
    required String text,
  }) = _SubtitleCue;
}

extension SubtitleCueX on SubtitleCue {
  /// Check if this cue should be displayed at given position
  bool isActiveAt(Duration position) {
    return position >= start && position <= end;
  }
}
