// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'curated_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CuratedGenreItem {

 String get name; String get slug; String? get image; int get count;
/// Create a copy of CuratedGenreItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CuratedGenreItemCopyWith<CuratedGenreItem> get copyWith => _$CuratedGenreItemCopyWithImpl<CuratedGenreItem>(this as CuratedGenreItem, _$identity);

  /// Serializes this CuratedGenreItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CuratedGenreItem&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.image, image) || other.image == image)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,slug,image,count);

@override
String toString() {
  return 'CuratedGenreItem(name: $name, slug: $slug, image: $image, count: $count)';
}


}

/// @nodoc
abstract mixin class $CuratedGenreItemCopyWith<$Res>  {
  factory $CuratedGenreItemCopyWith(CuratedGenreItem value, $Res Function(CuratedGenreItem) _then) = _$CuratedGenreItemCopyWithImpl;
@useResult
$Res call({
 String name, String slug, String? image, int count
});




}
/// @nodoc
class _$CuratedGenreItemCopyWithImpl<$Res>
    implements $CuratedGenreItemCopyWith<$Res> {
  _$CuratedGenreItemCopyWithImpl(this._self, this._then);

  final CuratedGenreItem _self;
  final $Res Function(CuratedGenreItem) _then;

/// Create a copy of CuratedGenreItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? slug = null,Object? image = freezed,Object? count = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CuratedGenreItem].
extension CuratedGenreItemPatterns on CuratedGenreItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CuratedGenreItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CuratedGenreItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CuratedGenreItem value)  $default,){
final _that = this;
switch (_that) {
case _CuratedGenreItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CuratedGenreItem value)?  $default,){
final _that = this;
switch (_that) {
case _CuratedGenreItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String slug,  String? image,  int count)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CuratedGenreItem() when $default != null:
return $default(_that.name,_that.slug,_that.image,_that.count);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String slug,  String? image,  int count)  $default,) {final _that = this;
switch (_that) {
case _CuratedGenreItem():
return $default(_that.name,_that.slug,_that.image,_that.count);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String slug,  String? image,  int count)?  $default,) {final _that = this;
switch (_that) {
case _CuratedGenreItem() when $default != null:
return $default(_that.name,_that.slug,_that.image,_that.count);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CuratedGenreItem implements CuratedGenreItem {
  const _CuratedGenreItem({required this.name, required this.slug, this.image, required this.count});
  factory _CuratedGenreItem.fromJson(Map<String, dynamic> json) => _$CuratedGenreItemFromJson(json);

@override final  String name;
@override final  String slug;
@override final  String? image;
@override final  int count;

/// Create a copy of CuratedGenreItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CuratedGenreItemCopyWith<_CuratedGenreItem> get copyWith => __$CuratedGenreItemCopyWithImpl<_CuratedGenreItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CuratedGenreItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CuratedGenreItem&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.image, image) || other.image == image)&&(identical(other.count, count) || other.count == count));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,slug,image,count);

@override
String toString() {
  return 'CuratedGenreItem(name: $name, slug: $slug, image: $image, count: $count)';
}


}

/// @nodoc
abstract mixin class _$CuratedGenreItemCopyWith<$Res> implements $CuratedGenreItemCopyWith<$Res> {
  factory _$CuratedGenreItemCopyWith(_CuratedGenreItem value, $Res Function(_CuratedGenreItem) _then) = __$CuratedGenreItemCopyWithImpl;
@override @useResult
$Res call({
 String name, String slug, String? image, int count
});




}
/// @nodoc
class __$CuratedGenreItemCopyWithImpl<$Res>
    implements _$CuratedGenreItemCopyWith<$Res> {
  __$CuratedGenreItemCopyWithImpl(this._self, this._then);

  final _CuratedGenreItem _self;
  final $Res Function(_CuratedGenreItem) _then;

/// Create a copy of CuratedGenreItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? slug = null,Object? image = freezed,Object? count = null,}) {
  return _then(_CuratedGenreItem(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CuratedGenresPage {

 List<CuratedGenreItem> get genres; Map<String, Map<String, List<Movie>>> get sections;
/// Create a copy of CuratedGenresPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CuratedGenresPageCopyWith<CuratedGenresPage> get copyWith => _$CuratedGenresPageCopyWithImpl<CuratedGenresPage>(this as CuratedGenresPage, _$identity);

  /// Serializes this CuratedGenresPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CuratedGenresPage&&const DeepCollectionEquality().equals(other.genres, genres)&&const DeepCollectionEquality().equals(other.sections, sections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(genres),const DeepCollectionEquality().hash(sections));

@override
String toString() {
  return 'CuratedGenresPage(genres: $genres, sections: $sections)';
}


}

/// @nodoc
abstract mixin class $CuratedGenresPageCopyWith<$Res>  {
  factory $CuratedGenresPageCopyWith(CuratedGenresPage value, $Res Function(CuratedGenresPage) _then) = _$CuratedGenresPageCopyWithImpl;
@useResult
$Res call({
 List<CuratedGenreItem> genres, Map<String, Map<String, List<Movie>>> sections
});




}
/// @nodoc
class _$CuratedGenresPageCopyWithImpl<$Res>
    implements $CuratedGenresPageCopyWith<$Res> {
  _$CuratedGenresPageCopyWithImpl(this._self, this._then);

  final CuratedGenresPage _self;
  final $Res Function(CuratedGenresPage) _then;

/// Create a copy of CuratedGenresPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? genres = null,Object? sections = null,}) {
  return _then(_self.copyWith(
genres: null == genres ? _self.genres : genres // ignore: cast_nullable_to_non_nullable
as List<CuratedGenreItem>,sections: null == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, List<Movie>>>,
  ));
}

}


/// Adds pattern-matching-related methods to [CuratedGenresPage].
extension CuratedGenresPagePatterns on CuratedGenresPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CuratedGenresPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CuratedGenresPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CuratedGenresPage value)  $default,){
final _that = this;
switch (_that) {
case _CuratedGenresPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CuratedGenresPage value)?  $default,){
final _that = this;
switch (_that) {
case _CuratedGenresPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<CuratedGenreItem> genres,  Map<String, Map<String, List<Movie>>> sections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CuratedGenresPage() when $default != null:
return $default(_that.genres,_that.sections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<CuratedGenreItem> genres,  Map<String, Map<String, List<Movie>>> sections)  $default,) {final _that = this;
switch (_that) {
case _CuratedGenresPage():
return $default(_that.genres,_that.sections);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<CuratedGenreItem> genres,  Map<String, Map<String, List<Movie>>> sections)?  $default,) {final _that = this;
switch (_that) {
case _CuratedGenresPage() when $default != null:
return $default(_that.genres,_that.sections);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CuratedGenresPage implements CuratedGenresPage {
  const _CuratedGenresPage({required final  List<CuratedGenreItem> genres, required final  Map<String, Map<String, List<Movie>>> sections}): _genres = genres,_sections = sections;
  factory _CuratedGenresPage.fromJson(Map<String, dynamic> json) => _$CuratedGenresPageFromJson(json);

 final  List<CuratedGenreItem> _genres;
@override List<CuratedGenreItem> get genres {
  if (_genres is EqualUnmodifiableListView) return _genres;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_genres);
}

 final  Map<String, Map<String, List<Movie>>> _sections;
@override Map<String, Map<String, List<Movie>>> get sections {
  if (_sections is EqualUnmodifiableMapView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_sections);
}


/// Create a copy of CuratedGenresPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CuratedGenresPageCopyWith<_CuratedGenresPage> get copyWith => __$CuratedGenresPageCopyWithImpl<_CuratedGenresPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CuratedGenresPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CuratedGenresPage&&const DeepCollectionEquality().equals(other._genres, _genres)&&const DeepCollectionEquality().equals(other._sections, _sections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_genres),const DeepCollectionEquality().hash(_sections));

@override
String toString() {
  return 'CuratedGenresPage(genres: $genres, sections: $sections)';
}


}

/// @nodoc
abstract mixin class _$CuratedGenresPageCopyWith<$Res> implements $CuratedGenresPageCopyWith<$Res> {
  factory _$CuratedGenresPageCopyWith(_CuratedGenresPage value, $Res Function(_CuratedGenresPage) _then) = __$CuratedGenresPageCopyWithImpl;
@override @useResult
$Res call({
 List<CuratedGenreItem> genres, Map<String, Map<String, List<Movie>>> sections
});




}
/// @nodoc
class __$CuratedGenresPageCopyWithImpl<$Res>
    implements _$CuratedGenresPageCopyWith<$Res> {
  __$CuratedGenresPageCopyWithImpl(this._self, this._then);

  final _CuratedGenresPage _self;
  final $Res Function(_CuratedGenresPage) _then;

/// Create a copy of CuratedGenresPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? genres = null,Object? sections = null,}) {
  return _then(_CuratedGenresPage(
genres: null == genres ? _self._genres : genres // ignore: cast_nullable_to_non_nullable
as List<CuratedGenreItem>,sections: null == sections ? _self._sections : sections // ignore: cast_nullable_to_non_nullable
as Map<String, Map<String, List<Movie>>>,
  ));
}


}


/// @nodoc
mixin _$CuratedSpecialSections {

 Map<String, List<Movie>> get mood; Map<String, List<Movie>> get duration;
/// Create a copy of CuratedSpecialSections
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CuratedSpecialSectionsCopyWith<CuratedSpecialSections> get copyWith => _$CuratedSpecialSectionsCopyWithImpl<CuratedSpecialSections>(this as CuratedSpecialSections, _$identity);

  /// Serializes this CuratedSpecialSections to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CuratedSpecialSections&&const DeepCollectionEquality().equals(other.mood, mood)&&const DeepCollectionEquality().equals(other.duration, duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(mood),const DeepCollectionEquality().hash(duration));

@override
String toString() {
  return 'CuratedSpecialSections(mood: $mood, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $CuratedSpecialSectionsCopyWith<$Res>  {
  factory $CuratedSpecialSectionsCopyWith(CuratedSpecialSections value, $Res Function(CuratedSpecialSections) _then) = _$CuratedSpecialSectionsCopyWithImpl;
@useResult
$Res call({
 Map<String, List<Movie>> mood, Map<String, List<Movie>> duration
});




}
/// @nodoc
class _$CuratedSpecialSectionsCopyWithImpl<$Res>
    implements $CuratedSpecialSectionsCopyWith<$Res> {
  _$CuratedSpecialSectionsCopyWithImpl(this._self, this._then);

  final CuratedSpecialSections _self;
  final $Res Function(CuratedSpecialSections) _then;

/// Create a copy of CuratedSpecialSections
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mood = null,Object? duration = null,}) {
  return _then(_self.copyWith(
mood: null == mood ? _self.mood : mood // ignore: cast_nullable_to_non_nullable
as Map<String, List<Movie>>,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Map<String, List<Movie>>,
  ));
}

}


/// Adds pattern-matching-related methods to [CuratedSpecialSections].
extension CuratedSpecialSectionsPatterns on CuratedSpecialSections {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CuratedSpecialSections value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CuratedSpecialSections() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CuratedSpecialSections value)  $default,){
final _that = this;
switch (_that) {
case _CuratedSpecialSections():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CuratedSpecialSections value)?  $default,){
final _that = this;
switch (_that) {
case _CuratedSpecialSections() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, List<Movie>> mood,  Map<String, List<Movie>> duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CuratedSpecialSections() when $default != null:
return $default(_that.mood,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, List<Movie>> mood,  Map<String, List<Movie>> duration)  $default,) {final _that = this;
switch (_that) {
case _CuratedSpecialSections():
return $default(_that.mood,_that.duration);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, List<Movie>> mood,  Map<String, List<Movie>> duration)?  $default,) {final _that = this;
switch (_that) {
case _CuratedSpecialSections() when $default != null:
return $default(_that.mood,_that.duration);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CuratedSpecialSections implements CuratedSpecialSections {
  const _CuratedSpecialSections({required final  Map<String, List<Movie>> mood, required final  Map<String, List<Movie>> duration}): _mood = mood,_duration = duration;
  factory _CuratedSpecialSections.fromJson(Map<String, dynamic> json) => _$CuratedSpecialSectionsFromJson(json);

 final  Map<String, List<Movie>> _mood;
@override Map<String, List<Movie>> get mood {
  if (_mood is EqualUnmodifiableMapView) return _mood;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_mood);
}

 final  Map<String, List<Movie>> _duration;
@override Map<String, List<Movie>> get duration {
  if (_duration is EqualUnmodifiableMapView) return _duration;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_duration);
}


/// Create a copy of CuratedSpecialSections
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CuratedSpecialSectionsCopyWith<_CuratedSpecialSections> get copyWith => __$CuratedSpecialSectionsCopyWithImpl<_CuratedSpecialSections>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CuratedSpecialSectionsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CuratedSpecialSections&&const DeepCollectionEquality().equals(other._mood, _mood)&&const DeepCollectionEquality().equals(other._duration, _duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_mood),const DeepCollectionEquality().hash(_duration));

@override
String toString() {
  return 'CuratedSpecialSections(mood: $mood, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$CuratedSpecialSectionsCopyWith<$Res> implements $CuratedSpecialSectionsCopyWith<$Res> {
  factory _$CuratedSpecialSectionsCopyWith(_CuratedSpecialSections value, $Res Function(_CuratedSpecialSections) _then) = __$CuratedSpecialSectionsCopyWithImpl;
@override @useResult
$Res call({
 Map<String, List<Movie>> mood, Map<String, List<Movie>> duration
});




}
/// @nodoc
class __$CuratedSpecialSectionsCopyWithImpl<$Res>
    implements _$CuratedSpecialSectionsCopyWith<$Res> {
  __$CuratedSpecialSectionsCopyWithImpl(this._self, this._then);

  final _CuratedSpecialSections _self;
  final $Res Function(_CuratedSpecialSections) _then;

/// Create a copy of CuratedSpecialSections
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mood = null,Object? duration = null,}) {
  return _then(_CuratedSpecialSections(
mood: null == mood ? _self._mood : mood // ignore: cast_nullable_to_non_nullable
as Map<String, List<Movie>>,duration: null == duration ? _self._duration : duration // ignore: cast_nullable_to_non_nullable
as Map<String, List<Movie>>,
  ));
}


}


