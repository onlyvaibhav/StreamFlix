// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stream_track.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioTrack {

 int get index; int get streamIndex; String get codec; String get language; String get languageCode; String get title; int get channels; String get channelLayout; bool get browserPlayable; bool get isDefault;
/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioTrackCopyWith<AudioTrack> get copyWith => _$AudioTrackCopyWithImpl<AudioTrack>(this as AudioTrack, _$identity);

  /// Serializes this AudioTrack to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioTrack&&(identical(other.index, index) || other.index == index)&&(identical(other.streamIndex, streamIndex) || other.streamIndex == streamIndex)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.language, language) || other.language == language)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.channelLayout, channelLayout) || other.channelLayout == channelLayout)&&(identical(other.browserPlayable, browserPlayable) || other.browserPlayable == browserPlayable)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,streamIndex,codec,language,languageCode,title,channels,channelLayout,browserPlayable,isDefault);

@override
String toString() {
  return 'AudioTrack(index: $index, streamIndex: $streamIndex, codec: $codec, language: $language, languageCode: $languageCode, title: $title, channels: $channels, channelLayout: $channelLayout, browserPlayable: $browserPlayable, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class $AudioTrackCopyWith<$Res>  {
  factory $AudioTrackCopyWith(AudioTrack value, $Res Function(AudioTrack) _then) = _$AudioTrackCopyWithImpl;
@useResult
$Res call({
 int index, int streamIndex, String codec, String language, String languageCode, String title, int channels, String channelLayout, bool browserPlayable, bool isDefault
});




}
/// @nodoc
class _$AudioTrackCopyWithImpl<$Res>
    implements $AudioTrackCopyWith<$Res> {
  _$AudioTrackCopyWithImpl(this._self, this._then);

  final AudioTrack _self;
  final $Res Function(AudioTrack) _then;

/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? streamIndex = null,Object? codec = null,Object? language = null,Object? languageCode = null,Object? title = null,Object? channels = null,Object? channelLayout = null,Object? browserPlayable = null,Object? isDefault = null,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,streamIndex: null == streamIndex ? _self.streamIndex : streamIndex // ignore: cast_nullable_to_non_nullable
as int,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,languageCode: null == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,channelLayout: null == channelLayout ? _self.channelLayout : channelLayout // ignore: cast_nullable_to_non_nullable
as String,browserPlayable: null == browserPlayable ? _self.browserPlayable : browserPlayable // ignore: cast_nullable_to_non_nullable
as bool,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioTrack].
extension AudioTrackPatterns on AudioTrack {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioTrack value)  $default,){
final _that = this;
switch (_that) {
case _AudioTrack():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioTrack value)?  $default,){
final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  int streamIndex,  String codec,  String language,  String languageCode,  String title,  int channels,  String channelLayout,  bool browserPlayable,  bool isDefault)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
return $default(_that.index,_that.streamIndex,_that.codec,_that.language,_that.languageCode,_that.title,_that.channels,_that.channelLayout,_that.browserPlayable,_that.isDefault);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  int streamIndex,  String codec,  String language,  String languageCode,  String title,  int channels,  String channelLayout,  bool browserPlayable,  bool isDefault)  $default,) {final _that = this;
switch (_that) {
case _AudioTrack():
return $default(_that.index,_that.streamIndex,_that.codec,_that.language,_that.languageCode,_that.title,_that.channels,_that.channelLayout,_that.browserPlayable,_that.isDefault);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  int streamIndex,  String codec,  String language,  String languageCode,  String title,  int channels,  String channelLayout,  bool browserPlayable,  bool isDefault)?  $default,) {final _that = this;
switch (_that) {
case _AudioTrack() when $default != null:
return $default(_that.index,_that.streamIndex,_that.codec,_that.language,_that.languageCode,_that.title,_that.channels,_that.channelLayout,_that.browserPlayable,_that.isDefault);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioTrack implements AudioTrack {
  const _AudioTrack({required this.index, required this.streamIndex, this.codec = 'unknown', this.language = 'Unknown', this.languageCode = 'und', this.title = '', this.channels = 0, this.channelLayout = '', this.browserPlayable = true, this.isDefault = false});
  factory _AudioTrack.fromJson(Map<String, dynamic> json) => _$AudioTrackFromJson(json);

@override final  int index;
@override final  int streamIndex;
@override@JsonKey() final  String codec;
@override@JsonKey() final  String language;
@override@JsonKey() final  String languageCode;
@override@JsonKey() final  String title;
@override@JsonKey() final  int channels;
@override@JsonKey() final  String channelLayout;
@override@JsonKey() final  bool browserPlayable;
@override@JsonKey() final  bool isDefault;

/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioTrackCopyWith<_AudioTrack> get copyWith => __$AudioTrackCopyWithImpl<_AudioTrack>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioTrackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioTrack&&(identical(other.index, index) || other.index == index)&&(identical(other.streamIndex, streamIndex) || other.streamIndex == streamIndex)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.language, language) || other.language == language)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.channelLayout, channelLayout) || other.channelLayout == channelLayout)&&(identical(other.browserPlayable, browserPlayable) || other.browserPlayable == browserPlayable)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,streamIndex,codec,language,languageCode,title,channels,channelLayout,browserPlayable,isDefault);

