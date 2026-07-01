// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tv_show.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TvShow {

 int get showTmdbId; String get showTitle; String? get originalShowTitle; String? get overview; List<String>? get genres; double? get rating; double? get popularity; String? get poster; String? get backdrop; String? get logo; int? get year; int? get totalSeasons; int? get totalEpisodes; List<int> get availableSeasons; int get availableEpisodeCount; List<SeasonInfo> get seasons;
/// Create a copy of TvShow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TvShowCopyWith<TvShow> get copyWith => _$TvShowCopyWithImpl<TvShow>(this as TvShow, _$identity);

  /// Serializes this TvShow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TvShow&&(identical(other.showTmdbId, showTmdbId) || other.showTmdbId == showTmdbId)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.originalShowTitle, originalShowTitle) || other.originalShowTitle == originalShowTitle)&&(identical(other.overview, overview) || other.overview == overview)&&const DeepCollectionEquality().equals(other.genres, genres)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.popularity, popularity) || other.popularity == popularity)&&(identical(other.poster, poster) || other.poster == poster)&&(identical(other.backdrop, backdrop) || other.backdrop == backdrop)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.year, year) || other.year == year)&&(identical(other.totalSeasons, totalSeasons) || other.totalSeasons == totalSeasons)&&(identical(other.totalEpisodes, totalEpisodes) || other.totalEpisodes == totalEpisodes)&&const DeepCollectionEquality().equals(other.availableSeasons, availableSeasons)&&(identical(other.availableEpisodeCount, availableEpisodeCount) || other.availableEpisodeCount == availableEpisodeCount)&&const DeepCollectionEquality().equals(other.seasons, seasons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,showTmdbId,showTitle,originalShowTitle,overview,const DeepCollectionEquality().hash(genres),rating,popularity,poster,backdrop,logo,year,totalSeasons,totalEpisodes,const DeepCollectionEquality().hash(availableSeasons),availableEpisodeCount,const DeepCollectionEquality().hash(seasons));

@override
String toString() {
  return 'TvShow(showTmdbId: $showTmdbId, showTitle: $showTitle, originalShowTitle: $originalShowTitle, overview: $overview, genres: $genres, rating: $rating, popularity: $popularity, poster: $poster, backdrop: $backdrop, logo: $logo, year: $year, totalSeasons: $totalSeasons, totalEpisodes: $totalEpisodes, availableSeasons: $availableSeasons, availableEpisodeCount: $availableEpisodeCount, seasons: $seasons)';
}


}

/// @nodoc
abstract mixin class $TvShowCopyWith<$Res>  {
  factory $TvShowCopyWith(TvShow value, $Res Function(TvShow) _then) = _$TvShowCopyWithImpl;
@useResult
$Res call({
 int showTmdbId, String showTitle, String? originalShowTitle, String? overview, List<String>? genres, double? rating, double? popularity, String? poster, String? backdrop, String? logo, int? year, int? totalSeasons, int? totalEpisodes, List<int> availableSeasons, int availableEpisodeCount, List<SeasonInfo> seasons
});




}
/// @nodoc
class _$TvShowCopyWithImpl<$Res>
    implements $TvShowCopyWith<$Res> {
  _$TvShowCopyWithImpl(this._self, this._then);

  final TvShow _self;
  final $Res Function(TvShow) _then;

/// Create a copy of TvShow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? showTmdbId = null,Object? showTitle = null,Object? originalShowTitle = freezed,Object? overview = freezed,Object? genres = freezed,Object? rating = freezed,Object? popularity = freezed,Object? poster = freezed,Object? backdrop = freezed,Object? logo = freezed,Object? year = freezed,Object? totalSeasons = freezed,Object? totalEpisodes = freezed,Object? availableSeasons = null,Object? availableEpisodeCount = null,Object? seasons = null,}) {
  return _then(_self.copyWith(
showTmdbId: null == showTmdbId ? _self.showTmdbId : showTmdbId // ignore: cast_nullable_to_non_nullable
as int,showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String,originalShowTitle: freezed == originalShowTitle ? _self.originalShowTitle : originalShowTitle // ignore: cast_nullable_to_non_nullable
as String?,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,genres: freezed == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as double?,poster: freezed == poster ? _self.poster : poster // ignore: cast_nullable_to_non_nullable
as String?,backdrop: freezed == backdrop ? _self.backdrop : backdrop // ignore: cast_nullable_to_non_nullable
as String?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,totalSeasons: freezed == totalSeasons ? _self.totalSeasons : totalSeasons // ignore: cast_nullable_to_non_nullable
as int?,totalEpisodes: freezed == totalEpisodes ? _self.totalEpisodes : totalEpisodes // ignore: cast_nullable_to_non_nullable
as int?,availableSeasons: null == availableSeasons ? _self.availableSeasons : availableSeasons // ignore: cast_nullable_to_non_nullable
as List<int>,availableEpisodeCount: null == availableEpisodeCount ? _self.availableEpisodeCount : availableEpisodeCount // ignore: cast_nullable_to_non_nullable
as int,seasons: null == seasons ? _self.seasons : seasons // ignore: cast_nullable_to_non_nullable
as List<SeasonInfo>,
  ));
}

}


