// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WarrantyClaim {

 String get reason; String get status; String get closedNote;
/// Create a copy of WarrantyClaim
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WarrantyClaimCopyWith<WarrantyClaim> get copyWith => _$WarrantyClaimCopyWithImpl<WarrantyClaim>(this as WarrantyClaim, _$identity);

  /// Serializes this WarrantyClaim to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as WarrantyClaim;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WarrantyClaim&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.closedNote, _this.closedNote) || other.closedNote == _this.closedNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as WarrantyClaim;
  return Object.hash(runtimeType,_this.reason,_this.status,_this.closedNote);
}

@override
String toString() {
  final _this = this as WarrantyClaim;
  return 'WarrantyClaim(reason: ${_this.reason}, status: ${_this.status}, closedNote: ${_this.closedNote})';
}


}

/// @nodoc
abstract mixin class $WarrantyClaimCopyWith<$Res>  {
  factory $WarrantyClaimCopyWith(WarrantyClaim value, $Res Function(WarrantyClaim) _then) = _$WarrantyClaimCopyWithImpl;
@useResult
$Res call({
 String reason, String status, String closedNote
});




}
/// @nodoc
class _$WarrantyClaimCopyWithImpl<$Res>
    implements $WarrantyClaimCopyWith<$Res> {
  _$WarrantyClaimCopyWithImpl(this._self, this._then);

  final WarrantyClaim _self;
  final $Res Function(WarrantyClaim) _then;

/// Create a copy of WarrantyClaim
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? reason = null,Object? status = null,Object? closedNote = null,}) {
  return _then(WarrantyClaim(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,closedNote: null == closedNote ? _self.closedNote : closedNote // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WarrantyClaim].
extension WarrantyClaimPatterns on WarrantyClaim {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WarrantyClaim value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WarrantyClaim() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WarrantyClaim value)  $default,){
final _that = this;
switch (_that) {
case _WarrantyClaim():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WarrantyClaim value)?  $default,){
final _that = this;
switch (_that) {
case _WarrantyClaim() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String reason,  String status,  String closedNote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WarrantyClaim() when $default != null:
return $default(_that.reason,_that.status,_that.closedNote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String reason,  String status,  String closedNote)  $default,) {final _that = this;
switch (_that) {
case _WarrantyClaim():
return $default(_that.reason,_that.status,_that.closedNote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String reason,  String status,  String closedNote)?  $default,) {final _that = this;
switch (_that) {
case _WarrantyClaim() when $default != null:
return $default(_that.reason,_that.status,_that.closedNote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WarrantyClaim implements WarrantyClaim {
  const _WarrantyClaim({required this.reason, required this.status, this.closedNote = ''});
  factory _WarrantyClaim.fromJson(Map<String, dynamic> json) => _$WarrantyClaimFromJson(json);

@override final  String reason;
@override final  String status;
@override@JsonKey() final  String closedNote;

/// Create a copy of WarrantyClaim
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WarrantyClaimCopyWith<_WarrantyClaim> get copyWith => __$WarrantyClaimCopyWithImpl<_WarrantyClaim>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WarrantyClaimToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WarrantyClaim&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.status, status) || other.status == status)&&(identical(other.closedNote, closedNote) || other.closedNote == closedNote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,reason,status,closedNote);
}

@override
String toString() {
    return 'WarrantyClaim(reason: $reason, status: $status, closedNote: $closedNote)';
}


}

/// @nodoc
abstract mixin class _$WarrantyClaimCopyWith<$Res> implements $WarrantyClaimCopyWith<$Res> {
  factory _$WarrantyClaimCopyWith(_WarrantyClaim value, $Res Function(_WarrantyClaim) _then) = __$WarrantyClaimCopyWithImpl;
@override @useResult
$Res call({
 String reason, String status, String closedNote
});




}
/// @nodoc
class __$WarrantyClaimCopyWithImpl<$Res>
    implements _$WarrantyClaimCopyWith<$Res> {
  __$WarrantyClaimCopyWithImpl(this._self, this._then);

  final _WarrantyClaim _self;
  final $Res Function(_WarrantyClaim) _then;

/// Create a copy of WarrantyClaim
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? reason = null,Object? status = null,Object? closedNote = null,}) {
  return _then(_WarrantyClaim(
reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,closedNote: null == closedNote ? _self.closedNote : closedNote // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$GeoPoint {

 List<double> get coordinates;
/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GeoPointCopyWith<GeoPoint> get copyWith => _$GeoPointCopyWithImpl<GeoPoint>(this as GeoPoint, _$identity);

  /// Serializes this GeoPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GeoPoint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GeoPoint&&const DeepCollectionEquality().equals(other.coordinates, _this.coordinates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GeoPoint;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.coordinates));
}

@override
String toString() {
  final _this = this as GeoPoint;
  return 'GeoPoint(coordinates: ${_this.coordinates})';
}


}

/// @nodoc
abstract mixin class $GeoPointCopyWith<$Res>  {
  factory $GeoPointCopyWith(GeoPoint value, $Res Function(GeoPoint) _then) = _$GeoPointCopyWithImpl;
@useResult
$Res call({
 List<double> coordinates
});




}
/// @nodoc
class _$GeoPointCopyWithImpl<$Res>
    implements $GeoPointCopyWith<$Res> {
  _$GeoPointCopyWithImpl(this._self, this._then);

  final GeoPoint _self;
  final $Res Function(GeoPoint) _then;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? coordinates = null,}) {
  return _then(GeoPoint(
coordinates: null == coordinates ? _self.coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}

}


/// Adds pattern-matching-related methods to [GeoPoint].
extension GeoPointPatterns on GeoPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GeoPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GeoPoint value)  $default,){
final _that = this;
switch (_that) {
case _GeoPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GeoPoint value)?  $default,){
final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<double> coordinates)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that.coordinates);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<double> coordinates)  $default,) {final _that = this;
switch (_that) {
case _GeoPoint():
return $default(_that.coordinates);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<double> coordinates)?  $default,) {final _that = this;
switch (_that) {
case _GeoPoint() when $default != null:
return $default(_that.coordinates);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GeoPoint extends GeoPoint {
  const _GeoPoint({required  List<double> coordinates}): _coordinates = coordinates,super._();
  factory _GeoPoint.fromJson(Map<String, dynamic> json) => _$GeoPointFromJson(json);

 final  List<double> _coordinates;
@override List<double> get coordinates {
  if (_coordinates is EqualUnmodifiableListView) return _coordinates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_coordinates);
}


/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GeoPointCopyWith<_GeoPoint> get copyWith => __$GeoPointCopyWithImpl<_GeoPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GeoPointToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GeoPoint&&const DeepCollectionEquality().equals(other.coordinates, _coordinates));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_coordinates));
}

