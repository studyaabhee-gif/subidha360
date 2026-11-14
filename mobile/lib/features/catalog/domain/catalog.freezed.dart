// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CatalogService {

 String get id; String get name; String get summary; int get categoryId; int get guideFromPaisa; int get guideToPaisa; List<String> get symptoms; List<String> get includes; bool get popular;/// Nepali set by an admin. Built-in services have theirs in the app.
 String get nameNe; String get summaryNe;
/// Create a copy of CatalogService
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogServiceCopyWith<CatalogService> get copyWith => _$CatalogServiceCopyWithImpl<CatalogService>(this as CatalogService, _$identity);

  /// Serializes this CatalogService to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CatalogService;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogService&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.guideFromPaisa, _this.guideFromPaisa) || other.guideFromPaisa == _this.guideFromPaisa)&&(identical(other.guideToPaisa, _this.guideToPaisa) || other.guideToPaisa == _this.guideToPaisa)&&const DeepCollectionEquality().equals(other.symptoms, _this.symptoms)&&const DeepCollectionEquality().equals(other.includes, _this.includes)&&(identical(other.popular, _this.popular) || other.popular == _this.popular)&&(identical(other.nameNe, _this.nameNe) || other.nameNe == _this.nameNe)&&(identical(other.summaryNe, _this.summaryNe) || other.summaryNe == _this.summaryNe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CatalogService;
  return Object.hash(runtimeType,_this.id,_this.name,_this.summary,_this.categoryId,_this.guideFromPaisa,_this.guideToPaisa,const DeepCollectionEquality().hash(_this.symptoms),const DeepCollectionEquality().hash(_this.includes),_this.popular,_this.nameNe,_this.summaryNe);
}

@override
String toString() {
  final _this = this as CatalogService;
  return 'CatalogService(id: ${_this.id}, name: ${_this.name}, summary: ${_this.summary}, categoryId: ${_this.categoryId}, guideFromPaisa: ${_this.guideFromPaisa}, guideToPaisa: ${_this.guideToPaisa}, symptoms: ${_this.symptoms}, includes: ${_this.includes}, popular: ${_this.popular}, nameNe: ${_this.nameNe}, summaryNe: ${_this.summaryNe})';
}


}