/// @nodoc
mixin _$CuratedHomepage {

 List<Movie> get hero; List<Movie> get trending;@JsonKey(name: 'recently_added') List<Movie> get recentlyAdded;@JsonKey(name: 'top_rated') List<Movie> get topRated; Map<String, List<Movie>> get rows;
/// Create a copy of CuratedHomepage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CuratedHomepageCopyWith<CuratedHomepage> get copyWith => _$CuratedHomepageCopyWithImpl<CuratedHomepage>(this as CuratedHomepage, _$identity);

  /// Serializes this CuratedHomepage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CuratedHomepage&&const DeepCollectionEquality().equals(other.hero, hero)&&const DeepCollectionEquality().equals(other.trending, trending)&&const DeepCollectionEquality().equals(other.recentlyAdded, recentlyAdded)&&const DeepCollectionEquality().equals(other.topRated, topRated)&&const DeepCollectionEquality().equals(other.rows, rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(hero),const DeepCollectionEquality().hash(trending),const DeepCollectionEquality().hash(recentlyAdded),const DeepCollectionEquality().hash(topRated),const DeepCollectionEquality().hash(rows));

@override
String toString() {
  return 'CuratedHomepage(hero: $hero, trending: $trending, recentlyAdded: $recentlyAdded, topRated: $topRated, rows: $rows)';
}


}