@override
String toString() {
    return 'GeoPoint(coordinates: $coordinates)';
}


}

/// @nodoc
abstract mixin class _$GeoPointCopyWith<$Res> implements $GeoPointCopyWith<$Res> {
  factory _$GeoPointCopyWith(_GeoPoint value, $Res Function(_GeoPoint) _then) = __$GeoPointCopyWithImpl;
@override @useResult
$Res call({
 List<double> coordinates
});




}
/// @nodoc
class __$GeoPointCopyWithImpl<$Res>
    implements _$GeoPointCopyWith<$Res> {
  __$GeoPointCopyWithImpl(this._self, this._then);

  final _GeoPoint _self;
  final $Res Function(_GeoPoint) _then;

/// Create a copy of GeoPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? coordinates = null,}) {
  return _then(_GeoPoint(
coordinates: null == coordinates ? _self._coordinates : coordinates // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}


}


/// @nodoc
mixin _$Job {

 String get id; String get seekerId; int get categoryId;@JsonKey(unknownEnumValue: JobStatus.unknown) JobStatus get status; String get description; String get address; int get bidCount; int get escrowAmountPaisa; DateTime get createdAt; String? get providerId; String? get serviceId; String? get preferredDate; String? get preferredSlot; DateTime? get seekerConfirmedAt; DateTime? get providerConfirmedAt; DateTime? get autoReleaseAt; DateTime? get selectionDeadline; DateTime? get completedAt; DateTime? get warrantyEndsAt; WarrantyClaim? get warrantyClaim; GeoPoint? get jobLocation; List<String> get photoIds; int get rescheduleCount; bool get reviewed; bool get escrowReviewRequired;
/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobCopyWith<Job> get copyWith => _$JobCopyWithImpl<Job>(this as Job, _$identity);

  /// Serializes this Job to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Job;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Job&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.seekerId, _this.seekerId) || other.seekerId == _this.seekerId)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.address, _this.address) || other.address == _this.address)&&(identical(other.bidCount, _this.bidCount) || other.bidCount == _this.bidCount)&&(identical(other.escrowAmountPaisa, _this.escrowAmountPaisa) || other.escrowAmountPaisa == _this.escrowAmountPaisa)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.providerId, _this.providerId) || other.providerId == _this.providerId)&&(identical(other.serviceId, _this.serviceId) || other.serviceId == _this.serviceId)&&(identical(other.preferredDate, _this.preferredDate) || other.preferredDate == _this.preferredDate)&&(identical(other.preferredSlot, _this.preferredSlot) || other.preferredSlot == _this.preferredSlot)&&(identical(other.seekerConfirmedAt, _this.seekerConfirmedAt) || other.seekerConfirmedAt == _this.seekerConfirmedAt)&&(identical(other.providerConfirmedAt, _this.providerConfirmedAt) || other.providerConfirmedAt == _this.providerConfirmedAt)&&(identical(other.autoReleaseAt, _this.autoReleaseAt) || other.autoReleaseAt == _this.autoReleaseAt)&&(identical(other.selectionDeadline, _this.selectionDeadline) || other.selectionDeadline == _this.selectionDeadline)&&(identical(other.completedAt, _this.completedAt) || other.completedAt == _this.completedAt)&&(identical(other.warrantyEndsAt, _this.warrantyEndsAt) || other.warrantyEndsAt == _this.warrantyEndsAt)&&(identical(other.warrantyClaim, _this.warrantyClaim) || other.warrantyClaim == _this.warrantyClaim)&&(identical(other.jobLocation, _this.jobLocation) || other.jobLocation == _this.jobLocation)&&const DeepCollectionEquality().equals(other.photoIds, _this.photoIds)&&(identical(other.rescheduleCount, _this.rescheduleCount) || other.rescheduleCount == _this.rescheduleCount)&&(identical(other.reviewed, _this.reviewed) || other.reviewed == _this.reviewed)&&(identical(other.escrowReviewRequired, _this.escrowReviewRequired) || other.escrowReviewRequired == _this.escrowReviewRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Job;
  return Object.hashAll([runtimeType,_this.id,_this.seekerId,_this.categoryId,_this.status,_this.description,_this.address,_this.bidCount,_this.escrowAmountPaisa,_this.createdAt,_this.providerId,_this.serviceId,_this.preferredDate,_this.preferredSlot,_this.seekerConfirmedAt,_this.providerConfirmedAt,_this.autoReleaseAt,_this.selectionDeadline,_this.completedAt,_this.warrantyEndsAt,_this.warrantyClaim,_this.jobLocation,const DeepCollectionEquality().hash(_this.photoIds),_this.rescheduleCount,_this.reviewed,_this.escrowReviewRequired]);
}

@override
String toString() {
  final _this = this as Job;
  return 'Job(id: ${_this.id}, seekerId: ${_this.seekerId}, categoryId: ${_this.categoryId}, status: ${_this.status}, description: ${_this.description}, address: ${_this.address}, bidCount: ${_this.bidCount}, escrowAmountPaisa: ${_this.escrowAmountPaisa}, createdAt: ${_this.createdAt}, providerId: ${_this.providerId}, serviceId: ${_this.serviceId}, preferredDate: ${_this.preferredDate}, preferredSlot: ${_this.preferredSlot}, seekerConfirmedAt: ${_this.seekerConfirmedAt}, providerConfirmedAt: ${_this.providerConfirmedAt}, autoReleaseAt: ${_this.autoReleaseAt}, selectionDeadline: ${_this.selectionDeadline}, completedAt: ${_this.completedAt}, warrantyEndsAt: ${_this.warrantyEndsAt}, warrantyClaim: ${_this.warrantyClaim}, jobLocation: ${_this.jobLocation}, photoIds: ${_this.photoIds}, rescheduleCount: ${_this.rescheduleCount}, reviewed: ${_this.reviewed}, escrowReviewRequired: ${_this.escrowReviewRequired})';
}


}

/// @nodoc
abstract mixin class $JobCopyWith<$Res>  {
  factory $JobCopyWith(Job value, $Res Function(Job) _then) = _$JobCopyWithImpl;
@useResult
$Res call({
 String id, String seekerId, int categoryId,@JsonKey(unknownEnumValue: JobStatus.unknown) JobStatus status, String description, String address, int bidCount, int escrowAmountPaisa, DateTime createdAt, String? providerId, String? serviceId, String? preferredDate, String? preferredSlot, DateTime? seekerConfirmedAt, DateTime? providerConfirmedAt, DateTime? autoReleaseAt, DateTime? selectionDeadline, DateTime? completedAt, DateTime? warrantyEndsAt, WarrantyClaim? warrantyClaim, GeoPoint? jobLocation, List<String> photoIds, int rescheduleCount, bool reviewed, bool escrowReviewRequired
});


$WarrantyClaimCopyWith<$Res>? get warrantyClaim;$GeoPointCopyWith<$Res>? get jobLocation;

}
/// @nodoc
class _$JobCopyWithImpl<$Res>
    implements $JobCopyWith<$Res> {
  _$JobCopyWithImpl(this._self, this._then);

  final Job _self;
  final $Res Function(Job) _then;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? seekerId = null,Object? categoryId = null,Object? status = null,Object? description = null,Object? address = null,Object? bidCount = null,Object? escrowAmountPaisa = null,Object? createdAt = null,Object? providerId = freezed,Object? serviceId = freezed,Object? preferredDate = freezed,Object? preferredSlot = freezed,Object? seekerConfirmedAt = freezed,Object? providerConfirmedAt = freezed,Object? autoReleaseAt = freezed,Object? selectionDeadline = freezed,Object? completedAt = freezed,Object? warrantyEndsAt = freezed,Object? warrantyClaim = freezed,Object? jobLocation = freezed,Object? photoIds = null,Object? rescheduleCount = null,Object? reviewed = null,Object? escrowReviewRequired = null,}) {
  return _then(Job(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seekerId: null == seekerId ? _self.seekerId : seekerId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,bidCount: null == bidCount ? _self.bidCount : bidCount // ignore: cast_nullable_to_non_nullable
as int,escrowAmountPaisa: null == escrowAmountPaisa ? _self.escrowAmountPaisa : escrowAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,providerId: freezed == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String?,serviceId: freezed == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String?,preferredDate: freezed == preferredDate ? _self.preferredDate : preferredDate // ignore: cast_nullable_to_non_nullable
as String?,preferredSlot: freezed == preferredSlot ? _self.preferredSlot : preferredSlot // ignore: cast_nullable_to_non_nullable
as String?,seekerConfirmedAt: freezed == seekerConfirmedAt ? _self.seekerConfirmedAt : seekerConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,providerConfirmedAt: freezed == providerConfirmedAt ? _self.providerConfirmedAt : providerConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,autoReleaseAt: freezed == autoReleaseAt ? _self.autoReleaseAt : autoReleaseAt // ignore: cast_nullable_to_non_nullable
as DateTime?,selectionDeadline: freezed == selectionDeadline ? _self.selectionDeadline : selectionDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,warrantyEndsAt: freezed == warrantyEndsAt ? _self.warrantyEndsAt : warrantyEndsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,warrantyClaim: freezed == warrantyClaim ? _self.warrantyClaim : warrantyClaim // ignore: cast_nullable_to_non_nullable
as WarrantyClaim?,jobLocation: freezed == jobLocation ? _self.jobLocation : jobLocation // ignore: cast_nullable_to_non_nullable
as GeoPoint?,photoIds: null == photoIds ? _self.photoIds : photoIds // ignore: cast_nullable_to_non_nullable
as List<String>,rescheduleCount: null == rescheduleCount ? _self.rescheduleCount : rescheduleCount // ignore: cast_nullable_to_non_nullable
as int,reviewed: null == reviewed ? _self.reviewed : reviewed // ignore: cast_nullable_to_non_nullable
as bool,escrowReviewRequired: null == escrowReviewRequired ? _self.escrowReviewRequired : escrowReviewRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WarrantyClaimCopyWith<$Res>? get warrantyClaim {
    if (_self.warrantyClaim == null) {
    return null;
  }

  return $WarrantyClaimCopyWith<$Res>(_self.warrantyClaim!, (value) {
    return _then(_self.copyWith(warrantyClaim: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get jobLocation {
    if (_self.jobLocation == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.jobLocation!, (value) {
    return _then(_self.copyWith(jobLocation: value));
  });
}
}


/// Adds pattern-matching-related methods to [Job].
extension JobPatterns on Job {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Job value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Job() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Job value)  $default,){
final _that = this;
switch (_that) {
case _Job():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Job value)?  $default,){
final _that = this;
switch (_that) {
case _Job() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String seekerId,  int categoryId, @JsonKey(unknownEnumValue: JobStatus.unknown)  JobStatus status,  String description,  String address,  int bidCount,  int escrowAmountPaisa,  DateTime createdAt,  String? providerId,  String? serviceId,  String? preferredDate,  String? preferredSlot,  DateTime? seekerConfirmedAt,  DateTime? providerConfirmedAt,  DateTime? autoReleaseAt,  DateTime? selectionDeadline,  DateTime? completedAt,  DateTime? warrantyEndsAt,  WarrantyClaim? warrantyClaim,  GeoPoint? jobLocation,  List<String> photoIds,  int rescheduleCount,  bool reviewed,  bool escrowReviewRequired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that.id,_that.seekerId,_that.categoryId,_that.status,_that.description,_that.address,_that.bidCount,_that.escrowAmountPaisa,_that.createdAt,_that.providerId,_that.serviceId,_that.preferredDate,_that.preferredSlot,_that.seekerConfirmedAt,_that.providerConfirmedAt,_that.autoReleaseAt,_that.selectionDeadline,_that.completedAt,_that.warrantyEndsAt,_that.warrantyClaim,_that.jobLocation,_that.photoIds,_that.rescheduleCount,_that.reviewed,_that.escrowReviewRequired);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String seekerId,  int categoryId, @JsonKey(unknownEnumValue: JobStatus.unknown)  JobStatus status,  String description,  String address,  int bidCount,  int escrowAmountPaisa,  DateTime createdAt,  String? providerId,  String? serviceId,  String? preferredDate,  String? preferredSlot,  DateTime? seekerConfirmedAt,  DateTime? providerConfirmedAt,  DateTime? autoReleaseAt,  DateTime? selectionDeadline,  DateTime? completedAt,  DateTime? warrantyEndsAt,  WarrantyClaim? warrantyClaim,  GeoPoint? jobLocation,  List<String> photoIds,  int rescheduleCount,  bool reviewed,  bool escrowReviewRequired)  $default,) {final _that = this;
switch (_that) {
case _Job():
return $default(_that.id,_that.seekerId,_that.categoryId,_that.status,_that.description,_that.address,_that.bidCount,_that.escrowAmountPaisa,_that.createdAt,_that.providerId,_that.serviceId,_that.preferredDate,_that.preferredSlot,_that.seekerConfirmedAt,_that.providerConfirmedAt,_that.autoReleaseAt,_that.selectionDeadline,_that.completedAt,_that.warrantyEndsAt,_that.warrantyClaim,_that.jobLocation,_that.photoIds,_that.rescheduleCount,_that.reviewed,_that.escrowReviewRequired);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String seekerId,  int categoryId, @JsonKey(unknownEnumValue: JobStatus.unknown)  JobStatus status,  String description,  String address,  int bidCount,  int escrowAmountPaisa,  DateTime createdAt,  String? providerId,  String? serviceId,  String? preferredDate,  String? preferredSlot,  DateTime? seekerConfirmedAt,  DateTime? providerConfirmedAt,  DateTime? autoReleaseAt,  DateTime? selectionDeadline,  DateTime? completedAt,  DateTime? warrantyEndsAt,  WarrantyClaim? warrantyClaim,  GeoPoint? jobLocation,  List<String> photoIds,  int rescheduleCount,  bool reviewed,  bool escrowReviewRequired)?  $default,) {final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that.id,_that.seekerId,_that.categoryId,_that.status,_that.description,_that.address,_that.bidCount,_that.escrowAmountPaisa,_that.createdAt,_that.providerId,_that.serviceId,_that.preferredDate,_that.preferredSlot,_that.seekerConfirmedAt,_that.providerConfirmedAt,_that.autoReleaseAt,_that.selectionDeadline,_that.completedAt,_that.warrantyEndsAt,_that.warrantyClaim,_that.jobLocation,_that.photoIds,_that.rescheduleCount,_that.reviewed,_that.escrowReviewRequired);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Job extends Job {
  const _Job({required this.id, required this.seekerId, required this.categoryId, @JsonKey(unknownEnumValue: JobStatus.unknown) required this.status, required this.description, required this.address, required this.bidCount, required this.escrowAmountPaisa, required this.createdAt, this.providerId, this.serviceId, this.preferredDate, this.preferredSlot, this.seekerConfirmedAt, this.providerConfirmedAt, this.autoReleaseAt, this.selectionDeadline, this.completedAt, this.warrantyEndsAt, this.warrantyClaim, this.jobLocation,  List<String> photoIds = const <String>[], this.rescheduleCount = 0, this.reviewed = false, this.escrowReviewRequired = false}): _photoIds = photoIds,super._();
  factory _Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

@override final  String id;
@override final  String seekerId;
@override final  int categoryId;
@override@JsonKey(unknownEnumValue: JobStatus.unknown) final  JobStatus status;
@override final  String description;
@override final  String address;
@override final  int bidCount;
@override final  int escrowAmountPaisa;
@override final  DateTime createdAt;
@override final  String? providerId;
@override final  String? serviceId;
@override final  String? preferredDate;
@override final  String? preferredSlot;
@override final  DateTime? seekerConfirmedAt;
@override final  DateTime? providerConfirmedAt;
@override final  DateTime? autoReleaseAt;
@override final  DateTime? selectionDeadline;
@override final  DateTime? completedAt;
@override final  DateTime? warrantyEndsAt;
@override final  WarrantyClaim? warrantyClaim;
@override final  GeoPoint? jobLocation;
 final  List<String> _photoIds;
@override@JsonKey() List<String> get photoIds {
  if (_photoIds is EqualUnmodifiableListView) return _photoIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photoIds);
}

@override@JsonKey() final  int rescheduleCount;
@override@JsonKey() final  bool reviewed;
@override@JsonKey() final  bool escrowReviewRequired;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobCopyWith<_Job> get copyWith => __$JobCopyWithImpl<_Job>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Job&&(identical(other.id, id) || other.id == id)&&(identical(other.seekerId, seekerId) || other.seekerId == seekerId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.status, status) || other.status == status)&&(identical(other.description, description) || other.description == description)&&(identical(other.address, address) || other.address == address)&&(identical(other.bidCount, bidCount) || other.bidCount == bidCount)&&(identical(other.escrowAmountPaisa, escrowAmountPaisa) || other.escrowAmountPaisa == escrowAmountPaisa)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.preferredDate, preferredDate) || other.preferredDate == preferredDate)&&(identical(other.preferredSlot, preferredSlot) || other.preferredSlot == preferredSlot)&&(identical(other.seekerConfirmedAt, seekerConfirmedAt) || other.seekerConfirmedAt == seekerConfirmedAt)&&(identical(other.providerConfirmedAt, providerConfirmedAt) || other.providerConfirmedAt == providerConfirmedAt)&&(identical(other.autoReleaseAt, autoReleaseAt) || other.autoReleaseAt == autoReleaseAt)&&(identical(other.selectionDeadline, selectionDeadline) || other.selectionDeadline == selectionDeadline)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.warrantyEndsAt, warrantyEndsAt) || other.warrantyEndsAt == warrantyEndsAt)&&(identical(other.warrantyClaim, warrantyClaim) || other.warrantyClaim == warrantyClaim)&&(identical(other.jobLocation, jobLocation) || other.jobLocation == jobLocation)&&const DeepCollectionEquality().equals(other.photoIds, _photoIds)&&(identical(other.rescheduleCount, rescheduleCount) || other.rescheduleCount == rescheduleCount)&&(identical(other.reviewed, reviewed) || other.reviewed == reviewed)&&(identical(other.escrowReviewRequired, escrowReviewRequired) || other.escrowReviewRequired == escrowReviewRequired));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,seekerId,categoryId,status,description,address,bidCount,escrowAmountPaisa,createdAt,providerId,serviceId,preferredDate,preferredSlot,seekerConfirmedAt,providerConfirmedAt,autoReleaseAt,selectionDeadline,completedAt,warrantyEndsAt,warrantyClaim,jobLocation,const DeepCollectionEquality().hash(_photoIds),rescheduleCount,reviewed,escrowReviewRequired]);
}

