// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'movie_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MovieListResponse {

 bool get success; int get count; int get nextOffset; List<Movie> get movies;
/// Create a copy of MovieListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MovieListResponseCopyWith<MovieListResponse> get copyWith => _$MovieListResponseCopyWithImpl<MovieListResponse>(this as MovieListResponse, _$identity);

  /// Serializes this MovieListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MovieListResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.count, count) || other.count == count)&&(identical(other.nextOffset, nextOffset) || other.nextOffset == nextOffset)&&const DeepCollectionEquality().equals(other.movies, movies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,count,nextOffset,const DeepCollectionEquality().hash(movies));

@override
String toString() {
  return 'MovieListResponse(success: $success, count: $count, nextOffset: $nextOffset, movies: $movies)';
}


}

/// @nodoc
abstract mixin class $MovieListResponseCopyWith<$Res>  {
  factory $MovieListResponseCopyWith(MovieListResponse value, $Res Function(MovieListResponse) _then) = _$MovieListResponseCopyWithImpl;
@useResult
$Res call({
 bool success, int count, int nextOffset, List<Movie> movies
});




}
/// @nodoc
class _$MovieListResponseCopyWithImpl<$Res>
    implements $MovieListResponseCopyWith<$Res> {
  _$MovieListResponseCopyWithImpl(this._self, this._then);

  final MovieListResponse _self;
  final $Res Function(MovieListResponse) _then;

/// Create a copy of MovieListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? count = null,Object? nextOffset = null,Object? movies = null,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,nextOffset: null == nextOffset ? _self.nextOffset : nextOffset // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self.movies : movies // ignore: cast_nullable_to_non_nullable
as List<Movie>,
  ));
}

}


/// Adds pattern-matching-related methods to [MovieListResponse].
extension MovieListResponsePatterns on MovieListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MovieListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MovieListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MovieListResponse value)  $default,){
final _that = this;
switch (_that) {
case _MovieListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MovieListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _MovieListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  int count,  int nextOffset,  List<Movie> movies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MovieListResponse() when $default != null:
return $default(_that.success,_that.count,_that.nextOffset,_that.movies);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  int count,  int nextOffset,  List<Movie> movies)  $default,) {final _that = this;
switch (_that) {
case _MovieListResponse():
return $default(_that.success,_that.count,_that.nextOffset,_that.movies);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  int count,  int nextOffset,  List<Movie> movies)?  $default,) {final _that = this;
switch (_that) {
case _MovieListResponse() when $default != null:
return $default(_that.success,_that.count,_that.nextOffset,_that.movies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MovieListResponse implements MovieListResponse {
  const _MovieListResponse({required this.success, required this.count, required this.nextOffset, required final  List<Movie> movies}): _movies = movies;
  factory _MovieListResponse.fromJson(Map<String, dynamic> json) => _$MovieListResponseFromJson(json);

@override final  bool success;
@override final  int count;
@override final  int nextOffset;
 final  List<Movie> _movies;
@override List<Movie> get movies {
  if (_movies is EqualUnmodifiableListView) return _movies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_movies);
}


/// Create a copy of MovieListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MovieListResponseCopyWith<_MovieListResponse> get copyWith => __$MovieListResponseCopyWithImpl<_MovieListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MovieListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MovieListResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.count, count) || other.count == count)&&(identical(other.nextOffset, nextOffset) || other.nextOffset == nextOffset)&&const DeepCollectionEquality().equals(other._movies, _movies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,count,nextOffset,const DeepCollectionEquality().hash(_movies));

@override
String toString() {
  return 'MovieListResponse(success: $success, count: $count, nextOffset: $nextOffset, movies: $movies)';
}


}

/// @nodoc
abstract mixin class _$MovieListResponseCopyWith<$Res> implements $MovieListResponseCopyWith<$Res> {
  factory _$MovieListResponseCopyWith(_MovieListResponse value, $Res Function(_MovieListResponse) _then) = __$MovieListResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, int count, int nextOffset, List<Movie> movies
});




}
/// @nodoc
class __$MovieListResponseCopyWithImpl<$Res>
    implements _$MovieListResponseCopyWith<$Res> {
  __$MovieListResponseCopyWithImpl(this._self, this._then);

  final _MovieListResponse _self;
  final $Res Function(_MovieListResponse) _then;

/// Create a copy of MovieListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? count = null,Object? nextOffset = null,Object? movies = null,}) {
  return _then(_MovieListResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,nextOffset: null == nextOffset ? _self.nextOffset : nextOffset // ignore: cast_nullable_to_non_nullable
as int,movies: null == movies ? _self._movies : movies // ignore: cast_nullable_to_non_nullable
as List<Movie>,
  ));
}


}

// dart format on
