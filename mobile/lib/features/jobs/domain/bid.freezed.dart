// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bid.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Bid {

 String get id; String get jobId; String get providerId; int get amountPaisa; String get status; DateTime get createdAt; bool get partsIncluded; String get note; PublicProfile? get provider;
/// Create a copy of Bid
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BidCopyWith<Bid> get copyWith => _$BidCopyWithImpl<Bid>(this as Bid, _$identity);

  /// Serializes this Bid to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Bid;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Bid&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.jobId, _this.jobId) || other.jobId == _this.jobId)&&(identical(other.providerId, _this.providerId) || other.providerId == _this.providerId)&&(identical(other.amountPaisa, _this.amountPaisa) || other.amountPaisa == _this.amountPaisa)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.partsIncluded, _this.partsIncluded) || other.partsIncluded == _this.partsIncluded)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.provider, _this.provider) || other.provider == _this.provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Bid;
  return Object.hash(runtimeType,_this.id,_this.jobId,_this.providerId,_this.amountPaisa,_this.status,_this.createdAt,_this.partsIncluded,_this.note,_this.provider);
}

@override
String toString() {
  final _this = this as Bid;
  return 'Bid(id: ${_this.id}, jobId: ${_this.jobId}, providerId: ${_this.providerId}, amountPaisa: ${_this.amountPaisa}, status: ${_this.status}, createdAt: ${_this.createdAt}, partsIncluded: ${_this.partsIncluded}, note: ${_this.note}, provider: ${_this.provider})';
}


}

/// @nodoc
abstract mixin class $BidCopyWith<$Res>  {
  factory $BidCopyWith(Bid value, $Res Function(Bid) _then) = _$BidCopyWithImpl;
@useResult
$Res call({
 String id, String jobId, String providerId, int amountPaisa, String status, DateTime createdAt, bool partsIncluded, String note, PublicProfile? provider
});


$PublicProfileCopyWith<$Res>? get provider;

}
/// @nodoc
class _$BidCopyWithImpl<$Res>
    implements $BidCopyWith<$Res> {
  _$BidCopyWithImpl(this._self, this._then);

  final Bid _self;
  final $Res Function(Bid) _then;

/// Create a copy of Bid
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? jobId = null,Object? providerId = null,Object? amountPaisa = null,Object? status = null,Object? createdAt = null,Object? partsIncluded = null,Object? note = null,Object? provider = freezed,}) {
  return _then(Bid(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,amountPaisa: null == amountPaisa ? _self.amountPaisa : amountPaisa // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,partsIncluded: null == partsIncluded ? _self.partsIncluded : partsIncluded // ignore: cast_nullable_to_non_nullable
as bool,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as PublicProfile?,
  ));
}
/// Create a copy of Bid
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileCopyWith<$Res>? get provider {
    if (_self.provider == null) {
    return null;
  }

  return $PublicProfileCopyWith<$Res>(_self.provider!, (value) {
    return _then(_self.copyWith(provider: value));
  });
}
}


/// Adds pattern-matching-related methods to [Bid].
extension BidPatterns on Bid {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Bid value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Bid() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Bid value)  $default,){
final _that = this;
switch (_that) {
case _Bid():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Bid value)?  $default,){
final _that = this;
switch (_that) {
case _Bid() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String jobId,  String providerId,  int amountPaisa,  String status,  DateTime createdAt,  bool partsIncluded,  String note,  PublicProfile? provider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Bid() when $default != null:
return $default(_that.id,_that.jobId,_that.providerId,_that.amountPaisa,_that.status,_that.createdAt,_that.partsIncluded,_that.note,_that.provider);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String jobId,  String providerId,  int amountPaisa,  String status,  DateTime createdAt,  bool partsIncluded,  String note,  PublicProfile? provider)  $default,) {final _that = this;
switch (_that) {
case _Bid():
return $default(_that.id,_that.jobId,_that.providerId,_that.amountPaisa,_that.status,_that.createdAt,_that.partsIncluded,_that.note,_that.provider);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String jobId,  String providerId,  int amountPaisa,  String status,  DateTime createdAt,  bool partsIncluded,  String note,  PublicProfile? provider)?  $default,) {final _that = this;
switch (_that) {
case _Bid() when $default != null:
return $default(_that.id,_that.jobId,_that.providerId,_that.amountPaisa,_that.status,_that.createdAt,_that.partsIncluded,_that.note,_that.provider);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Bid implements Bid {
  const _Bid({required this.id, required this.jobId, required this.providerId, required this.amountPaisa, required this.status, required this.createdAt, this.partsIncluded = false, this.note = '', this.provider});
  factory _Bid.fromJson(Map<String, dynamic> json) => _$BidFromJson(json);

@override final  String id;
@override final  String jobId;
@override final  String providerId;
@override final  int amountPaisa;
@override final  String status;
@override final  DateTime createdAt;
@override@JsonKey() final  bool partsIncluded;
@override@JsonKey() final  String note;
@override final  PublicProfile? provider;

/// Create a copy of Bid
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BidCopyWith<_Bid> get copyWith => __$BidCopyWithImpl<_Bid>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BidToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Bid&&(identical(other.id, id) || other.id == id)&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.amountPaisa, amountPaisa) || other.amountPaisa == amountPaisa)&&(identical(other.status, status) || other.status == status)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.partsIncluded, partsIncluded) || other.partsIncluded == partsIncluded)&&(identical(other.note, note) || other.note == note)&&(identical(other.provider, provider) || other.provider == provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,jobId,providerId,amountPaisa,status,createdAt,partsIncluded,note,provider);
}

@override
String toString() {
    return 'Bid(id: $id, jobId: $jobId, providerId: $providerId, amountPaisa: $amountPaisa, status: $status, createdAt: $createdAt, partsIncluded: $partsIncluded, note: $note, provider: $provider)';
}


}

/// @nodoc
abstract mixin class _$BidCopyWith<$Res> implements $BidCopyWith<$Res> {
  factory _$BidCopyWith(_Bid value, $Res Function(_Bid) _then) = __$BidCopyWithImpl;
@override @useResult
$Res call({
 String id, String jobId, String providerId, int amountPaisa, String status, DateTime createdAt, bool partsIncluded, String note, PublicProfile? provider
});


@override $PublicProfileCopyWith<$Res>? get provider;

}
/// @nodoc
class __$BidCopyWithImpl<$Res>
    implements _$BidCopyWith<$Res> {
  __$BidCopyWithImpl(this._self, this._then);

  final _Bid _self;
  final $Res Function(_Bid) _then;

/// Create a copy of Bid
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? jobId = null,Object? providerId = null,Object? amountPaisa = null,Object? status = null,Object? createdAt = null,Object? partsIncluded = null,Object? note = null,Object? provider = freezed,}) {
  return _then(_Bid(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,amountPaisa: null == amountPaisa ? _self.amountPaisa : amountPaisa // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,partsIncluded: null == partsIncluded ? _self.partsIncluded : partsIncluded // ignore: cast_nullable_to_non_nullable
as bool,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as PublicProfile?,
  ));
}

/// Create a copy of Bid
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicProfileCopyWith<$Res>? get provider {
    if (_self.provider == null) {
    return null;
  }

  return $PublicProfileCopyWith<$Res>(_self.provider!, (value) {
    return _then(_self.copyWith(provider: value));
  });
}
}

// dart format on
