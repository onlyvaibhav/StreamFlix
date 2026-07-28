import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:streamflix/features/movies/data/models/movie.dart';

part 'curated_row.freezed.dart';
part 'curated_row.g.dart';

Object _readRowTitle(Map json, String key) {
  final val = json['title'] ?? json['name'];
  if (val != null && val.toString().trim().isNotEmpty) {
    return val.toString();
  }
  return 'Curated Content';
}

@freezed
sealed class CuratedRow with _$CuratedRow {
  const factory CuratedRow({
    @JsonKey(readValue: _readRowTitle) required String title,
    String? logo,
    @Default([]) List<Movie> items,
  }) = _CuratedRow;

  factory CuratedRow.fromJson(Map<String, dynamic> json) =>
      _$CuratedRowFromJson(json);
}