/// @nodoc
abstract mixin class $CuratedHomepageCopyWith<$Res>  {
  factory $CuratedHomepageCopyWith(CuratedHomepage value, $Res Function(CuratedHomepage) _then) = _$CuratedHomepageCopyWithImpl;
@useResult
$Res call({
 List<Movie> hero, List<Movie> trending,@JsonKey(name: 'recently_added') List<Movie> recentlyAdded,@JsonKey(name: 'top_rated') List<Movie> topRated, Map<String, List<Movie>> rows
});




}
/// @nodoc
class _$CuratedHomepageCopyWithImpl<$Res>
    implements $CuratedHomepageCopyWith<$Res> {
  _$CuratedHomepageCopyWithImpl(this._self, this._then);

  final CuratedHomepage _self;
  final $Res Function(CuratedHomepage) _then;

/// Create a copy of CuratedHomepage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hero = null,Object? trending = null,Object? recentlyAdded = null,Object? topRated = null,Object? rows = null,}) {
  return _then(_self.copyWith(
hero: null == hero ? _self.hero : hero // ignore: cast_nullable_to_non_nullable
as List<Movie>,trending: null == trending ? _self.trending : trending // ignore: cast_nullable_to_non_nullable
as List<Movie>,recentlyAdded: null == recentlyAdded ? _self.recentlyAdded : recentlyAdded // ignore: cast_nullable_to_non_nullable
as List<Movie>,topRated: null == topRated ? _self.topRated : topRated // ignore: cast_nullable_to_non_nullable
as List<Movie>,rows: null == rows ? _self.rows : rows // ignore: cast_nullable_to_non_nullable
as Map<String, List<Movie>>,
  ));
}

}


