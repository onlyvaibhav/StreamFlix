// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'movie.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Movie {

@JsonKey(readValue: _readId) String get id; int? get messageId;@JsonKey(readValue: _readTitle) String get title; String? get fileName; int? get size; String? get sizeFormatted; String? get mimeType; double? get duration; String? get durationFormatted; int? get width; int? get height; int? get date;@JsonKey(readValue: _readDateFormatted) String? get dateFormatted;@JsonKey(readValue: _readOverview) String? get overview;@JsonKey(readValue: _readOverview) String? get description; String? get type; int? get year; int? get runtime; List<String>? get genres; double? get rating; double? get popularity;@JsonKey(readValue: _readPoster) String? get poster; String? get backdrop; String? get logo; int? get tmdbId; String? get awards; String? get certification; int? get seasonNumber; int? get episodeNumber; TvShowInfo? get tv; List<SeasonInfo>? get seasons; bool? get isSplit; int? get totalParts; List<SplitPart>? get parts;
/// Create a copy of Movie
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MovieCopyWith<Movie> get copyWith => _$MovieCopyWithImpl<Movie>(this as Movie, _$identity);

  /// Serializes this Movie to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Movie&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.title, title) || other.title == title)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.size, size) || other.size == size)&&(identical(other.sizeFormatted, sizeFormatted) || other.sizeFormatted == sizeFormatted)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.durationFormatted, durationFormatted) || other.durationFormatted == durationFormatted)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.date, date) || other.date == date)&&(identical(other.dateFormatted, dateFormatted) || other.dateFormatted == dateFormatted)&&(identical(other.overview, overview) || other.overview == overview)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.year, year) || other.year == year)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&const DeepCollectionEquality().equals(other.genres, genres)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.popularity, popularity) || other.popularity == popularity)&&(identical(other.poster, poster) || other.poster == poster)&&(identical(other.backdrop, backdrop) || other.backdrop == backdrop)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.tmdbId, tmdbId) || other.tmdbId == tmdbId)&&(identical(other.awards, awards) || other.awards == awards)&&(identical(other.certification, certification) || other.certification == certification)&&(identical(other.seasonNumber, seasonNumber) || other.seasonNumber == seasonNumber)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.tv, tv) || other.tv == tv)&&const DeepCollectionEquality().equals(other.seasons, seasons)&&(identical(other.isSplit, isSplit) || other.isSplit == isSplit)&&(identical(other.totalParts, totalParts) || other.totalParts == totalParts)&&const DeepCollectionEquality().equals(other.parts, parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,messageId,title,fileName,size,sizeFormatted,mimeType,duration,durationFormatted,width,height,date,dateFormatted,overview,description,type,year,runtime,const DeepCollectionEquality().hash(genres),rating,popularity,poster,backdrop,logo,tmdbId,awards,certification,seasonNumber,episodeNumber,tv,const DeepCollectionEquality().hash(seasons),isSplit,totalParts,const DeepCollectionEquality().hash(parts)]);

@override
String toString() {
  return 'Movie(id: $id, messageId: $messageId, title: $title, fileName: $fileName, size: $size, sizeFormatted: $sizeFormatted, mimeType: $mimeType, duration: $duration, durationFormatted: $durationFormatted, width: $width, height: $height, date: $date, dateFormatted: $dateFormatted, overview: $overview, description: $description, type: $type, year: $year, runtime: $runtime, genres: $genres, rating: $rating, popularity: $popularity, poster: $poster, backdrop: $backdrop, logo: $logo, tmdbId: $tmdbId, awards: $awards, certification: $certification, seasonNumber: $seasonNumber, episodeNumber: $episodeNumber, tv: $tv, seasons: $seasons, isSplit: $isSplit, totalParts: $totalParts, parts: $parts)';
}


}

