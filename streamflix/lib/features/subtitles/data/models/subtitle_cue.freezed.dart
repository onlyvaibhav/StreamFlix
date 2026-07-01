// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subtitle_cue.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SubtitleCue {

 int get index; Duration get start; Duration get end; String get text;
/// Create a copy of SubtitleCue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubtitleCueCopyWith<SubtitleCue> get copyWith => _$SubtitleCueCopyWithImpl<SubtitleCue>(this as SubtitleCue, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubtitleCue&&(identical(other.index, index) || other.index == index)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,index,start,end,text);

@override
String toString() {
  return 'SubtitleCue(index: $index, start: $start, end: $end, text: $text)';
}


}

/// @nodoc
abstract mixin class $SubtitleCueCopyWith<$Res>  {
  factory $SubtitleCueCopyWith(SubtitleCue value, $Res Function(SubtitleCue) _then) = _$SubtitleCueCopyWithImpl;
@useResult
$Res call({
 int index, Duration start, Duration end, String text
});




}
/// @nodoc
class _$SubtitleCueCopyWithImpl<$Res>
    implements $SubtitleCueCopyWith<$Res> {
  _$SubtitleCueCopyWithImpl(this._self, this._then);

  final SubtitleCue _self;
  final $Res Function(SubtitleCue) _then;

/// Create a copy of SubtitleCue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? start = null,Object? end = null,Object? text = null,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SubtitleCue].
extension SubtitleCuePatterns on SubtitleCue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubtitleCue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubtitleCue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubtitleCue value)  $default,){
final _that = this;
switch (_that) {
case _SubtitleCue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubtitleCue value)?  $default,){
final _that = this;
switch (_that) {
case _SubtitleCue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  Duration start,  Duration end,  String text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubtitleCue() when $default != null:
return $default(_that.index,_that.start,_that.end,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  Duration start,  Duration end,  String text)  $default,) {final _that = this;
switch (_that) {
case _SubtitleCue():
return $default(_that.index,_that.start,_that.end,_that.text);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  Duration start,  Duration end,  String text)?  $default,) {final _that = this;
switch (_that) {
case _SubtitleCue() when $default != null:
return $default(_that.index,_that.start,_that.end,_that.text);case _:
  return null;

}
}

}

/// @nodoc


class _SubtitleCue implements SubtitleCue {
  const _SubtitleCue({required this.index, required this.start, required this.end, required this.text});
  

@override final  int index;
@override final  Duration start;
@override final  Duration end;
@override final  String text;

/// Create a copy of SubtitleCue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubtitleCueCopyWith<_SubtitleCue> get copyWith => __$SubtitleCueCopyWithImpl<_SubtitleCue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubtitleCue&&(identical(other.index, index) || other.index == index)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,index,start,end,text);

@override
String toString() {
  return 'SubtitleCue(index: $index, start: $start, end: $end, text: $text)';
}


}

/// @nodoc
abstract mixin class _$SubtitleCueCopyWith<$Res> implements $SubtitleCueCopyWith<$Res> {
  factory _$SubtitleCueCopyWith(_SubtitleCue value, $Res Function(_SubtitleCue) _then) = __$SubtitleCueCopyWithImpl;
@override @useResult
$Res call({
 int index, Duration start, Duration end, String text
});




}
/// @nodoc
class __$SubtitleCueCopyWithImpl<$Res>
    implements _$SubtitleCueCopyWith<$Res> {
  __$SubtitleCueCopyWithImpl(this._self, this._then);

  final _SubtitleCue _self;
  final $Res Function(_SubtitleCue) _then;

/// Create a copy of SubtitleCue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? start = null,Object? end = null,Object? text = null,}) {
  return _then(_SubtitleCue(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as Duration,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