/// Adds pattern-matching-related methods to [CuratedHomepage].
extension CuratedHomepagePatterns on CuratedHomepage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CuratedHomepage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CuratedHomepage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CuratedHomepage value)  $default,){
final _that = this;
switch (_that) {
case _CuratedHomepage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CuratedHomepage value)?  $default,){
final _that = this;
switch (_that) {
case _CuratedHomepage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Movie> hero,  List<Movie> trending, @JsonKey(name: 'recently_added')  List<Movie> recentlyAdded, @JsonKey(name: 'top_rated')  List<Movie> topRated,  Map<String, List<Movie>> rows)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CuratedHomepage() when $default != null:
return $default(_that.hero,_that.trending,_that.recentlyAdded,_that.topRated,_that.rows);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Movie> hero,  List<Movie> trending, @JsonKey(name: 'recently_added')  List<Movie> recentlyAdded, @JsonKey(name: 'top_rated')  List<Movie> topRated,  Map<String, List<Movie>> rows)  $default,) {final _that = this;
switch (_that) {
case _CuratedHomepage():
return $default(_that.hero,_that.trending,_that.recentlyAdded,_that.topRated,_that.rows);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Movie> hero,  List<Movie> trending, @JsonKey(name: 'recently_added')  List<Movie> recentlyAdded, @JsonKey(name: 'top_rated')  List<Movie> topRated,  Map<String, List<Movie>> rows)?  $default,) {final _that = this;
switch (_that) {
case _CuratedHomepage() when $default != null:
return $default(_that.hero,_that.trending,_that.recentlyAdded,_that.topRated,_that.rows);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CuratedHomepage implements CuratedHomepage {
  const _CuratedHomepage({required final  List<Movie> hero, required final  List<Movie> trending, @JsonKey(name: 'recently_added') required final  List<Movie> recentlyAdded, @JsonKey(name: 'top_rated') required final  List<Movie> topRated, required final  Map<String, List<Movie>> rows}): _hero = hero,_trending = trending,_recentlyAdded = recentlyAdded,_topRated = topRated,_rows = rows;
  factory _CuratedHomepage.fromJson(Map<String, dynamic> json) => _$CuratedHomepageFromJson(json);

 final  List<Movie> _hero;
@override List<Movie> get hero {
  if (_hero is EqualUnmodifiableListView) return _hero;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_hero);
}

 final  List<Movie> _trending;
@override List<Movie> get trending {
  if (_trending is EqualUnmodifiableListView) return _trending;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trending);
}

 final  List<Movie> _recentlyAdded;
@override@JsonKey(name: 'recently_added') List<Movie> get recentlyAdded {
  if (_recentlyAdded is EqualUnmodifiableListView) return _recentlyAdded;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentlyAdded);
}

 final  List<Movie> _topRated;