/// @nodoc
abstract mixin class $MovieCopyWith<$Res>  {
  factory $MovieCopyWith(Movie value, $Res Function(Movie) _then) = _$MovieCopyWithImpl;
@useResult
$Res call({
@JsonKey(readValue: _readId) String id, int? messageId,@JsonKey(readValue: _readTitle) String title, String? fileName, int? size, String? sizeFormatted, String? mimeType, double? duration, String? durationFormatted, int? width, int? height, int? date,@JsonKey(readValue: _readDateFormatted) String? dateFormatted,@JsonKey(readValue: _readOverview) String? overview,@JsonKey(readValue: _readOverview) String? description, String? type, int? year, int? runtime, List<String>? genres, double? rating, double? popularity,@JsonKey(readValue: _readPoster) String? poster, String? backdrop, String? logo, int? tmdbId, String? awards, String? certification, int? seasonNumber, int? episodeNumber, TvShowInfo? tv, List<SeasonInfo>? seasons, bool? isSplit, int? totalParts, List<SplitPart>? parts
});


$TvShowInfoCopyWith<$Res>? get tv;

}
/// @nodoc
class _$MovieCopyWithImpl<$Res>
    implements $MovieCopyWith<$Res> {
  _$MovieCopyWithImpl(this._self, this._then);

  final Movie _self;
  final $Res Function(Movie) _then;

/// Create a copy of Movie
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? messageId = freezed,Object? title = null,Object? fileName = freezed,Object? size = freezed,Object? sizeFormatted = freezed,Object? mimeType = freezed,Object? duration = freezed,Object? durationFormatted = freezed,Object? width = freezed,Object? height = freezed,Object? date = freezed,Object? dateFormatted = freezed,Object? overview = freezed,Object? description = freezed,Object? type = freezed,Object? year = freezed,Object? runtime = freezed,Object? genres = freezed,Object? rating = freezed,Object? popularity = freezed,Object? poster = freezed,Object? backdrop = freezed,Object? logo = freezed,Object? tmdbId = freezed,Object? awards = freezed,Object? certification = freezed,Object? seasonNumber = freezed,Object? episodeNumber = freezed,Object? tv = freezed,Object? seasons = freezed,Object? isSplit = freezed,Object? totalParts = freezed,Object? parts = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,sizeFormatted: freezed == sizeFormatted ? _self.sizeFormatted : sizeFormatted // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as double?,durationFormatted: freezed == durationFormatted ? _self.durationFormatted : durationFormatted // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as int?,dateFormatted: freezed == dateFormatted ? _self.dateFormatted : dateFormatted // ignore: cast_nullable_to_non_nullable
as String?,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as int?,genres: freezed == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as double?,poster: freezed == poster ? _self.poster : poster // ignore: cast_nullable_to_non_nullable
as String?,backdrop: freezed == backdrop ? _self.backdrop : backdrop // ignore: cast_nullable_to_non_nullable
as String?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,tmdbId: freezed == tmdbId ? _self.tmdbId : tmdbId // ignore: cast_nullable_to_non_nullable
as int?,awards: freezed == awards ? _self.awards : awards // ignore: cast_nullable_to_non_nullable
as String?,certification: freezed == certification ? _self.certification : certification // ignore: cast_nullable_to_non_nullable
as String?,seasonNumber: freezed == seasonNumber ? _self.seasonNumber : seasonNumber // ignore: cast_nullable_to_non_nullable
as int?,episodeNumber: freezed == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int?,tv: freezed == tv ? _self.tv : tv // ignore: cast_nullable_to_non_nullable
as TvShowInfo?,seasons: freezed == seasons ? _self.seasons : seasons // ignore: cast_nullable_to_non_nullable
as List<SeasonInfo>?,isSplit: freezed == isSplit ? _self.isSplit : isSplit // ignore: cast_nullable_to_non_nullable
as bool?,totalParts: freezed == totalParts ? _self.totalParts : totalParts // ignore: cast_nullable_to_non_nullable
as int?,parts: freezed == parts ? _self.parts : parts // ignore: cast_nullable_to_non_nullable
as List<SplitPart>?,
  ));
}
/// Create a copy of Movie
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvShowInfoCopyWith<$Res>? get tv {
    if (_self.tv == null) {
    return null;
  }

  return $TvShowInfoCopyWith<$Res>(_self.tv!, (value) {
    return _then(_self.copyWith(tv: value));
  });
}
}