@override
String toString() {
  return 'AudioTrack(index: $index, streamIndex: $streamIndex, codec: $codec, language: $language, languageCode: $languageCode, title: $title, channels: $channels, channelLayout: $channelLayout, browserPlayable: $browserPlayable, isDefault: $isDefault)';
}


}

/// @nodoc
abstract mixin class _$AudioTrackCopyWith<$Res> implements $AudioTrackCopyWith<$Res> {
  factory _$AudioTrackCopyWith(_AudioTrack value, $Res Function(_AudioTrack) _then) = __$AudioTrackCopyWithImpl;
@override @useResult
$Res call({
 int index, int streamIndex, String codec, String language, String languageCode, String title, int channels, String channelLayout, bool browserPlayable, bool isDefault
});




}
/// @nodoc
class __$AudioTrackCopyWithImpl<$Res>
    implements _$AudioTrackCopyWith<$Res> {
  __$AudioTrackCopyWithImpl(this._self, this._then);

  final _AudioTrack _self;
  final $Res Function(_AudioTrack) _then;

/// Create a copy of AudioTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? streamIndex = null,Object? codec = null,Object? language = null,Object? languageCode = null,Object? title = null,Object? channels = null,Object? channelLayout = null,Object? browserPlayable = null,Object? isDefault = null,}) {
  return _then(_AudioTrack(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,streamIndex: null == streamIndex ? _self.streamIndex : streamIndex // ignore: cast_nullable_to_non_nullable
as int,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,languageCode: null == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,channelLayout: null == channelLayout ? _self.channelLayout : channelLayout // ignore: cast_nullable_to_non_nullable
as String,browserPlayable: null == browserPlayable ? _self.browserPlayable : browserPlayable // ignore: cast_nullable_to_non_nullable
as bool,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SubtitleTrack {

 int get index; int get streamIndex; String get codec; String get language; String get languageCode; String get title; bool get isTextBased; bool get isImageBased; bool get extractable; bool get isDefault; bool get isForced;
/// Create a copy of SubtitleTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubtitleTrackCopyWith<SubtitleTrack> get copyWith => _$SubtitleTrackCopyWithImpl<SubtitleTrack>(this as SubtitleTrack, _$identity);

  /// Serializes this SubtitleTrack to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubtitleTrack&&(identical(other.index, index) || other.index == index)&&(identical(other.streamIndex, streamIndex) || other.streamIndex == streamIndex)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.language, language) || other.language == language)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.isTextBased, isTextBased) || other.isTextBased == isTextBased)&&(identical(other.isImageBased, isImageBased) || other.isImageBased == isImageBased)&&(identical(other.extractable, extractable) || other.extractable == extractable)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.isForced, isForced) || other.isForced == isForced));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,streamIndex,codec,language,languageCode,title,isTextBased,isImageBased,extractable,isDefault,isForced);

@override
String toString() {
  return 'SubtitleTrack(index: $index, streamIndex: $streamIndex, codec: $codec, language: $language, languageCode: $languageCode, title: $title, isTextBased: $isTextBased, isImageBased: $isImageBased, extractable: $extractable, isDefault: $isDefault, isForced: $isForced)';
}


}

/// @nodoc
abstract mixin class $SubtitleTrackCopyWith<$Res>  {
  factory $SubtitleTrackCopyWith(SubtitleTrack value, $Res Function(SubtitleTrack) _then) = _$SubtitleTrackCopyWithImpl;
@useResult
$Res call({
 int index, int streamIndex, String codec, String language, String languageCode, String title, bool isTextBased, bool isImageBased, bool extractable, bool isDefault, bool isForced
});




}
/// @nodoc
class _$SubtitleTrackCopyWithImpl<$Res>
    implements $SubtitleTrackCopyWith<$Res> {
  _$SubtitleTrackCopyWithImpl(this._self, this._then);

  final SubtitleTrack _self;
  final $Res Function(SubtitleTrack) _then;

/// Create a copy of SubtitleTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? index = null,Object? streamIndex = null,Object? codec = null,Object? language = null,Object? languageCode = null,Object? title = null,Object? isTextBased = null,Object? isImageBased = null,Object? extractable = null,Object? isDefault = null,Object? isForced = null,}) {
  return _then(_self.copyWith(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,streamIndex: null == streamIndex ? _self.streamIndex : streamIndex // ignore: cast_nullable_to_non_nullable
as int,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,languageCode: null == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isTextBased: null == isTextBased ? _self.isTextBased : isTextBased // ignore: cast_nullable_to_non_nullable
as bool,isImageBased: null == isImageBased ? _self.isImageBased : isImageBased // ignore: cast_nullable_to_non_nullable
as bool,extractable: null == extractable ? _self.extractable : extractable // ignore: cast_nullable_to_non_nullable
as bool,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,isForced: null == isForced ? _self.isForced : isForced // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SubtitleTrack].
extension SubtitleTrackPatterns on SubtitleTrack {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubtitleTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubtitleTrack() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubtitleTrack value)  $default,){
final _that = this;
switch (_that) {
case _SubtitleTrack():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubtitleTrack value)?  $default,){
final _that = this;
switch (_that) {
case _SubtitleTrack() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int index,  int streamIndex,  String codec,  String language,  String languageCode,  String title,  bool isTextBased,  bool isImageBased,  bool extractable,  bool isDefault,  bool isForced)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubtitleTrack() when $default != null:
return $default(_that.index,_that.streamIndex,_that.codec,_that.language,_that.languageCode,_that.title,_that.isTextBased,_that.isImageBased,_that.extractable,_that.isDefault,_that.isForced);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int index,  int streamIndex,  String codec,  String language,  String languageCode,  String title,  bool isTextBased,  bool isImageBased,  bool extractable,  bool isDefault,  bool isForced)  $default,) {final _that = this;
switch (_that) {
case _SubtitleTrack():
return $default(_that.index,_that.streamIndex,_that.codec,_that.language,_that.languageCode,_that.title,_that.isTextBased,_that.isImageBased,_that.extractable,_that.isDefault,_that.isForced);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int index,  int streamIndex,  String codec,  String language,  String languageCode,  String title,  bool isTextBased,  bool isImageBased,  bool extractable,  bool isDefault,  bool isForced)?  $default,) {final _that = this;
switch (_that) {
case _SubtitleTrack() when $default != null:
return $default(_that.index,_that.streamIndex,_that.codec,_that.language,_that.languageCode,_that.title,_that.isTextBased,_that.isImageBased,_that.extractable,_that.isDefault,_that.isForced);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubtitleTrack implements SubtitleTrack {
  const _SubtitleTrack({required this.index, required this.streamIndex, this.codec = 'unknown', this.language = 'Unknown', this.languageCode = 'und', this.title = '', this.isTextBased = false, this.isImageBased = false, this.extractable = false, this.isDefault = false, this.isForced = false});
  factory _SubtitleTrack.fromJson(Map<String, dynamic> json) => _$SubtitleTrackFromJson(json);

@override final  int index;
@override final  int streamIndex;
@override@JsonKey() final  String codec;
@override@JsonKey() final  String language;
@override@JsonKey() final  String languageCode;
@override@JsonKey() final  String title;
@override@JsonKey() final  bool isTextBased;
@override@JsonKey() final  bool isImageBased;
@override@JsonKey() final  bool extractable;
@override@JsonKey() final  bool isDefault;
@override@JsonKey() final  bool isForced;

/// Create a copy of SubtitleTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubtitleTrackCopyWith<_SubtitleTrack> get copyWith => __$SubtitleTrackCopyWithImpl<_SubtitleTrack>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubtitleTrackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubtitleTrack&&(identical(other.index, index) || other.index == index)&&(identical(other.streamIndex, streamIndex) || other.streamIndex == streamIndex)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.language, language) || other.language == language)&&(identical(other.languageCode, languageCode) || other.languageCode == languageCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.isTextBased, isTextBased) || other.isTextBased == isTextBased)&&(identical(other.isImageBased, isImageBased) || other.isImageBased == isImageBased)&&(identical(other.extractable, extractable) || other.extractable == extractable)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.isForced, isForced) || other.isForced == isForced));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,index,streamIndex,codec,language,languageCode,title,isTextBased,isImageBased,extractable,isDefault,isForced);

@override
String toString() {
  return 'SubtitleTrack(index: $index, streamIndex: $streamIndex, codec: $codec, language: $language, languageCode: $languageCode, title: $title, isTextBased: $isTextBased, isImageBased: $isImageBased, extractable: $extractable, isDefault: $isDefault, isForced: $isForced)';
}


}

/// @nodoc
abstract mixin class _$SubtitleTrackCopyWith<$Res> implements $SubtitleTrackCopyWith<$Res> {
  factory _$SubtitleTrackCopyWith(_SubtitleTrack value, $Res Function(_SubtitleTrack) _then) = __$SubtitleTrackCopyWithImpl;
@override @useResult
$Res call({
 int index, int streamIndex, String codec, String language, String languageCode, String title, bool isTextBased, bool isImageBased, bool extractable, bool isDefault, bool isForced
});




}
/// @nodoc
class __$SubtitleTrackCopyWithImpl<$Res>
    implements _$SubtitleTrackCopyWith<$Res> {
  __$SubtitleTrackCopyWithImpl(this._self, this._then);

  final _SubtitleTrack _self;
  final $Res Function(_SubtitleTrack) _then;

/// Create a copy of SubtitleTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? index = null,Object? streamIndex = null,Object? codec = null,Object? language = null,Object? languageCode = null,Object? title = null,Object? isTextBased = null,Object? isImageBased = null,Object? extractable = null,Object? isDefault = null,Object? isForced = null,}) {
  return _then(_SubtitleTrack(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,streamIndex: null == streamIndex ? _self.streamIndex : streamIndex // ignore: cast_nullable_to_non_nullable
as int,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,languageCode: null == languageCode ? _self.languageCode : languageCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,isTextBased: null == isTextBased ? _self.isTextBased : isTextBased // ignore: cast_nullable_to_non_nullable
as bool,isImageBased: null == isImageBased ? _self.isImageBased : isImageBased // ignore: cast_nullable_to_non_nullable
as bool,extractable: null == extractable ? _self.extractable : extractable // ignore: cast_nullable_to_non_nullable
as bool,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,isForced: null == isForced ? _self.isForced : isForced // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TrackInfo {

 String get fileId; String get audioCodec; bool get browserPlayable; List<AudioTrack> get audioTracks; List<SubtitleTrack> get subtitleTracks; bool get hasUnsupportedAudio; double get duration; bool get ready;
/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackInfoCopyWith<TrackInfo> get copyWith => _$TrackInfoCopyWithImpl<TrackInfo>(this as TrackInfo, _$identity);

  /// Serializes this TrackInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackInfo&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.audioCodec, audioCodec) || other.audioCodec == audioCodec)&&(identical(other.browserPlayable, browserPlayable) || other.browserPlayable == browserPlayable)&&const DeepCollectionEquality().equals(other.audioTracks, audioTracks)&&const DeepCollectionEquality().equals(other.subtitleTracks, subtitleTracks)&&(identical(other.hasUnsupportedAudio, hasUnsupportedAudio) || other.hasUnsupportedAudio == hasUnsupportedAudio)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.ready, ready) || other.ready == ready));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileId,audioCodec,browserPlayable,const DeepCollectionEquality().hash(audioTracks),const DeepCollectionEquality().hash(subtitleTracks),hasUnsupportedAudio,duration,ready);

@override
String toString() {
  return 'TrackInfo(fileId: $fileId, audioCodec: $audioCodec, browserPlayable: $browserPlayable, audioTracks: $audioTracks, subtitleTracks: $subtitleTracks, hasUnsupportedAudio: $hasUnsupportedAudio, duration: $duration, ready: $ready)';
}


}

/// @nodoc
abstract mixin class $TrackInfoCopyWith<$Res>  {
  factory $TrackInfoCopyWith(TrackInfo value, $Res Function(TrackInfo) _then) = _$TrackInfoCopyWithImpl;
@useResult
$Res call({
 String fileId, String audioCodec, bool browserPlayable, List<AudioTrack> audioTracks, List<SubtitleTrack> subtitleTracks, bool hasUnsupportedAudio, double duration, bool ready
});




}
/// @nodoc
class _$TrackInfoCopyWithImpl<$Res>
    implements $TrackInfoCopyWith<$Res> {
  _$TrackInfoCopyWithImpl(this._self, this._then);

  final TrackInfo _self;
  final $Res Function(TrackInfo) _then;

/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileId = null,Object? audioCodec = null,Object? browserPlayable = null,Object? audioTracks = null,Object? subtitleTracks = null,Object? hasUnsupportedAudio = null,Object? duration = null,Object? ready = null,}) {
  return _then(_self.copyWith(
fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,audioCodec: null == audioCodec ? _self.audioCodec : audioCodec // ignore: cast_nullable_to_non_nullable
as String,browserPlayable: null == browserPlayable ? _self.browserPlayable : browserPlayable // ignore: cast_nullable_to_non_nullable
as bool,audioTracks: null == audioTracks ? _self.audioTracks : audioTracks // ignore: cast_nullable_to_non_nullable
as List<AudioTrack>,subtitleTracks: null == subtitleTracks ? _self.subtitleTracks : subtitleTracks // ignore: cast_nullable_to_non_nullable
as List<SubtitleTrack>,hasUnsupportedAudio: null == hasUnsupportedAudio ? _self.hasUnsupportedAudio : hasUnsupportedAudio // ignore: cast_nullable_to_non_nullable
as bool,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as double,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackInfo].
extension TrackInfoPatterns on TrackInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackInfo value)  $default,){
final _that = this;
switch (_that) {
case _TrackInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackInfo value)?  $default,){
final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fileId,  String audioCodec,  bool browserPlayable,  List<AudioTrack> audioTracks,  List<SubtitleTrack> subtitleTracks,  bool hasUnsupportedAudio,  double duration,  bool ready)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
return $default(_that.fileId,_that.audioCodec,_that.browserPlayable,_that.audioTracks,_that.subtitleTracks,_that.hasUnsupportedAudio,_that.duration,_that.ready);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fileId,  String audioCodec,  bool browserPlayable,  List<AudioTrack> audioTracks,  List<SubtitleTrack> subtitleTracks,  bool hasUnsupportedAudio,  double duration,  bool ready)  $default,) {final _that = this;
switch (_that) {
case _TrackInfo():
return $default(_that.fileId,_that.audioCodec,_that.browserPlayable,_that.audioTracks,_that.subtitleTracks,_that.hasUnsupportedAudio,_that.duration,_that.ready);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fileId,  String audioCodec,  bool browserPlayable,  List<AudioTrack> audioTracks,  List<SubtitleTrack> subtitleTracks,  bool hasUnsupportedAudio,  double duration,  bool ready)?  $default,) {final _that = this;
switch (_that) {
case _TrackInfo() when $default != null:
return $default(_that.fileId,_that.audioCodec,_that.browserPlayable,_that.audioTracks,_that.subtitleTracks,_that.hasUnsupportedAudio,_that.duration,_that.ready);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrackInfo implements TrackInfo {
  const _TrackInfo({required this.fileId, this.audioCodec = 'unknown', this.browserPlayable = true, final  List<AudioTrack> audioTracks = const [], final  List<SubtitleTrack> subtitleTracks = const [], this.hasUnsupportedAudio = false, this.duration = 0, this.ready = true}): _audioTracks = audioTracks,_subtitleTracks = subtitleTracks;
  factory _TrackInfo.fromJson(Map<String, dynamic> json) => _$TrackInfoFromJson(json);

@override final  String fileId;
@override@JsonKey() final  String audioCodec;
@override@JsonKey() final  bool browserPlayable;
 final  List<AudioTrack> _audioTracks;
@override@JsonKey() List<AudioTrack> get audioTracks {
  if (_audioTracks is EqualUnmodifiableListView) return _audioTracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audioTracks);
}

 final  List<SubtitleTrack> _subtitleTracks;
@override@JsonKey() List<SubtitleTrack> get subtitleTracks {
  if (_subtitleTracks is EqualUnmodifiableListView) return _subtitleTracks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subtitleTracks);
}

@override@JsonKey() final  bool hasUnsupportedAudio;
@override@JsonKey() final  double duration;
@override@JsonKey() final  bool ready;

/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackInfoCopyWith<_TrackInfo> get copyWith => __$TrackInfoCopyWithImpl<_TrackInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackInfo&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.audioCodec, audioCodec) || other.audioCodec == audioCodec)&&(identical(other.browserPlayable, browserPlayable) || other.browserPlayable == browserPlayable)&&const DeepCollectionEquality().equals(other._audioTracks, _audioTracks)&&const DeepCollectionEquality().equals(other._subtitleTracks, _subtitleTracks)&&(identical(other.hasUnsupportedAudio, hasUnsupportedAudio) || other.hasUnsupportedAudio == hasUnsupportedAudio)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.ready, ready) || other.ready == ready));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fileId,audioCodec,browserPlayable,const DeepCollectionEquality().hash(_audioTracks),const DeepCollectionEquality().hash(_subtitleTracks),hasUnsupportedAudio,duration,ready);

