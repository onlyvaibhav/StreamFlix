// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'external_subtitle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExternalSubtitle {

 String get id; String? get label; String? get language; String? get rating; String get source; String? get endpoint; String? get localPath;
/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExternalSubtitleCopyWith<ExternalSubtitle> get copyWith => _$ExternalSubtitleCopyWithImpl<ExternalSubtitle>(this as ExternalSubtitle, _$identity);

  /// Serializes this ExternalSubtitle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExternalSubtitle&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.language, language) || other.language == language)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.source, source) || other.source == source)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.localPath, localPath) || other.localPath == localPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,language,rating,source,endpoint,localPath);

@override
String toString() {
  return 'ExternalSubtitle(id: $id, label: $label, language: $language, rating: $rating, source: $source, endpoint: $endpoint, localPath: $localPath)';
}


}

/// @nodoc
abstract mixin class $ExternalSubtitleCopyWith<$Res>  {
  factory $ExternalSubtitleCopyWith(ExternalSubtitle value, $Res Function(ExternalSubtitle) _then) = _$ExternalSubtitleCopyWithImpl;
@useResult
$Res call({
 String id, String? label, String? language, String? rating, String source, String? endpoint, String? localPath
});




}
/// @nodoc
class _$ExternalSubtitleCopyWithImpl<$Res>
    implements $ExternalSubtitleCopyWith<$Res> {
  _$ExternalSubtitleCopyWithImpl(this._self, this._then);

  final ExternalSubtitle _self;
  final $Res Function(ExternalSubtitle) _then;

/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = freezed,Object? language = freezed,Object? rating = freezed,Object? source = null,Object? endpoint = freezed,Object? localPath = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,endpoint: freezed == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExternalSubtitle].
extension ExternalSubtitlePatterns on ExternalSubtitle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExternalSubtitle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExternalSubtitle value)  $default,){
final _that = this;
switch (_that) {
case _ExternalSubtitle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExternalSubtitle value)?  $default,){
final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? label,  String? language,  String? rating,  String source,  String? endpoint,  String? localPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
return $default(_that.id,_that.label,_that.language,_that.rating,_that.source,_that.endpoint,_that.localPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? label,  String? language,  String? rating,  String source,  String? endpoint,  String? localPath)  $default,) {final _that = this;
switch (_that) {
case _ExternalSubtitle():
return $default(_that.id,_that.label,_that.language,_that.rating,_that.source,_that.endpoint,_that.localPath);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? label,  String? language,  String? rating,  String source,  String? endpoint,  String? localPath)?  $default,) {final _that = this;
switch (_that) {
case _ExternalSubtitle() when $default != null:
return $default(_that.id,_that.label,_that.language,_that.rating,_that.source,_that.endpoint,_that.localPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExternalSubtitle implements ExternalSubtitle {
  const _ExternalSubtitle({required this.id, this.label, this.language, this.rating, this.source = 'SubDL', this.endpoint, this.localPath});
  factory _ExternalSubtitle.fromJson(Map<String, dynamic> json) => _$ExternalSubtitleFromJson(json);

@override final  String id;
@override final  String? label;
@override final  String? language;
@override final  String? rating;
@override@JsonKey() final  String source;
@override final  String? endpoint;
@override final  String? localPath;

/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExternalSubtitleCopyWith<_ExternalSubtitle> get copyWith => __$ExternalSubtitleCopyWithImpl<_ExternalSubtitle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExternalSubtitleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExternalSubtitle&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.language, language) || other.language == language)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.source, source) || other.source == source)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.localPath, localPath) || other.localPath == localPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,language,rating,source,endpoint,localPath);

@override
String toString() {
  return 'ExternalSubtitle(id: $id, label: $label, language: $language, rating: $rating, source: $source, endpoint: $endpoint, localPath: $localPath)';
}


}

/// @nodoc
abstract mixin class _$ExternalSubtitleCopyWith<$Res> implements $ExternalSubtitleCopyWith<$Res> {
  factory _$ExternalSubtitleCopyWith(_ExternalSubtitle value, $Res Function(_ExternalSubtitle) _then) = __$ExternalSubtitleCopyWithImpl;
@override @useResult
$Res call({
 String id, String? label, String? language, String? rating, String source, String? endpoint, String? localPath
});




}
/// @nodoc
class __$ExternalSubtitleCopyWithImpl<$Res>
    implements _$ExternalSubtitleCopyWith<$Res> {
  __$ExternalSubtitleCopyWithImpl(this._self, this._then);

  final _ExternalSubtitle _self;
  final $Res Function(_ExternalSubtitle) _then;

/// Create a copy of ExternalSubtitle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = freezed,Object? language = freezed,Object? rating = freezed,Object? source = null,Object? endpoint = freezed,Object? localPath = freezed,}) {
  return _then(_ExternalSubtitle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,endpoint: freezed == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