/// Adds pattern-matching-related methods to [Movie].
extension MoviePatterns on Movie {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Movie value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Movie() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Movie value)  $default,){
final _that = this;
switch (_that) {
case _Movie():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Movie value)?  $default,){
final _that = this;
switch (_that) {
case _Movie() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(readValue: _readId)  String id,  int? messageId, @JsonKey(readValue: _readTitle)  String title,  String? fileName,  int? size,  String? sizeFormatted,  String? mimeType,  double? duration,  String? durationFormatted,  int? width,  int? height,  int? date, @JsonKey(readValue: _readDateFormatted)  String? dateFormatted, @JsonKey(readValue: _readOverview)  String? overview, @JsonKey(readValue: _readOverview)  String? description,  String? type,  int? year,  int? runtime,  List<String>? genres,  double? rating,  double? popularity, @JsonKey(readValue: _readPoster)  String? poster,  String? backdrop,  String? logo,  int? tmdbId,  String? awards,  String? certification,  int? seasonNumber,  int? episodeNumber,  TvShowInfo? tv,  List<SeasonInfo>? seasons,  bool? isSplit,  int? totalParts,  List<SplitPart>? parts)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Movie() when $default != null:
return $default(_that.id,_that.messageId,_that.title,_that.fileName,_that.size,_that.sizeFormatted,_that.mimeType,_that.duration,_that.durationFormatted,_that.width,_that.height,_that.date,_that.dateFormatted,_that.overview,_that.description,_that.type,_that.year,_that.runtime,_that.genres,_that.rating,_that.popularity,_that.poster,_that.backdrop,_that.logo,_that.tmdbId,_that.awards,_that.certification,_that.seasonNumber,_that.episodeNumber,_that.tv,_that.seasons,_that.isSplit,_that.totalParts,_that.parts);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(readValue: _readId)  String id,  int? messageId, @JsonKey(readValue: _readTitle)  String title,  String? fileName,  int? size,  String? sizeFormatted,  String? mimeType,  double? duration,  String? durationFormatted,  int? width,  int? height,  int? date, @JsonKey(readValue: _readDateFormatted)  String? dateFormatted, @JsonKey(readValue: _readOverview)  String? overview, @JsonKey(readValue: _readOverview)  String? description,  String? type,  int? year,  int? runtime,  List<String>? genres,  double? rating,  double? popularity, @JsonKey(readValue: _readPoster)  String? poster,  String? backdrop,  String? logo,  int? tmdbId,  String? awards,  String? certification,  int? seasonNumber,  int? episodeNumber,  TvShowInfo? tv,  List<SeasonInfo>? seasons,  bool? isSplit,  int? totalParts,  List<SplitPart>? parts)  $default,) {final _that = this;
switch (_that) {
case _Movie():
return $default(_that.id,_that.messageId,_that.title,_that.fileName,_that.size,_that.sizeFormatted,_that.mimeType,_that.duration,_that.durationFormatted,_that.width,_that.height,_that.date,_that.dateFormatted,_that.overview,_that.description,_that.type,_that.year,_that.runtime,_that.genres,_that.rating,_that.popularity,_that.poster,_that.backdrop,_that.logo,_that.tmdbId,_that.awards,_that.certification,_that.seasonNumber,_that.episodeNumber,_that.tv,_that.seasons,_that.isSplit,_that.totalParts,_that.parts);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(readValue: _readId)  String id,  int? messageId, @JsonKey(readValue: _readTitle)  String title,  String? fileName,  int? size,  String? sizeFormatted,  String? mimeType,  double? duration,  String? durationFormatted,  int? width,  int? height,  int? date, @JsonKey(readValue: _readDateFormatted)  String? dateFormatted, @JsonKey(readValue: _readOverview)  String? overview, @JsonKey(readValue: _readOverview)  String? description,  String? type,  int? year,  int? runtime,  List<String>? genres,  double? rating,  double? popularity, @JsonKey(readValue: _readPoster)  String? poster,  String? backdrop,  String? logo,  int? tmdbId,  String? awards,  String? certification,  int? seasonNumber,  int? episodeNumber,  TvShowInfo? tv,  List<SeasonInfo>? seasons,  bool? isSplit,  int? totalParts,  List<SplitPart>? parts)?  $default,) {final _that = this;
switch (_that) {
case _Movie() when $default != null:
return $default(_that.id,_that.messageId,_that.title,_that.fileName,_that.size,_that.sizeFormatted,_that.mimeType,_that.duration,_that.durationFormatted,_that.width,_that.height,_that.date,_that.dateFormatted,_that.overview,_that.description,_that.type,_that.year,_that.runtime,_that.genres,_that.rating,_that.popularity,_that.poster,_that.backdrop,_that.logo,_that.tmdbId,_that.awards,_that.certification,_that.seasonNumber,_that.episodeNumber,_that.tv,_that.seasons,_that.isSplit,_that.totalParts,_that.parts);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Movie implements Movie {
  const _Movie({@JsonKey(readValue: _readId) required this.id, this.messageId, @JsonKey(readValue: _readTitle) required this.title, this.fileName, this.size, this.sizeFormatted, this.mimeType, this.duration, this.durationFormatted, this.width, this.height, this.date, @JsonKey(readValue: _readDateFormatted) this.dateFormatted, @JsonKey(readValue: _readOverview) this.overview, @JsonKey(readValue: _readOverview) this.description, this.type, this.year, this.runtime, final  List<String>? genres, this.rating, this.popularity, @JsonKey(readValue: _readPoster) this.poster, this.backdrop, this.logo, this.tmdbId, this.awards, this.certification, this.seasonNumber, this.episodeNumber, this.tv, final  List<SeasonInfo>? seasons, this.isSplit, this.totalParts, final  List<SplitPart>? parts}): _genres = genres,_seasons = seasons,_parts = parts;
  factory _Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);

@override@JsonKey(readValue: _readId) final  String id;
@override final  int? messageId;
@override@JsonKey(readValue: _readTitle) final  String title;
@override final  String? fileName;
@override final  int? size;
@override final  String? sizeFormatted;
@override final  String? mimeType;
@override final  double? duration;
@override final  String? durationFormatted;
@override final  int? width;
@override final  int? height;
@override final  int? date;
@override@JsonKey(readValue: _readDateFormatted) final  String? dateFormatted;
@override@JsonKey(readValue: _readOverview) final  String? overview;
@override@JsonKey(readValue: _readOverview) final  String? description;
@override final  String? type;
@override final  int? year;
@override final  int? runtime;
 final  List<String>? _genres;
@override List<String>? get genres {
  final value = _genres;
  if (value == null) return null;
  if (_genres is EqualUnmodifiableListView) return _genres;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  double? rating;
@override final  double? popularity;
@override@JsonKey(readValue: _readPoster) final  String? poster;
@override final  String? backdrop;
@override final  String? logo;
@override final  int? tmdbId;
@override final  String? awards;
@override final  String? certification;
@override final  int? seasonNumber;
@override final  int? episodeNumber;
@override final  TvShowInfo? tv;
 final  List<SeasonInfo>? _seasons;
@override List<SeasonInfo>? get seasons {
  final value = _seasons;
  if (value == null) return null;
  if (_seasons is EqualUnmodifiableListView) return _seasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  bool? isSplit;
@override final  int? totalParts;
 final  List<SplitPart>? _parts;
@override List<SplitPart>? get parts {
  final value = _parts;
  if (value == null) return null;
  if (_parts is EqualUnmodifiableListView) return _parts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of Movie
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MovieCopyWith<_Movie> get copyWith => __$MovieCopyWithImpl<_Movie>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MovieToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Movie&&(identical(other.id, id) || other.id == id)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.title, title) || other.title == title)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.size, size) || other.size == size)&&(identical(other.sizeFormatted, sizeFormatted) || other.sizeFormatted == sizeFormatted)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.durationFormatted, durationFormatted) || other.durationFormatted == durationFormatted)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.date, date) || other.date == date)&&(identical(other.dateFormatted, dateFormatted) || other.dateFormatted == dateFormatted)&&(identical(other.overview, overview) || other.overview == overview)&&(identical(other.description, description) || other.description == description)&&(identical(other.type, type) || other.type == type)&&(identical(other.year, year) || other.year == year)&&(identical(other.runtime, runtime) || other.runtime == runtime)&&const DeepCollectionEquality().equals(other._genres, _genres)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.popularity, popularity) || other.popularity == popularity)&&(identical(other.poster, poster) || other.poster == poster)&&(identical(other.backdrop, backdrop) || other.backdrop == backdrop)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.tmdbId, tmdbId) || other.tmdbId == tmdbId)&&(identical(other.awards, awards) || other.awards == awards)&&(identical(other.certification, certification) || other.certification == certification)&&(identical(other.seasonNumber, seasonNumber) || other.seasonNumber == seasonNumber)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.tv, tv) || other.tv == tv)&&const DeepCollectionEquality().equals(other._seasons, _seasons)&&(identical(other.isSplit, isSplit) || other.isSplit == isSplit)&&(identical(other.totalParts, totalParts) || other.totalParts == totalParts)&&const DeepCollectionEquality().equals(other._parts, _parts));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,messageId,title,fileName,size,sizeFormatted,mimeType,duration,durationFormatted,width,height,date,dateFormatted,overview,description,type,year,runtime,const DeepCollectionEquality().hash(_genres),rating,popularity,poster,backdrop,logo,tmdbId,awards,certification,seasonNumber,episodeNumber,tv,const DeepCollectionEquality().hash(_seasons),isSplit,totalParts,const DeepCollectionEquality().hash(_parts)]);