@override
String toString() {
  return 'TrackInfo(fileId: $fileId, audioCodec: $audioCodec, browserPlayable: $browserPlayable, audioTracks: $audioTracks, subtitleTracks: $subtitleTracks, hasUnsupportedAudio: $hasUnsupportedAudio, duration: $duration, ready: $ready)';
}


}

/// @nodoc
abstract mixin class _$TrackInfoCopyWith<$Res> implements $TrackInfoCopyWith<$Res> {
  factory _$TrackInfoCopyWith(_TrackInfo value, $Res Function(_TrackInfo) _then) = __$TrackInfoCopyWithImpl;
@override @useResult
$Res call({
 String fileId, String audioCodec, bool browserPlayable, List<AudioTrack> audioTracks, List<SubtitleTrack> subtitleTracks, bool hasUnsupportedAudio, double duration, bool ready
});




}
/// @nodoc
class __$TrackInfoCopyWithImpl<$Res>
    implements _$TrackInfoCopyWith<$Res> {
  __$TrackInfoCopyWithImpl(this._self, this._then);

  final _TrackInfo _self;
  final $Res Function(_TrackInfo) _then;

/// Create a copy of TrackInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileId = null,Object? audioCodec = null,Object? browserPlayable = null,Object? audioTracks = null,Object? subtitleTracks = null,Object? hasUnsupportedAudio = null,Object? duration = null,Object? ready = null,}) {
  return _then(_TrackInfo(
fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,audioCodec: null == audioCodec ? _self.audioCodec : audioCodec // ignore: cast_nullable_to_non_nullable
as String,browserPlayable: null == browserPlayable ? _self.browserPlayable : browserPlayable // ignore: cast_nullable_to_non_nullable
as bool,audioTracks: null == audioTracks ? _self._audioTracks : audioTracks // ignore: cast_nullable_to_non_nullable
as List<AudioTrack>,subtitleTracks: null == subtitleTracks ? _self._subtitleTracks : subtitleTracks // ignore: cast_nullable_to_non_nullable
as List<SubtitleTrack>,hasUnsupportedAudio: null == hasUnsupportedAudio ? _self.hasUnsupportedAudio : hasUnsupportedAudio // ignore: cast_nullable_to_non_nullable
as bool,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as double,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