/// @nodoc
abstract mixin class $CatalogServiceCopyWith<$Res>  {
  factory $CatalogServiceCopyWith(CatalogService value, $Res Function(CatalogService) _then) = _$CatalogServiceCopyWithImpl;
@useResult
$Res call({
 String id, String name, String summary, int categoryId, int guideFromPaisa, int guideToPaisa, List<String> symptoms, List<String> includes, bool popular, String nameNe, String summaryNe
});




}
/// @nodoc
class _$CatalogServiceCopyWithImpl<$Res>
    implements $CatalogServiceCopyWith<$Res> {
  _$CatalogServiceCopyWithImpl(this._self, this._then);

  final CatalogService _self;
  final $Res Function(CatalogService) _then;

/// Create a copy of CatalogService
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? summary = null,Object? categoryId = null,Object? guideFromPaisa = null,Object? guideToPaisa = null,Object? symptoms = null,Object? includes = null,Object? popular = null,Object? nameNe = null,Object? summaryNe = null,}) {
  return _then(CatalogService(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,guideFromPaisa: null == guideFromPaisa ? _self.guideFromPaisa : guideFromPaisa // ignore: cast_nullable_to_non_nullable
as int,guideToPaisa: null == guideToPaisa ? _self.guideToPaisa : guideToPaisa // ignore: cast_nullable_to_non_nullable
as int,symptoms: null == symptoms ? _self.symptoms : symptoms // ignore: cast_nullable_to_non_nullable
as List<String>,includes: null == includes ? _self.includes : includes // ignore: cast_nullable_to_non_nullable
as List<String>,popular: null == popular ? _self.popular : popular // ignore: cast_nullable_to_non_nullable
as bool,nameNe: null == nameNe ? _self.nameNe : nameNe // ignore: cast_nullable_to_non_nullable
as String,summaryNe: null == summaryNe ? _self.summaryNe : summaryNe // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CatalogService].
extension CatalogServicePatterns on CatalogService {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CatalogService value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CatalogService() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CatalogService value)  $default,){
final _that = this;
switch (_that) {
case _CatalogService():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CatalogService value)?  $default,){
final _that = this;
switch (_that) {
case _CatalogService() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String summary,  int categoryId,  int guideFromPaisa,  int guideToPaisa,  List<String> symptoms,  List<String> includes,  bool popular,  String nameNe,  String summaryNe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CatalogService() when $default != null:
return $default(_that.id,_that.name,_that.summary,_that.categoryId,_that.guideFromPaisa,_that.guideToPaisa,_that.symptoms,_that.includes,_that.popular,_that.nameNe,_that.summaryNe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String summary,  int categoryId,  int guideFromPaisa,  int guideToPaisa,  List<String> symptoms,  List<String> includes,  bool popular,  String nameNe,  String summaryNe)  $default,) {final _that = this;
switch (_that) {
case _CatalogService():
return $default(_that.id,_that.name,_that.summary,_that.categoryId,_that.guideFromPaisa,_that.guideToPaisa,_that.symptoms,_that.includes,_that.popular,_that.nameNe,_that.summaryNe);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String summary,  int categoryId,  int guideFromPaisa,  int guideToPaisa,  List<String> symptoms,  List<String> includes,  bool popular,  String nameNe,  String summaryNe)?  $default,) {final _that = this;
switch (_that) {
case _CatalogService() when $default != null:
return $default(_that.id,_that.name,_that.summary,_that.categoryId,_that.guideFromPaisa,_that.guideToPaisa,_that.symptoms,_that.includes,_that.popular,_that.nameNe,_that.summaryNe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CatalogService extends CatalogService {
  const _CatalogService({required this.id, required this.name, required this.summary, required this.categoryId, required this.guideFromPaisa, required this.guideToPaisa,  List<String> symptoms = const <String>[],  List<String> includes = const <String>[], this.popular = false, this.nameNe = '', this.summaryNe = ''}): _symptoms = symptoms,_includes = includes,super._();
  factory _CatalogService.fromJson(Map<String, dynamic> json) => _$CatalogServiceFromJson(json);

@override final  String id;
@override final  String name;
@override final  String summary;
@override final  int categoryId;
@override final  int guideFromPaisa;
@override final  int guideToPaisa;
 final  List<String> _symptoms;
@override@JsonKey() List<String> get symptoms {
  if (_symptoms is EqualUnmodifiableListView) return _symptoms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_symptoms);
}

 final  List<String> _includes;
@override@JsonKey() List<String> get includes {
  if (_includes is EqualUnmodifiableListView) return _includes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_includes);
}

@override@JsonKey() final  bool popular;
/// Nepali set by an admin. Built-in services have theirs in the app.
@override@JsonKey() final  String nameNe;
@override@JsonKey() final  String summaryNe;

/// Create a copy of CatalogService
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogServiceCopyWith<_CatalogService> get copyWith => __$CatalogServiceCopyWithImpl<_CatalogService>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogServiceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogService&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.guideFromPaisa, guideFromPaisa) || other.guideFromPaisa == guideFromPaisa)&&(identical(other.guideToPaisa, guideToPaisa) || other.guideToPaisa == guideToPaisa)&&const DeepCollectionEquality().equals(other.symptoms, _symptoms)&&const DeepCollectionEquality().equals(other.includes, _includes)&&(identical(other.popular, popular) || other.popular == popular)&&(identical(other.nameNe, nameNe) || other.nameNe == nameNe)&&(identical(other.summaryNe, summaryNe) || other.summaryNe == summaryNe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,summary,categoryId,guideFromPaisa,guideToPaisa,const DeepCollectionEquality().hash(_symptoms),const DeepCollectionEquality().hash(_includes),popular,nameNe,summaryNe);
}

@override
String toString() {
    return 'CatalogService(id: $id, name: $name, summary: $summary, categoryId: $categoryId, guideFromPaisa: $guideFromPaisa, guideToPaisa: $guideToPaisa, symptoms: $symptoms, includes: $includes, popular: $popular, nameNe: $nameNe, summaryNe: $summaryNe)';
}


}

/// @nodoc
abstract mixin class _$CatalogServiceCopyWith<$Res> implements $CatalogServiceCopyWith<$Res> {
  factory _$CatalogServiceCopyWith(_CatalogService value, $Res Function(_CatalogService) _then) = __$CatalogServiceCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String summary, int categoryId, int guideFromPaisa, int guideToPaisa, List<String> symptoms, List<String> includes, bool popular, String nameNe, String summaryNe
});




}
/// @nodoc
class __$CatalogServiceCopyWithImpl<$Res>
    implements _$CatalogServiceCopyWith<$Res> {
  __$CatalogServiceCopyWithImpl(this._self, this._then);

  final _CatalogService _self;
  final $Res Function(_CatalogService) _then;

/// Create a copy of CatalogService
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? summary = null,Object? categoryId = null,Object? guideFromPaisa = null,Object? guideToPaisa = null,Object? symptoms = null,Object? includes = null,Object? popular = null,Object? nameNe = null,Object? summaryNe = null,}) {
  return _then(_CatalogService(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,guideFromPaisa: null == guideFromPaisa ? _self.guideFromPaisa : guideFromPaisa // ignore: cast_nullable_to_non_nullable
as int,guideToPaisa: null == guideToPaisa ? _self.guideToPaisa : guideToPaisa // ignore: cast_nullable_to_non_nullable
as int,symptoms: null == symptoms ? _self._symptoms : symptoms // ignore: cast_nullable_to_non_nullable
as List<String>,includes: null == includes ? _self._includes : includes // ignore: cast_nullable_to_non_nullable
as List<String>,popular: null == popular ? _self.popular : popular // ignore: cast_nullable_to_non_nullable
as bool,nameNe: null == nameNe ? _self.nameNe : nameNe // ignore: cast_nullable_to_non_nullable
as String,summaryNe: null == summaryNe ? _self.summaryNe : summaryNe // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$CatalogCategory {

 int get id; String get slug; String get name; String get tagline; List<CatalogService> get services; String get nameNe; String get taglineNe;
/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogCategoryCopyWith<CatalogCategory> get copyWith => _$CatalogCategoryCopyWithImpl<CatalogCategory>(this as CatalogCategory, _$identity);

  /// Serializes this CatalogCategory to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CatalogCategory;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogCategory&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.slug, _this.slug) || other.slug == _this.slug)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.tagline, _this.tagline) || other.tagline == _this.tagline)&&const DeepCollectionEquality().equals(other.services, _this.services)&&(identical(other.nameNe, _this.nameNe) || other.nameNe == _this.nameNe)&&(identical(other.taglineNe, _this.taglineNe) || other.taglineNe == _this.taglineNe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CatalogCategory;
  return Object.hash(runtimeType,_this.id,_this.slug,_this.name,_this.tagline,const DeepCollectionEquality().hash(_this.services),_this.nameNe,_this.taglineNe);
}

@override
String toString() {
  final _this = this as CatalogCategory;
  return 'CatalogCategory(id: ${_this.id}, slug: ${_this.slug}, name: ${_this.name}, tagline: ${_this.tagline}, services: ${_this.services}, nameNe: ${_this.nameNe}, taglineNe: ${_this.taglineNe})';
}


}

/// @nodoc
abstract mixin class $CatalogCategoryCopyWith<$Res>  {
  factory $CatalogCategoryCopyWith(CatalogCategory value, $Res Function(CatalogCategory) _then) = _$CatalogCategoryCopyWithImpl;
@useResult
$Res call({
 int id, String slug, String name, String tagline, List<CatalogService> services, String nameNe, String taglineNe
});




}
/// @nodoc
class _$CatalogCategoryCopyWithImpl<$Res>
    implements $CatalogCategoryCopyWith<$Res> {
  _$CatalogCategoryCopyWithImpl(this._self, this._then);

  final CatalogCategory _self;
  final $Res Function(CatalogCategory) _then;

/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? tagline = null,Object? services = null,Object? nameNe = null,Object? taglineNe = null,}) {
  return _then(CatalogCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tagline: null == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String,services: null == services ? _self.services : services // ignore: cast_nullable_to_non_nullable
as List<CatalogService>,nameNe: null == nameNe ? _self.nameNe : nameNe // ignore: cast_nullable_to_non_nullable
as String,taglineNe: null == taglineNe ? _self.taglineNe : taglineNe // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CatalogCategory].
extension CatalogCategoryPatterns on CatalogCategory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CatalogCategory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CatalogCategory value)  $default,){
final _that = this;
switch (_that) {
case _CatalogCategory():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CatalogCategory value)?  $default,){
final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String slug,  String name,  String tagline,  List<CatalogService> services,  String nameNe,  String taglineNe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.tagline,_that.services,_that.nameNe,_that.taglineNe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String slug,  String name,  String tagline,  List<CatalogService> services,  String nameNe,  String taglineNe)  $default,) {final _that = this;
switch (_that) {
case _CatalogCategory():
return $default(_that.id,_that.slug,_that.name,_that.tagline,_that.services,_that.nameNe,_that.taglineNe);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String slug,  String name,  String tagline,  List<CatalogService> services,  String nameNe,  String taglineNe)?  $default,) {final _that = this;
switch (_that) {
case _CatalogCategory() when $default != null:
return $default(_that.id,_that.slug,_that.name,_that.tagline,_that.services,_that.nameNe,_that.taglineNe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CatalogCategory extends CatalogCategory {
  const _CatalogCategory({required this.id, required this.slug, required this.name, required this.tagline, required  List<CatalogService> services, this.nameNe = '', this.taglineNe = ''}): _services = services,super._();
  factory _CatalogCategory.fromJson(Map<String, dynamic> json) => _$CatalogCategoryFromJson(json);

@override final  int id;
@override final  String slug;
@override final  String name;
@override final  String tagline;
 final  List<CatalogService> _services;
@override List<CatalogService> get services {
  if (_services is EqualUnmodifiableListView) return _services;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_services);
}

@override@JsonKey() final  String nameNe;
@override@JsonKey() final  String taglineNe;

/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogCategoryCopyWith<_CatalogCategory> get copyWith => __$CatalogCategoryCopyWithImpl<_CatalogCategory>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogCategoryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogCategory&&(identical(other.id, id) || other.id == id)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.name, name) || other.name == name)&&(identical(other.tagline, tagline) || other.tagline == tagline)&&const DeepCollectionEquality().equals(other.services, _services)&&(identical(other.nameNe, nameNe) || other.nameNe == nameNe)&&(identical(other.taglineNe, taglineNe) || other.taglineNe == taglineNe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,slug,name,tagline,const DeepCollectionEquality().hash(_services),nameNe,taglineNe);
}