@override
String toString() {
  return 'Movie(id: $id, messageId: $messageId, title: $title, fileName: $fileName, size: $size, sizeFormatted: $sizeFormatted, mimeType: $mimeType, duration: $duration, durationFormatted: $durationFormatted, width: $width, height: $height, date: $date, dateFormatted: $dateFormatted, overview: $overview, description: $description, type: $type, year: $year, runtime: $runtime, genres: $genres, rating: $rating, popularity: $popularity, poster: $poster, backdrop: $backdrop, logo: $logo, tmdbId: $tmdbId, awards: $awards, certification: $certification, seasonNumber: $seasonNumber, episodeNumber: $episodeNumber, tv: $tv, seasons: $seasons, isSplit: $isSplit, totalParts: $totalParts, parts: $parts)';
}


}

/// @nodoc
abstract mixin class _$MovieCopyWith<$Res> implements $MovieCopyWith<$Res> {
  factory _$MovieCopyWith(_Movie value, $Res Function(_Movie) _then) = __$MovieCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(readValue: _readId) String id, int? messageId,@JsonKey(readValue: _readTitle) String title, String? fileName, int? size, String? sizeFormatted, String? mimeType, double? duration, String? durationFormatted, int? width, int? height, int? date,@JsonKey(readValue: _readDateFormatted) String? dateFormatted,@JsonKey(readValue: _readOverview) String? overview,@JsonKey(readValue: _readOverview) String? description, String? type, int? year, int? runtime, List<String>? genres, double? rating, double? popularity,@JsonKey(readValue: _readPoster) String? poster, String? backdrop, String? logo, int? tmdbId, String? awards, String? certification, int? seasonNumber, int? episodeNumber, TvShowInfo? tv, List<SeasonInfo>? seasons, bool? isSplit, int? totalParts, List<SplitPart>? parts
});