@override@JsonKey(name: 'top_rated') List<Movie> get topRated {
  if (_topRated is EqualUnmodifiableListView) return _topRated;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topRated);
}

 final  Map<String, List<Movie>> _rows;
@override Map<String, List<Movie>> get rows {
  if (_rows is EqualUnmodifiableMapView) return _rows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_rows);
}


/// Create a copy of CuratedHomepage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CuratedHomepageCopyWith<_CuratedHomepage> get copyWith => __$CuratedHomepageCopyWithImpl<_CuratedHomepage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CuratedHomepageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CuratedHomepage&&const DeepCollectionEquality().equals(other._hero, _hero)&&const DeepCollectionEquality().equals(other._trending, _trending)&&const DeepCollectionEquality().equals(other._recentlyAdded, _recentlyAdded)&&const DeepCollectionEquality().equals(other._topRated, _topRated)&&const DeepCollectionEquality().equals(other._rows, _rows));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_hero),const DeepCollectionEquality().hash(_trending),const DeepCollectionEquality().hash(_recentlyAdded),const DeepCollectionEquality().hash(_topRated),const DeepCollectionEquality().hash(_rows));

@override
String toString() {
  return 'CuratedHomepage(hero: $hero, trending: $trending, recentlyAdded: $recentlyAdded, topRated: $topRated, rows: $rows)';
}


}

