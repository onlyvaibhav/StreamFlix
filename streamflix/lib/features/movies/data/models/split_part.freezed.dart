// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'split_part.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SplitPart {

 String? get fileId; int? get messageId; int? get partNumber; String? get fileName; int? get size; String? get sizeFormatted;@JsonKey(readValue: _readDuration) double? get duration;
/// Create a copy of SplitPart
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitPartCopyWith<SplitPart> get copyWith => _$SplitPartCopyWithImpl<SplitPart>(this as SplitPart, _$identity);

  /// Serializes this SplitPart to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitPart&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.partNumber, partNumber) || other.partNumber == partNumber)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.size, size) || other.size == size)&&(identical(other.sizeFormatted, sizeFormatted) || other.sizeFormatted == sizeFormatted)&&(identical(other.duration, duration) || other.duration == duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileId,messageId,partNumber,fileName,size,sizeFormatted,duration);

@override
String toString() {
  return 'SplitPart(fileId: $fileId, messageId: $messageId, partNumber: $partNumber, fileName: $fileName, size: $size, sizeFormatted: $sizeFormatted, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $SplitPartCopyWith<$Res>  {
  factory $SplitPartCopyWith(SplitPart value, $Res Function(SplitPart) _then) = _$SplitPartCopyWithImpl;
@useResult
$Res call({
 String? fileId, int? messageId, int? partNumber, String? fileName, int? size, String? sizeFormatted,@JsonKey(readValue: _readDuration) double? duration
});




}
/// @nodoc
class _$SplitPartCopyWithImpl<$Res>
    implements $SplitPartCopyWith<$Res> {
  _$SplitPartCopyWithImpl(this._self, this._then);

  final SplitPart _self;
  final $Res Function(SplitPart) _then;

/// Create a copy of SplitPart
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileId = freezed,Object? messageId = freezed,Object? partNumber = freezed,Object? fileName = freezed,Object? size = freezed,Object? sizeFormatted = freezed,Object? duration = freezed,}) {
  return _then(_self.copyWith(
fileId: freezed == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int?,partNumber: freezed == partNumber ? _self.partNumber : partNumber // ignore: cast_nullable_to_non_nullable
as int?,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,sizeFormatted: freezed == sizeFormatted ? _self.sizeFormatted : sizeFormatted // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [SplitPart].
extension SplitPartPatterns on SplitPart {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SplitPart value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SplitPart() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SplitPart value)  $default,){
final _that = this;
switch (_that) {
case _SplitPart():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SplitPart value)?  $default,){
final _that = this;
switch (_that) {
case _SplitPart() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? fileId,  int? messageId,  int? partNumber,  String? fileName,  int? size,  String? sizeFormatted, @JsonKey(readValue: _readDuration)  double? duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SplitPart() when $default != null:
return $default(_that.fileId,_that.messageId,_that.partNumber,_that.fileName,_that.size,_that.sizeFormatted,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? fileId,  int? messageId,  int? partNumber,  String? fileName,  int? size,  String? sizeFormatted, @JsonKey(readValue: _readDuration)  double? duration)  $default,) {final _that = this;
switch (_that) {
case _SplitPart():
return $default(_that.fileId,_that.messageId,_that.partNumber,_that.fileName,_that.size,_that.sizeFormatted,_that.duration);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? fileId,  int? messageId,  int? partNumber,  String? fileName,  int? size,  String? sizeFormatted, @JsonKey(readValue: _readDuration)  double? duration)?  $default,) {final _that = this;
switch (_that) {
case _SplitPart() when $default != null:
return $default(_that.fileId,_that.messageId,_that.partNumber,_that.fileName,_that.size,_that.sizeFormatted,_that.duration);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SplitPart implements SplitPart {
  const _SplitPart({this.fileId, this.messageId, this.partNumber, this.fileName, this.size, this.sizeFormatted, @JsonKey(readValue: _readDuration) this.duration});
  factory _SplitPart.fromJson(Map<String, dynamic> json) => _$SplitPartFromJson(json);

@override final  String? fileId;
@override final  int? messageId;
@override final  int? partNumber;
@override final  String? fileName;
@override final  int? size;
@override final  String? sizeFormatted;
@override@JsonKey(readValue: _readDuration) final  double? duration;

/// Create a copy of SplitPart
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SplitPartCopyWith<_SplitPart> get copyWith => __$SplitPartCopyWithImpl<_SplitPart>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SplitPartToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SplitPart&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.partNumber, partNumber) || other.partNumber == partNumber)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.size, size) || other.size == size)&&(identical(other.sizeFormatted, sizeFormatted) || other.sizeFormatted == sizeFormatted)&&(identical(other.duration, duration) || other.duration == duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileId,messageId,partNumber,fileName,size,sizeFormatted,duration);

@override
String toString() {
  return 'SplitPart(fileId: $fileId, messageId: $messageId, partNumber: $partNumber, fileName: $fileName, size: $size, sizeFormatted: $sizeFormatted, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$SplitPartCopyWith<$Res> implements $SplitPartCopyWith<$Res> {
  factory _$SplitPartCopyWith(_SplitPart value, $Res Function(_SplitPart) _then) = __$SplitPartCopyWithImpl;
@override @useResult
$Res call({
 String? fileId, int? messageId, int? partNumber, String? fileName, int? size, String? sizeFormatted,@JsonKey(readValue: _readDuration) double? duration
});




}
/// @nodoc
class __$SplitPartCopyWithImpl<$Res>
    implements _$SplitPartCopyWith<$Res> {
  __$SplitPartCopyWithImpl(this._self, this._then);

  final _SplitPart _self;
  final $Res Function(_SplitPart) _then;

/// Create a copy of SplitPart
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileId = freezed,Object? messageId = freezed,Object? partNumber = freezed,Object? fileName = freezed,Object? size = freezed,Object? sizeFormatted = freezed,Object? duration = freezed,}) {
  return _then(_SplitPart(
fileId: freezed == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String?,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int?,partNumber: freezed == partNumber ? _self.partNumber : partNumber // ignore: cast_nullable_to_non_nullable
as int?,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,size: freezed == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int?,sizeFormatted: freezed == sizeFormatted ? _self.sizeFormatted : sizeFormatted // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