@override $TvShowInfoCopyWith<$Res>? get tv;

}
/// @nodoc
class __$MovieCopyWithImpl<$Res>
    implements _$MovieCopyWith<$Res> {
  __$MovieCopyWithImpl(this._self, this._then);

  final _Movie _self;
  final $Res Function(_Movie) _then;

/// Create a copy of Movie
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? messageId = freezed,Object? title = null,Object? fileName = freezed,Object? size = freezed,Object? sizeFormatted = freezed,Object? mimeType = freezed,Object? duration = freezed,Object? durationFormatted = freezed,Object? width = freezed,Object? height = freezed,Object? date = freezed,Object? dateFormatted = freezed,Object? overview = freezed,Object? description = freezed,Object? type = freezed,Object? year = freezed,Object? runtime = freezed,Object? genres = freezed,Object? rating = freezed,Object? popularity = freezed,Object? poster = freezed,Object? backdrop = freezed,Object? logo = freezed,Object? tmdbId = freezed,Object? awards = freezed,Object? certification = freezed,Object? seasonNumber = freezed,Object? episodeNumber = freezed,Object? tv = freezed,Object? seasons = freezed,Object? isSplit = freezed,Object? totalParts = freezed,Object? parts = freezed,}) {
  return _then(_Movie(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,sizeFormatted: freezed == sizeFormatted ? _self.sizeFormatted : sizeFormatted // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as double?,durationFormatted: freezed == durationFormatted ? _self.durationFormatted : durationFormatted // ignore: cast_nullable_to_non_nullable
as String?,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as int?,dateFormatted: freezed == dateFormatted ? _self.dateFormatted : dateFormatted // ignore: cast_nullable_to_non_nullable
as String?,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,runtime: freezed == runtime ? _self.runtime : runtime // ignore: cast_nullable_to_non_nullable
as int?,genres: freezed == genres ? _self._genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as double?,poster: freezed == poster ? _self.poster : poster // ignore: cast_nullable_to_non_nullable
as String?,backdrop: freezed == backdrop ? _self.backdrop : backdrop // ignore: cast_nullable_to_non_nullable
as String?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,tmdbId: freezed == tmdbId ? _self.tmdbId : tmdbId // ignore: cast_nullable_to_non_nullable
as int?,awards: freezed == awards ? _self.awards : awards // ignore: cast_nullable_to_non_nullable
as String?,certification: freezed == certification ? _self.certification : certification // ignore: cast_nullable_to_non_nullable
as String?,seasonNumber: freezed == seasonNumber ? _self.seasonNumber : seasonNumber // ignore: cast_nullable_to_non_nullable
as int?,episodeNumber: freezed == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int?,tv: freezed == tv ? _self.tv : tv // ignore: cast_nullable_to_non_nullable
as TvShowInfo?,seasons: freezed == seasons ? _self._seasons : seasons // ignore: cast_nullable_to_non_nullable
as List<SeasonInfo>?,isSplit: freezed == isSplit ? _self.isSplit : isSplit // ignore: cast_nullable_to_non_nullable
as bool?,totalParts: freezed == totalParts ? _self.totalParts : totalParts // ignore: cast_nullable_to_non_nullable
as int?,parts: freezed == parts ? _self._parts : parts // ignore: cast_nullable_to_non_nullable
as List<SplitPart>?,
  ));
}

/// Create a copy of Movie
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TvShowInfoCopyWith<$Res>? get tv {
    if (_self.tv == null) {
    return null;
  }

  return $TvShowInfoCopyWith<$Res>(_self.tv!, (value) {
    return _then(_self.copyWith(tv: value));
  });
}
}

// dart format on