/// @nodoc
abstract mixin class _$CuratedHomepageCopyWith<$Res> implements $CuratedHomepageCopyWith<$Res> {
  factory _$CuratedHomepageCopyWith(_CuratedHomepage value, $Res Function(_CuratedHomepage) _then) = __$CuratedHomepageCopyWithImpl;
@override @useResult
$Res call({
 List<Movie> hero, List<Movie> trending,@JsonKey(name: 'recently_added') List<Movie> recentlyAdded,@JsonKey(name: 'top_rated') List<Movie> topRated, Map<String, List<Movie>> rows
});




}
/// @nodoc
class __$CuratedHomepageCopyWithImpl<$Res>
    implements _$CuratedHomepageCopyWith<$Res> {
  __$CuratedHomepageCopyWithImpl(this._self, this._then);

  final _CuratedHomepage _self;
  final $Res Function(_CuratedHomepage) _then;

/// Create a copy of CuratedHomepage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hero = null,Object? trending = null,Object? recentlyAdded = null,Object? topRated = null,Object? rows = null,}) {
  return _then(_CuratedHomepage(
hero: null == hero ? _self._hero : hero // ignore: cast_nullable_to_non_nullable
as List<Movie>,trending: null == trending ? _self._trending : trending // ignore: cast_nullable_to_non_nullable
as List<Movie>,recentlyAdded: null == recentlyAdded ? _self._recentlyAdded : recentlyAdded // ignore: cast_nullable_to_non_nullable
as List<Movie>,topRated: null == topRated ? _self._topRated : topRated // ignore: cast_nullable_to_non_nullable
as List<Movie>,rows: null == rows ? _self._rows : rows // ignore: cast_nullable_to_non_nullable
as Map<String, List<Movie>>,
  ));
}


}