/// Adds pattern-matching-related methods to [TvShow].
extension TvShowPatterns on TvShow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TvShow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TvShow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TvShow value)  $default,){
final _that = this;
switch (_that) {
case _TvShow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TvShow value)?  $default,){
final _that = this;
switch (_that) {
case _TvShow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int showTmdbId,  String showTitle,  String? originalShowTitle,  String? overview,  List<String>? genres,  double? rating,  double? popularity,  String? poster,  String? backdrop,  String? logo,  int? year,  int? totalSeasons,  int? totalEpisodes,  List<int> availableSeasons,  int availableEpisodeCount,  List<SeasonInfo> seasons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TvShow() when $default != null:
return $default(_that.showTmdbId,_that.showTitle,_that.originalShowTitle,_that.overview,_that.genres,_that.rating,_that.popularity,_that.poster,_that.backdrop,_that.logo,_that.year,_that.totalSeasons,_that.totalEpisodes,_that.availableSeasons,_that.availableEpisodeCount,_that.seasons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int showTmdbId,  String showTitle,  String? originalShowTitle,  String? overview,  List<String>? genres,  double? rating,  double? popularity,  String? poster,  String? backdrop,  String? logo,  int? year,  int? totalSeasons,  int? totalEpisodes,  List<int> availableSeasons,  int availableEpisodeCount,  List<SeasonInfo> seasons)  $default,) {final _that = this;
switch (_that) {
case _TvShow():
return $default(_that.showTmdbId,_that.showTitle,_that.originalShowTitle,_that.overview,_that.genres,_that.rating,_that.popularity,_that.poster,_that.backdrop,_that.logo,_that.year,_that.totalSeasons,_that.totalEpisodes,_that.availableSeasons,_that.availableEpisodeCount,_that.seasons);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int showTmdbId,  String showTitle,  String? originalShowTitle,  String? overview,  List<String>? genres,  double? rating,  double? popularity,  String? poster,  String? backdrop,  String? logo,  int? year,  int? totalSeasons,  int? totalEpisodes,  List<int> availableSeasons,  int availableEpisodeCount,  List<SeasonInfo> seasons)?  $default,) {final _that = this;
switch (_that) {
case _TvShow() when $default != null:
return $default(_that.showTmdbId,_that.showTitle,_that.originalShowTitle,_that.overview,_that.genres,_that.rating,_that.popularity,_that.poster,_that.backdrop,_that.logo,_that.year,_that.totalSeasons,_that.totalEpisodes,_that.availableSeasons,_that.availableEpisodeCount,_that.seasons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TvShow implements TvShow {
  const _TvShow({required this.showTmdbId, required this.showTitle, this.originalShowTitle, this.overview, final  List<String>? genres, this.rating, this.popularity, this.poster, this.backdrop, this.logo, this.year, this.totalSeasons, this.totalEpisodes, required final  List<int> availableSeasons, required this.availableEpisodeCount, required final  List<SeasonInfo> seasons}): _genres = genres,_availableSeasons = availableSeasons,_seasons = seasons;
  factory _TvShow.fromJson(Map<String, dynamic> json) => _$TvShowFromJson(json);

@override final  int showTmdbId;
@override final  String showTitle;
@override final  String? originalShowTitle;
@override final  String? overview;
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
@override final  String? poster;
@override final  String? backdrop;
@override final  String? logo;
@override final  int? year;
@override final  int? totalSeasons;
@override final  int? totalEpisodes;
 final  List<int> _availableSeasons;
@override List<int> get availableSeasons {
  if (_availableSeasons is EqualUnmodifiableListView) return _availableSeasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableSeasons);
}

@override final  int availableEpisodeCount;
 final  List<SeasonInfo> _seasons;
@override List<SeasonInfo> get seasons {
  if (_seasons is EqualUnmodifiableListView) return _seasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_seasons);
}


/// Create a copy of TvShow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TvShowCopyWith<_TvShow> get copyWith => __$TvShowCopyWithImpl<_TvShow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TvShowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TvShow&&(identical(other.showTmdbId, showTmdbId) || other.showTmdbId == showTmdbId)&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.originalShowTitle, originalShowTitle) || other.originalShowTitle == originalShowTitle)&&(identical(other.overview, overview) || other.overview == overview)&&const DeepCollectionEquality().equals(other._genres, _genres)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.popularity, popularity) || other.popularity == popularity)&&(identical(other.poster, poster) || other.poster == poster)&&(identical(other.backdrop, backdrop) || other.backdrop == backdrop)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.year, year) || other.year == year)&&(identical(other.totalSeasons, totalSeasons) || other.totalSeasons == totalSeasons)&&(identical(other.totalEpisodes, totalEpisodes) || other.totalEpisodes == totalEpisodes)&&const DeepCollectionEquality().equals(other._availableSeasons, _availableSeasons)&&(identical(other.availableEpisodeCount, availableEpisodeCount) || other.availableEpisodeCount == availableEpisodeCount)&&const DeepCollectionEquality().equals(other._seasons, _seasons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,showTmdbId,showTitle,originalShowTitle,overview,const DeepCollectionEquality().hash(_genres),rating,popularity,poster,backdrop,logo,year,totalSeasons,totalEpisodes,const DeepCollectionEquality().hash(_availableSeasons),availableEpisodeCount,const DeepCollectionEquality().hash(_seasons));

@override
String toString() {
  return 'TvShow(showTmdbId: $showTmdbId, showTitle: $showTitle, originalShowTitle: $originalShowTitle, overview: $overview, genres: $genres, rating: $rating, popularity: $popularity, poster: $poster, backdrop: $backdrop, logo: $logo, year: $year, totalSeasons: $totalSeasons, totalEpisodes: $totalEpisodes, availableSeasons: $availableSeasons, availableEpisodeCount: $availableEpisodeCount, seasons: $seasons)';
}


}

/// @nodoc
abstract mixin class _$TvShowCopyWith<$Res> implements $TvShowCopyWith<$Res> {
  factory _$TvShowCopyWith(_TvShow value, $Res Function(_TvShow) _then) = __$TvShowCopyWithImpl;
@override @useResult
$Res call({
 int showTmdbId, String showTitle, String? originalShowTitle, String? overview, List<String>? genres, double? rating, double? popularity, String? poster, String? backdrop, String? logo, int? year, int? totalSeasons, int? totalEpisodes, List<int> availableSeasons, int availableEpisodeCount, List<SeasonInfo> seasons
});




}
/// @nodoc
class __$TvShowCopyWithImpl<$Res>
    implements _$TvShowCopyWith<$Res> {
  __$TvShowCopyWithImpl(this._self, this._then);

  final _TvShow _self;
  final $Res Function(_TvShow) _then;

/// Create a copy of TvShow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? showTmdbId = null,Object? showTitle = null,Object? originalShowTitle = freezed,Object? overview = freezed,Object? genres = freezed,Object? rating = freezed,Object? popularity = freezed,Object? poster = freezed,Object? backdrop = freezed,Object? logo = freezed,Object? year = freezed,Object? totalSeasons = freezed,Object? totalEpisodes = freezed,Object? availableSeasons = null,Object? availableEpisodeCount = null,Object? seasons = null,}) {
  return _then(_TvShow(
showTmdbId: null == showTmdbId ? _self.showTmdbId : showTmdbId // ignore: cast_nullable_to_non_nullable
as int,showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String,originalShowTitle: freezed == originalShowTitle ? _self.originalShowTitle : originalShowTitle // ignore: cast_nullable_to_non_nullable
as String?,overview: freezed == overview ? _self.overview : overview // ignore: cast_nullable_to_non_nullable
as String?,genres: freezed == genres ? _self._genres : genres // ignore: cast_nullable_to_non_nullable
as List<String>?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,popularity: freezed == popularity ? _self.popularity : popularity // ignore: cast_nullable_to_non_nullable
as double?,poster: freezed == poster ? _self.poster : poster // ignore: cast_nullable_to_non_nullable
as String?,backdrop: freezed == backdrop ? _self.backdrop : backdrop // ignore: cast_nullable_to_non_nullable
as String?,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,year: freezed == year ? _self.year : year // ignore: cast_nullable_to_non_nullable
as int?,totalSeasons: freezed == totalSeasons ? _self.totalSeasons : totalSeasons // ignore: cast_nullable_to_non_nullable
as int?,totalEpisodes: freezed == totalEpisodes ? _self.totalEpisodes : totalEpisodes // ignore: cast_nullable_to_non_nullable
as int?,availableSeasons: null == availableSeasons ? _self._availableSeasons : availableSeasons // ignore: cast_nullable_to_non_nullable
as List<int>,availableEpisodeCount: null == availableEpisodeCount ? _self.availableEpisodeCount : availableEpisodeCount // ignore: cast_nullable_to_non_nullable
as int,seasons: null == seasons ? _self._seasons : seasons // ignore: cast_nullable_to_non_nullable
as List<SeasonInfo>,
  ));
}


}

// dart format on
