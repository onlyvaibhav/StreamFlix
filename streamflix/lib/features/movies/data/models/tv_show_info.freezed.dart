// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tv_show_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TvShowInfo {

 String get showTitle; String? get originalShowTitle; int get seasonNumber; int get episodeNumber; String? get episodeTitle; String? get episodeOverview; int get showTmdbId; int? get episodeRuntime; int? get totalSeasons; int? get totalEpisodes;
/// Create a copy of TvShowInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TvShowInfoCopyWith<TvShowInfo> get copyWith => _$TvShowInfoCopyWithImpl<TvShowInfo>(this as TvShowInfo, _$identity);

  /// Serializes this TvShowInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TvShowInfo&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.originalShowTitle, originalShowTitle) || other.originalShowTitle == originalShowTitle)&&(identical(other.seasonNumber, seasonNumber) || other.seasonNumber == seasonNumber)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.episodeTitle, episodeTitle) || other.episodeTitle == episodeTitle)&&(identical(other.episodeOverview, episodeOverview) || other.episodeOverview == episodeOverview)&&(identical(other.showTmdbId, showTmdbId) || other.showTmdbId == showTmdbId)&&(identical(other.episodeRuntime, episodeRuntime) || other.episodeRuntime == episodeRuntime)&&(identical(other.totalSeasons, totalSeasons) || other.totalSeasons == totalSeasons)&&(identical(other.totalEpisodes, totalEpisodes) || other.totalEpisodes == totalEpisodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,showTitle,originalShowTitle,seasonNumber,episodeNumber,episodeTitle,episodeOverview,showTmdbId,episodeRuntime,totalSeasons,totalEpisodes);

@override
String toString() {
  return 'TvShowInfo(showTitle: $showTitle, originalShowTitle: $originalShowTitle, seasonNumber: $seasonNumber, episodeNumber: $episodeNumber, episodeTitle: $episodeTitle, episodeOverview: $episodeOverview, showTmdbId: $showTmdbId, episodeRuntime: $episodeRuntime, totalSeasons: $totalSeasons, totalEpisodes: $totalEpisodes)';
}


}

