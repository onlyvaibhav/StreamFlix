import 'package:freezed_annotation/freezed_annotation.dart';

part 'split_part.freezed.dart';
part 'split_part.g.dart';

double? _readDuration(Map json, String key) {
  final val = json[key];
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

@freezed
sealed class SplitPart with _$SplitPart {
  const factory SplitPart({
    String? fileId,
    int? messageId,
    int? partNumber,
    String? fileName,
    int? size,
    String? sizeFormatted,
    @JsonKey(readValue: _readDuration) double? duration,
  }) = _SplitPart;

  factory SplitPart.fromJson(Map<String, dynamic> json) =>
      _$SplitPartFromJson(json);
}
