// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'season_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SeasonInfo {

 int get seasonNumber; List<Movie> get episodes;
/// Create a copy of SeasonInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeasonInfoCopyWith<SeasonInfo> get copyWith => _$SeasonInfoCopyWithImpl<SeasonInfo>(this as SeasonInfo, _$identity);

  /// Serializes this SeasonInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeasonInfo&&(identical(other.seasonNumber, seasonNumber) || other.seasonNumber == seasonNumber)&&const DeepCollectionEquality().equals(other.episodes, episodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seasonNumber,const DeepCollectionEquality().hash(episodes));

@override
String toString() {
  return 'SeasonInfo(seasonNumber: $seasonNumber, episodes: $episodes)';
}


}

/// @nodoc
abstract mixin class $SeasonInfoCopyWith<$Res>  {
  factory $SeasonInfoCopyWith(SeasonInfo value, $Res Function(SeasonInfo) _then) = _$SeasonInfoCopyWithImpl;
@useResult
$Res call({
 int seasonNumber, List<Movie> episodes
});




}
/// @nodoc
class _$SeasonInfoCopyWithImpl<$Res>
    implements $SeasonInfoCopyWith<$Res> {
  _$SeasonInfoCopyWithImpl(this._self, this._then);

  final SeasonInfo _self;
  final $Res Function(SeasonInfo) _then;

/// Create a copy of SeasonInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seasonNumber = null,Object? episodes = null,}) {
  return _then(_self.copyWith(
seasonNumber: null == seasonNumber ? _self.seasonNumber : seasonNumber // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as List<Movie>,
  ));
}

}


/// Adds pattern-matching-related methods to [SeasonInfo].
extension SeasonInfoPatterns on SeasonInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SeasonInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SeasonInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SeasonInfo value)  $default,){
final _that = this;
switch (_that) {
case _SeasonInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SeasonInfo value)?  $default,){
final _that = this;
switch (_that) {
case _SeasonInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int seasonNumber,  List<Movie> episodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SeasonInfo() when $default != null:
return $default(_that.seasonNumber,_that.episodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int seasonNumber,  List<Movie> episodes)  $default,) {final _that = this;
switch (_that) {
case _SeasonInfo():
return $default(_that.seasonNumber,_that.episodes);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int seasonNumber,  List<Movie> episodes)?  $default,) {final _that = this;
switch (_that) {
case _SeasonInfo() when $default != null:
return $default(_that.seasonNumber,_that.episodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SeasonInfo implements SeasonInfo {
  const _SeasonInfo({required this.seasonNumber, required final  List<Movie> episodes}): _episodes = episodes;
  factory _SeasonInfo.fromJson(Map<String, dynamic> json) => _$SeasonInfoFromJson(json);

@override final  int seasonNumber;
 final  List<Movie> _episodes;
@override List<Movie> get episodes {
  if (_episodes is EqualUnmodifiableListView) return _episodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_episodes);
}


/// Create a copy of SeasonInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeasonInfoCopyWith<_SeasonInfo> get copyWith => __$SeasonInfoCopyWithImpl<_SeasonInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SeasonInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SeasonInfo&&(identical(other.seasonNumber, seasonNumber) || other.seasonNumber == seasonNumber)&&const DeepCollectionEquality().equals(other._episodes, _episodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,seasonNumber,const DeepCollectionEquality().hash(_episodes));

@override
String toString() {
  return 'SeasonInfo(seasonNumber: $seasonNumber, episodes: $episodes)';
}


}

/// @nodoc
abstract mixin class _$SeasonInfoCopyWith<$Res> implements $SeasonInfoCopyWith<$Res> {
  factory _$SeasonInfoCopyWith(_SeasonInfo value, $Res Function(_SeasonInfo) _then) = __$SeasonInfoCopyWithImpl;
@override @useResult
$Res call({
 int seasonNumber, List<Movie> episodes
});




}
/// @nodoc
class __$SeasonInfoCopyWithImpl<$Res>
    implements _$SeasonInfoCopyWith<$Res> {
  __$SeasonInfoCopyWithImpl(this._self, this._then);

  final _SeasonInfo _self;
  final $Res Function(_SeasonInfo) _then;

/// Create a copy of SeasonInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seasonNumber = null,Object? episodes = null,}) {
  return _then(_SeasonInfo(
seasonNumber: null == seasonNumber ? _self.seasonNumber : seasonNumber // ignore: cast_nullable_to_non_nullable
as int,episodes: null == episodes ? _self._episodes : episodes // ignore: cast_nullable_to_non_nullable
as List<Movie>,
  ));
}


}

// dart format on
