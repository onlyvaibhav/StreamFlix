import 'package:freezed_annotation/freezed_annotation.dart';

part 'split_part.freezed.dart';
part 'split_part.g.dart';

@freezed
sealed class SplitPart with _$SplitPart {
  const factory SplitPart({
    String? fileId,
    int? messageId,
    int? partNumber,
    String? fileName,
    int? size,
    String? sizeFormatted,
    double? duration,
  }) = _SplitPart;

  factory SplitPart.fromJson(Map<String, dynamic> json) =>
      _$SplitPartFromJson(json);
}