@override
String toString() {
    return 'CatalogCategory(id: $id, slug: $slug, name: $name, tagline: $tagline, services: $services, nameNe: $nameNe, taglineNe: $taglineNe)';
}


}

/// @nodoc
abstract mixin class _$CatalogCategoryCopyWith<$Res> implements $CatalogCategoryCopyWith<$Res> {
  factory _$CatalogCategoryCopyWith(_CatalogCategory value, $Res Function(_CatalogCategory) _then) = __$CatalogCategoryCopyWithImpl;
@override @useResult
$Res call({
 int id, String slug, String name, String tagline, List<CatalogService> services, String nameNe, String taglineNe
});




}
/// @nodoc
class __$CatalogCategoryCopyWithImpl<$Res>
    implements _$CatalogCategoryCopyWith<$Res> {
  __$CatalogCategoryCopyWithImpl(this._self, this._then);

  final _CatalogCategory _self;
  final $Res Function(_CatalogCategory) _then;

/// Create a copy of CatalogCategory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? slug = null,Object? name = null,Object? tagline = null,Object? services = null,Object? nameNe = null,Object? taglineNe = null,}) {
  return _then(_CatalogCategory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,tagline: null == tagline ? _self.tagline : tagline // ignore: cast_nullable_to_non_nullable
as String,services: null == services ? _self._services : services // ignore: cast_nullable_to_non_nullable
as List<CatalogService>,nameNe: null == nameNe ? _self.nameNe : nameNe // ignore: cast_nullable_to_non_nullable
as String,taglineNe: null == taglineNe ? _self.taglineNe : taglineNe // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