/// @nodoc
mixin _$CuratedResponse {

 CuratedHomepage get homepage;@JsonKey(name: 'genres_page') CuratedGenresPage get genresPage;@JsonKey(name: 'special_sections') CuratedSpecialSections get specialSections;
/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CuratedResponseCopyWith<CuratedResponse> get copyWith => _$CuratedResponseCopyWithImpl<CuratedResponse>(this as CuratedResponse, _$identity);

  /// Serializes this CuratedResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CuratedResponse&&(identical(other.homepage, homepage) || other.homepage == homepage)&&(identical(other.genresPage, genresPage) || other.genresPage == genresPage)&&(identical(other.specialSections, specialSections) || other.specialSections == specialSections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,homepage,genresPage,specialSections);

@override
String toString() {
  return 'CuratedResponse(homepage: $homepage, genresPage: $genresPage, specialSections: $specialSections)';
}


}

/// @nodoc
abstract mixin class $CuratedResponseCopyWith<$Res>  {
  factory $CuratedResponseCopyWith(CuratedResponse value, $Res Function(CuratedResponse) _then) = _$CuratedResponseCopyWithImpl;
@useResult
$Res call({
 CuratedHomepage homepage,@JsonKey(name: 'genres_page') CuratedGenresPage genresPage,@JsonKey(name: 'special_sections') CuratedSpecialSections specialSections
});


$CuratedHomepageCopyWith<$Res> get homepage;$CuratedGenresPageCopyWith<$Res> get genresPage;$CuratedSpecialSectionsCopyWith<$Res> get specialSections;

}
/// @nodoc
class _$CuratedResponseCopyWithImpl<$Res>
    implements $CuratedResponseCopyWith<$Res> {
  _$CuratedResponseCopyWithImpl(this._self, this._then);

  final CuratedResponse _self;
  final $Res Function(CuratedResponse) _then;

/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? homepage = null,Object? genresPage = null,Object? specialSections = null,}) {
  return _then(_self.copyWith(
homepage: null == homepage ? _self.homepage : homepage // ignore: cast_nullable_to_non_nullable
as CuratedHomepage,genresPage: null == genresPage ? _self.genresPage : genresPage // ignore: cast_nullable_to_non_nullable
as CuratedGenresPage,specialSections: null == specialSections ? _self.specialSections : specialSections // ignore: cast_nullable_to_non_nullable
as CuratedSpecialSections,
  ));
}
/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuratedHomepageCopyWith<$Res> get homepage {
  
  return $CuratedHomepageCopyWith<$Res>(_self.homepage, (value) {
    return _then(_self.copyWith(homepage: value));
  });
}/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuratedGenresPageCopyWith<$Res> get genresPage {
  
  return $CuratedGenresPageCopyWith<$Res>(_self.genresPage, (value) {
    return _then(_self.copyWith(genresPage: value));
  });
}/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuratedSpecialSectionsCopyWith<$Res> get specialSections {
  
  return $CuratedSpecialSectionsCopyWith<$Res>(_self.specialSections, (value) {
    return _then(_self.copyWith(specialSections: value));
  });
}
}