/// @nodoc
abstract mixin class $TvShowInfoCopyWith<$Res>  {
  factory $TvShowInfoCopyWith(TvShowInfo value, $Res Function(TvShowInfo) _then) = _$TvShowInfoCopyWithImpl;
@useResult
$Res call({
 String showTitle, String? originalShowTitle, int seasonNumber, int episodeNumber, String? episodeTitle, String? episodeOverview, int showTmdbId, int? episodeRuntime, int? totalSeasons, int? totalEpisodes
});




}
/// @nodoc
class _$TvShowInfoCopyWithImpl<$Res>
    implements $TvShowInfoCopyWith<$Res> {
  _$TvShowInfoCopyWithImpl(this._self, this._then);

  final TvShowInfo _self;
  final $Res Function(TvShowInfo) _then;

/// Create a copy of TvShowInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? showTitle = null,Object? originalShowTitle = freezed,Object? seasonNumber = null,Object? episodeNumber = null,Object? episodeTitle = freezed,Object? episodeOverview = freezed,Object? showTmdbId = null,Object? episodeRuntime = freezed,Object? totalSeasons = freezed,Object? totalEpisodes = freezed,}) {
  return _then(_self.copyWith(
showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String,originalShowTitle: freezed == originalShowTitle ? _self.originalShowTitle : originalShowTitle // ignore: cast_nullable_to_non_nullable
as String?,seasonNumber: null == seasonNumber ? _self.seasonNumber : seasonNumber // ignore: cast_nullable_to_non_nullable
as int,episodeNumber: null == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int,episodeTitle: freezed == episodeTitle ? _self.episodeTitle : episodeTitle // ignore: cast_nullable_to_non_nullable
as String?,episodeOverview: freezed == episodeOverview ? _self.episodeOverview : episodeOverview // ignore: cast_nullable_to_non_nullable
as String?,showTmdbId: null == showTmdbId ? _self.showTmdbId : showTmdbId // ignore: cast_nullable_to_non_nullable
as int,episodeRuntime: freezed == episodeRuntime ? _self.episodeRuntime : episodeRuntime // ignore: cast_nullable_to_non_nullable
as int?,totalSeasons: freezed == totalSeasons ? _self.totalSeasons : totalSeasons // ignore: cast_nullable_to_non_nullable
as int?,totalEpisodes: freezed == totalEpisodes ? _self.totalEpisodes : totalEpisodes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TvShowInfo].
extension TvShowInfoPatterns on TvShowInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TvShowInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TvShowInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TvShowInfo value)  $default,){
final _that = this;
switch (_that) {
case _TvShowInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TvShowInfo value)?  $default,){
final _that = this;
switch (_that) {
case _TvShowInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String showTitle,  String? originalShowTitle,  int seasonNumber,  int episodeNumber,  String? episodeTitle,  String? episodeOverview,  int showTmdbId,  int? episodeRuntime,  int? totalSeasons,  int? totalEpisodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TvShowInfo() when $default != null:
return $default(_that.showTitle,_that.originalShowTitle,_that.seasonNumber,_that.episodeNumber,_that.episodeTitle,_that.episodeOverview,_that.showTmdbId,_that.episodeRuntime,_that.totalSeasons,_that.totalEpisodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String showTitle,  String? originalShowTitle,  int seasonNumber,  int episodeNumber,  String? episodeTitle,  String? episodeOverview,  int showTmdbId,  int? episodeRuntime,  int? totalSeasons,  int? totalEpisodes)  $default,) {final _that = this;
switch (_that) {
case _TvShowInfo():
return $default(_that.showTitle,_that.originalShowTitle,_that.seasonNumber,_that.episodeNumber,_that.episodeTitle,_that.episodeOverview,_that.showTmdbId,_that.episodeRuntime,_that.totalSeasons,_that.totalEpisodes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String showTitle,  String? originalShowTitle,  int seasonNumber,  int episodeNumber,  String? episodeTitle,  String? episodeOverview,  int showTmdbId,  int? episodeRuntime,  int? totalSeasons,  int? totalEpisodes)?  $default,) {final _that = this;
switch (_that) {
case _TvShowInfo() when $default != null:
return $default(_that.showTitle,_that.originalShowTitle,_that.seasonNumber,_that.episodeNumber,_that.episodeTitle,_that.episodeOverview,_that.showTmdbId,_that.episodeRuntime,_that.totalSeasons,_that.totalEpisodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TvShowInfo implements TvShowInfo {
  const _TvShowInfo({required this.showTitle, this.originalShowTitle, required this.seasonNumber, required this.episodeNumber, this.episodeTitle, this.episodeOverview, required this.showTmdbId, this.episodeRuntime, this.totalSeasons, this.totalEpisodes});
  factory _TvShowInfo.fromJson(Map<String, dynamic> json) => _$TvShowInfoFromJson(json);

@override final  String showTitle;
@override final  String? originalShowTitle;
@override final  int seasonNumber;
@override final  int episodeNumber;
@override final  String? episodeTitle;
@override final  String? episodeOverview;
@override final  int showTmdbId;
@override final  int? episodeRuntime;
@override final  int? totalSeasons;
@override final  int? totalEpisodes;

/// Create a copy of TvShowInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TvShowInfoCopyWith<_TvShowInfo> get copyWith => __$TvShowInfoCopyWithImpl<_TvShowInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TvShowInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TvShowInfo&&(identical(other.showTitle, showTitle) || other.showTitle == showTitle)&&(identical(other.originalShowTitle, originalShowTitle) || other.originalShowTitle == originalShowTitle)&&(identical(other.seasonNumber, seasonNumber) || other.seasonNumber == seasonNumber)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber)&&(identical(other.episodeTitle, episodeTitle) || other.episodeTitle == episodeTitle)&&(identical(other.episodeOverview, episodeOverview) || other.episodeOverview == episodeOverview)&&(identical(other.showTmdbId, showTmdbId) || other.showTmdbId == showTmdbId)&&(identical(other.episodeRuntime, episodeRuntime) || other.episodeRuntime == episodeRuntime)&&(identical(other.totalSeasons, totalSeasons) || other.totalSeasons == totalSeasons)&&(identical(other.totalEpisodes, totalEpisodes) || other.totalEpisodes == totalEpisodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,showTitle,originalShowTitle,seasonNumber,episodeNumber,episodeTitle,episodeOverview,showTmdbId,episodeRuntime,totalSeasons,totalEpisodes);

@override
String toString() {
  return 'TvShowInfo(showTitle: $showTitle, originalShowTitle: $originalShowTitle, seasonNumber: $seasonNumber, episodeNumber: $episodeNumber, episodeTitle: $episodeTitle, episodeOverview: $episodeOverview, showTmdbId: $showTmdbId, episodeRuntime: $episodeRuntime, totalSeasons: $totalSeasons, totalEpisodes: $totalEpisodes)';
}


}

/// @nodoc
abstract mixin class _$TvShowInfoCopyWith<$Res> implements $TvShowInfoCopyWith<$Res> {
  factory _$TvShowInfoCopyWith(_TvShowInfo value, $Res Function(_TvShowInfo) _then) = __$TvShowInfoCopyWithImpl;
@override @useResult
$Res call({
 String showTitle, String? originalShowTitle, int seasonNumber, int episodeNumber, String? episodeTitle, String? episodeOverview, int showTmdbId, int? episodeRuntime, int? totalSeasons, int? totalEpisodes
});




}
/// @nodoc
class __$TvShowInfoCopyWithImpl<$Res>
    implements _$TvShowInfoCopyWith<$Res> {
  __$TvShowInfoCopyWithImpl(this._self, this._then);

  final _TvShowInfo _self;
  final $Res Function(_TvShowInfo) _then;

/// Create a copy of TvShowInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? showTitle = null,Object? originalShowTitle = freezed,Object? seasonNumber = null,Object? episodeNumber = null,Object? episodeTitle = freezed,Object? episodeOverview = freezed,Object? showTmdbId = null,Object? episodeRuntime = freezed,Object? totalSeasons = freezed,Object? totalEpisodes = freezed,}) {
  return _then(_TvShowInfo(
showTitle: null == showTitle ? _self.showTitle : showTitle // ignore: cast_nullable_to_non_nullable
as String,originalShowTitle: freezed == originalShowTitle ? _self.originalShowTitle : originalShowTitle // ignore: cast_nullable_to_non_nullable
as String?,seasonNumber: null == seasonNumber ? _self.seasonNumber : seasonNumber // ignore: cast_nullable_to_non_nullable
as int,episodeNumber: null == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int,episodeTitle: freezed == episodeTitle ? _self.episodeTitle : episodeTitle // ignore: cast_nullable_to_non_nullable
as String?,episodeOverview: freezed == episodeOverview ? _self.episodeOverview : episodeOverview // ignore: cast_nullable_to_non_nullable
as String?,showTmdbId: null == showTmdbId ? _self.showTmdbId : showTmdbId // ignore: cast_nullable_to_non_nullable
as int,episodeRuntime: freezed == episodeRuntime ? _self.episodeRuntime : episodeRuntime // ignore: cast_nullable_to_non_nullable
as int?,totalSeasons: freezed == totalSeasons ? _self.totalSeasons : totalSeasons // ignore: cast_nullable_to_non_nullable
as int?,totalEpisodes: freezed == totalEpisodes ? _self.totalEpisodes : totalEpisodes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