@override
String toString() {
    return 'Job(id: $id, seekerId: $seekerId, categoryId: $categoryId, status: $status, description: $description, address: $address, bidCount: $bidCount, escrowAmountPaisa: $escrowAmountPaisa, createdAt: $createdAt, providerId: $providerId, serviceId: $serviceId, preferredDate: $preferredDate, preferredSlot: $preferredSlot, seekerConfirmedAt: $seekerConfirmedAt, providerConfirmedAt: $providerConfirmedAt, autoReleaseAt: $autoReleaseAt, selectionDeadline: $selectionDeadline, completedAt: $completedAt, warrantyEndsAt: $warrantyEndsAt, warrantyClaim: $warrantyClaim, jobLocation: $jobLocation, photoIds: $photoIds, rescheduleCount: $rescheduleCount, reviewed: $reviewed, escrowReviewRequired: $escrowReviewRequired)';
}


}

/// @nodoc
abstract mixin class _$JobCopyWith<$Res> implements $JobCopyWith<$Res> {
  factory _$JobCopyWith(_Job value, $Res Function(_Job) _then) = __$JobCopyWithImpl;
@override @useResult
$Res call({
 String id, String seekerId, int categoryId,@JsonKey(unknownEnumValue: JobStatus.unknown) JobStatus status, String description, String address, int bidCount, int escrowAmountPaisa, DateTime createdAt, String? providerId, String? serviceId, String? preferredDate, String? preferredSlot, DateTime? seekerConfirmedAt, DateTime? providerConfirmedAt, DateTime? autoReleaseAt, DateTime? selectionDeadline, DateTime? completedAt, DateTime? warrantyEndsAt, WarrantyClaim? warrantyClaim, GeoPoint? jobLocation, List<String> photoIds, int rescheduleCount, bool reviewed, bool escrowReviewRequired
});


@override $WarrantyClaimCopyWith<$Res>? get warrantyClaim;@override $GeoPointCopyWith<$Res>? get jobLocation;

}
/// @nodoc
class __$JobCopyWithImpl<$Res>
    implements _$JobCopyWith<$Res> {
  __$JobCopyWithImpl(this._self, this._then);

  final _Job _self;
  final $Res Function(_Job) _then;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? seekerId = null,Object? categoryId = null,Object? status = null,Object? description = null,Object? address = null,Object? bidCount = null,Object? escrowAmountPaisa = null,Object? createdAt = null,Object? providerId = freezed,Object? serviceId = freezed,Object? preferredDate = freezed,Object? preferredSlot = freezed,Object? seekerConfirmedAt = freezed,Object? providerConfirmedAt = freezed,Object? autoReleaseAt = freezed,Object? selectionDeadline = freezed,Object? completedAt = freezed,Object? warrantyEndsAt = freezed,Object? warrantyClaim = freezed,Object? jobLocation = freezed,Object? photoIds = null,Object? rescheduleCount = null,Object? reviewed = null,Object? escrowReviewRequired = null,}) {
  return _then(_Job(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seekerId: null == seekerId ? _self.seekerId : seekerId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,bidCount: null == bidCount ? _self.bidCount : bidCount // ignore: cast_nullable_to_non_nullable
as int,escrowAmountPaisa: null == escrowAmountPaisa ? _self.escrowAmountPaisa : escrowAmountPaisa // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,providerId: freezed == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String?,serviceId: freezed == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String?,preferredDate: freezed == preferredDate ? _self.preferredDate : preferredDate // ignore: cast_nullable_to_non_nullable
as String?,preferredSlot: freezed == preferredSlot ? _self.preferredSlot : preferredSlot // ignore: cast_nullable_to_non_nullable
as String?,seekerConfirmedAt: freezed == seekerConfirmedAt ? _self.seekerConfirmedAt : seekerConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,providerConfirmedAt: freezed == providerConfirmedAt ? _self.providerConfirmedAt : providerConfirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,autoReleaseAt: freezed == autoReleaseAt ? _self.autoReleaseAt : autoReleaseAt // ignore: cast_nullable_to_non_nullable
as DateTime?,selectionDeadline: freezed == selectionDeadline ? _self.selectionDeadline : selectionDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,warrantyEndsAt: freezed == warrantyEndsAt ? _self.warrantyEndsAt : warrantyEndsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,warrantyClaim: freezed == warrantyClaim ? _self.warrantyClaim : warrantyClaim // ignore: cast_nullable_to_non_nullable
as WarrantyClaim?,jobLocation: freezed == jobLocation ? _self.jobLocation : jobLocation // ignore: cast_nullable_to_non_nullable
as GeoPoint?,photoIds: null == photoIds ? _self._photoIds : photoIds // ignore: cast_nullable_to_non_nullable
as List<String>,rescheduleCount: null == rescheduleCount ? _self.rescheduleCount : rescheduleCount // ignore: cast_nullable_to_non_nullable
as int,reviewed: null == reviewed ? _self.reviewed : reviewed // ignore: cast_nullable_to_non_nullable
as bool,escrowReviewRequired: null == escrowReviewRequired ? _self.escrowReviewRequired : escrowReviewRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WarrantyClaimCopyWith<$Res>? get warrantyClaim {
    if (_self.warrantyClaim == null) {
    return null;
  }

  return $WarrantyClaimCopyWith<$Res>(_self.warrantyClaim!, (value) {
    return _then(_self.copyWith(warrantyClaim: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GeoPointCopyWith<$Res>? get jobLocation {
    if (_self.jobLocation == null) {
    return null;
  }

  return $GeoPointCopyWith<$Res>(_self.jobLocation!, (value) {
    return _then(_self.copyWith(jobLocation: value));
  });
}
}

// dart format on