/// Adds pattern-matching-related methods to [CuratedResponse].
extension CuratedResponsePatterns on CuratedResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CuratedResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CuratedResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CuratedResponse value)  $default,){
final _that = this;
switch (_that) {
case _CuratedResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CuratedResponse value)?  $default,){
final _that = this;
switch (_that) {
case _CuratedResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CuratedHomepage homepage, @JsonKey(name: 'genres_page')  CuratedGenresPage genresPage, @JsonKey(name: 'special_sections')  CuratedSpecialSections specialSections)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CuratedResponse() when $default != null:
return $default(_that.homepage,_that.genresPage,_that.specialSections);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CuratedHomepage homepage, @JsonKey(name: 'genres_page')  CuratedGenresPage genresPage, @JsonKey(name: 'special_sections')  CuratedSpecialSections specialSections)  $default,) {final _that = this;
switch (_that) {
case _CuratedResponse():
return $default(_that.homepage,_that.genresPage,_that.specialSections);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CuratedHomepage homepage, @JsonKey(name: 'genres_page')  CuratedGenresPage genresPage, @JsonKey(name: 'special_sections')  CuratedSpecialSections specialSections)?  $default,) {final _that = this;
switch (_that) {
case _CuratedResponse() when $default != null:
return $default(_that.homepage,_that.genresPage,_that.specialSections);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CuratedResponse implements CuratedResponse {
  const _CuratedResponse({required this.homepage, @JsonKey(name: 'genres_page') required this.genresPage, @JsonKey(name: 'special_sections') required this.specialSections});
  factory _CuratedResponse.fromJson(Map<String, dynamic> json) => _$CuratedResponseFromJson(json);

@override final  CuratedHomepage homepage;
@override@JsonKey(name: 'genres_page') final  CuratedGenresPage genresPage;
@override@JsonKey(name: 'special_sections') final  CuratedSpecialSections specialSections;

/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CuratedResponseCopyWith<_CuratedResponse> get copyWith => __$CuratedResponseCopyWithImpl<_CuratedResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CuratedResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CuratedResponse&&(identical(other.homepage, homepage) || other.homepage == homepage)&&(identical(other.genresPage, genresPage) || other.genresPage == genresPage)&&(identical(other.specialSections, specialSections) || other.specialSections == specialSections));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,homepage,genresPage,specialSections);

@override
String toString() {
  return 'CuratedResponse(homepage: $homepage, genresPage: $genresPage, specialSections: $specialSections)';
}


}

/// @nodoc
abstract mixin class _$CuratedResponseCopyWith<$Res> implements $CuratedResponseCopyWith<$Res> {
  factory _$CuratedResponseCopyWith(_CuratedResponse value, $Res Function(_CuratedResponse) _then) = __$CuratedResponseCopyWithImpl;
@override @useResult
$Res call({
 CuratedHomepage homepage,@JsonKey(name: 'genres_page') CuratedGenresPage genresPage,@JsonKey(name: 'special_sections') CuratedSpecialSections specialSections
});


@override $CuratedHomepageCopyWith<$Res> get homepage;@override $CuratedGenresPageCopyWith<$Res> get genresPage;@override $CuratedSpecialSectionsCopyWith<$Res> get specialSections;

}
/// @nodoc
class __$CuratedResponseCopyWithImpl<$Res>
    implements _$CuratedResponseCopyWith<$Res> {
  __$CuratedResponseCopyWithImpl(this._self, this._then);

  final _CuratedResponse _self;
  final $Res Function(_CuratedResponse) _then;

/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? homepage = null,Object? genresPage = null,Object? specialSections = null,}) {
  return _then(_CuratedResponse(
homepage: null == homepage ? _self.homepage : homepage // ignore: cast_nullable_to_non_nullable
as CuratedHomepage,genresPage: null == genresPage ? _self.genresPage : genresPage // ignore: cast_nullable_to_non_nullable
as CuratedGenresPage,specialSections: null == specialSections ? _self.specialSections : specialSections // ignore: cast_nullable_to_non_nullable
as CuratedSpecialSections,
  ));
}

/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuratedHomepageCopyWith<$Res> get homepage {
  
  return $CuratedHomepageCopyWith<$Res>(_self.homepage, (value) {
    return _then(_self.copyWith(homepage: value));
  });
}/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuratedGenresPageCopyWith<$Res> get genresPage {
  
  return $CuratedGenresPageCopyWith<$Res>(_self.genresPage, (value) {
    return _then(_self.copyWith(genresPage: value));
  });
}/// Create a copy of CuratedResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CuratedSpecialSectionsCopyWith<$Res> get specialSections {
  
  return $CuratedSpecialSectionsCopyWith<$Res>(_self.specialSections, (value) {
    return _then(_self.copyWith(specialSections: value));
  });
}
}

// dart format on
