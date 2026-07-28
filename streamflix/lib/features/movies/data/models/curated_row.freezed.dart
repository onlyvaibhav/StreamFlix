// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'curated_row.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CuratedRow {

@JsonKey(readValue: _readRowTitle) String get title; String? get logo; List<Movie> get items;
/// Create a copy of CuratedRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CuratedRowCopyWith<CuratedRow> get copyWith => _$CuratedRowCopyWithImpl<CuratedRow>(this as CuratedRow, _$identity);

  /// Serializes this CuratedRow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CuratedRow&&(identical(other.title, title) || other.title == title)&&(identical(other.logo, logo) || other.logo == logo)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,logo,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'CuratedRow(title: $title, logo: $logo, items: $items)';
}


}

/// @nodoc
abstract mixin class $CuratedRowCopyWith<$Res>  {
  factory $CuratedRowCopyWith(CuratedRow value, $Res Function(CuratedRow) _then) = _$CuratedRowCopyWithImpl;
@useResult
$Res call({
@JsonKey(readValue: _readRowTitle) String title, String? logo, List<Movie> items
});




}
/// @nodoc
class _$CuratedRowCopyWithImpl<$Res>
    implements $CuratedRowCopyWith<$Res> {
  _$CuratedRowCopyWithImpl(this._self, this._then);

  final CuratedRow _self;
  final $Res Function(CuratedRow) _then;

/// Create a copy of CuratedRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? logo = freezed,Object? items = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Movie>,
  ));
}

}


/// Adds pattern-matching-related methods to [CuratedRow].
extension CuratedRowPatterns on CuratedRow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CuratedRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CuratedRow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CuratedRow value)  $default,){
final _that = this;
switch (_that) {
case _CuratedRow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CuratedRow value)?  $default,){
final _that = this;
switch (_that) {
case _CuratedRow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(readValue: _readRowTitle)  String title,  String? logo,  List<Movie> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CuratedRow() when $default != null:
return $default(_that.title,_that.logo,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(readValue: _readRowTitle)  String title,  String? logo,  List<Movie> items)  $default,) {final _that = this;
switch (_that) {
case _CuratedRow():
return $default(_that.title,_that.logo,_that.items);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(readValue: _readRowTitle)  String title,  String? logo,  List<Movie> items)?  $default,) {final _that = this;
switch (_that) {
case _CuratedRow() when $default != null:
return $default(_that.title,_that.logo,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CuratedRow implements CuratedRow {
  const _CuratedRow({@JsonKey(readValue: _readRowTitle) required this.title, this.logo, final  List<Movie> items = const []}): _items = items;
  factory _CuratedRow.fromJson(Map<String, dynamic> json) => _$CuratedRowFromJson(json);

@override@JsonKey(readValue: _readRowTitle) final  String title;
@override final  String? logo;
 final  List<Movie> _items;
@override@JsonKey() List<Movie> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of CuratedRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CuratedRowCopyWith<_CuratedRow> get copyWith => __$CuratedRowCopyWithImpl<_CuratedRow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CuratedRowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CuratedRow&&(identical(other.title, title) || other.title == title)&&(identical(other.logo, logo) || other.logo == logo)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,logo,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'CuratedRow(title: $title, logo: $logo, items: $items)';
}


}

/// @nodoc
abstract mixin class _$CuratedRowCopyWith<$Res> implements $CuratedRowCopyWith<$Res> {
  factory _$CuratedRowCopyWith(_CuratedRow value, $Res Function(_CuratedRow) _then) = __$CuratedRowCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(readValue: _readRowTitle) String title, String? logo, List<Movie> items
});




}
/// @nodoc
class __$CuratedRowCopyWithImpl<$Res>
    implements _$CuratedRowCopyWith<$Res> {
  __$CuratedRowCopyWithImpl(this._self, this._then);

  final _CuratedRow _self;
  final $Res Function(_CuratedRow) _then;

/// Create a copy of CuratedRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? logo = freezed,Object? items = null,}) {
  return _then(_CuratedRow(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Movie>,
  ));
}


}

// dart format on
