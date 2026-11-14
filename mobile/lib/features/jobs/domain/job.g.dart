// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WarrantyClaim _$WarrantyClaimFromJson(Map<String, dynamic> json) =>
    _WarrantyClaim(
      reason: json['reason'] as String,
      status: json['status'] as String,
      closedNote: json['closed_note'] as String? ?? '',
    );

Map<String, dynamic> _$WarrantyClaimToJson(_WarrantyClaim instance) =>
    <String, dynamic>{
      'reason': instance.reason,
      'status': instance.status,
      'closed_note': instance.closedNote,
    };

_GeoPoint _$GeoPointFromJson(Map<String, dynamic> json) => _GeoPoint(
  coordinates: (json['coordinates'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
);

Map<String, dynamic> _$GeoPointToJson(_GeoPoint instance) => <String, dynamic>{
  'coordinates': instance.coordinates,
};

_Job _$JobFromJson(Map<String, dynamic> json) => _Job(
  id: json['id'] as String,
  seekerId: json['seeker_id'] as String,
  categoryId: (json['category_id'] as num).toInt(),
  status: $enumDecode(
    _$JobStatusEnumMap,
    json['status'],
    unknownValue: JobStatus.unknown,
  ),
  description: json['description'] as String,
  address: json['address'] as String,
  bidCount: (json['bid_count'] as num).toInt(),
  escrowAmountPaisa: (json['escrow_amount_paisa'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  providerId: json['provider_id'] as String?,
  serviceId: json['service_id'] as String?,
  preferredDate: json['preferred_date'] as String?,
  preferredSlot: json['preferred_slot'] as String?,
  seekerConfirmedAt: json['seeker_confirmed_at'] == null
      ? null
      : DateTime.parse(json['seeker_confirmed_at'] as String),
  providerConfirmedAt: json['provider_confirmed_at'] == null
      ? null
      : DateTime.parse(json['provider_confirmed_at'] as String),
  autoReleaseAt: json['auto_release_at'] == null
      ? null
      : DateTime.parse(json['auto_release_at'] as String),
  selectionDeadline: json['selection_deadline'] == null
      ? null
      : DateTime.parse(json['selection_deadline'] as String),
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
  warrantyEndsAt: json['warranty_ends_at'] == null
      ? null
      : DateTime.parse(json['warranty_ends_at'] as String),
  warrantyClaim: json['warranty_claim'] == null
      ? null
      : WarrantyClaim.fromJson(json['warranty_claim'] as Map<String, dynamic>),
  jobLocation: json['job_location'] == null
      ? null
      : GeoPoint.fromJson(json['job_location'] as Map<String, dynamic>),
  photoIds:
      (json['photo_ids'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  rescheduleCount: (json['reschedule_count'] as num?)?.toInt() ?? 0,
  reviewed: json['reviewed'] as bool? ?? false,
  escrowReviewRequired: json['escrow_review_required'] as bool? ?? false,
);

Map<String, dynamic> _$JobToJson(_Job instance) => <String, dynamic>{
  'id': instance.id,
  'seeker_id': instance.seekerId,
  'category_id': instance.categoryId,
  'status': _$JobStatusEnumMap[instance.status]!,
  'description': instance.description,
  'address': instance.address,
  'bid_count': instance.bidCount,
  'escrow_amount_paisa': instance.escrowAmountPaisa,
  'created_at': instance.createdAt.toIso8601String(),
  'provider_id': instance.providerId,
  'service_id': instance.serviceId,
  'preferred_date': instance.preferredDate,
  'preferred_slot': instance.preferredSlot,
  'seeker_confirmed_at': instance.seekerConfirmedAt?.toIso8601String(),
  'provider_confirmed_at': instance.providerConfirmedAt?.toIso8601String(),
  'auto_release_at': instance.autoReleaseAt?.toIso8601String(),
  'selection_deadline': instance.selectionDeadline?.toIso8601String(),
  'completed_at': instance.completedAt?.toIso8601String(),
  'warranty_ends_at': instance.warrantyEndsAt?.toIso8601String(),
  'warranty_claim': instance.warrantyClaim?.toJson(),
  'job_location': instance.jobLocation?.toJson(),
  'photo_ids': instance.photoIds,
  'reschedule_count': instance.rescheduleCount,
  'reviewed': instance.reviewed,
  'escrow_review_required': instance.escrowReviewRequired,
};

const _$JobStatusEnumMap = {
  JobStatus.broadcasting: 'BROADCASTING',
  JobStatus.escalating: 'ESCALATING',
  JobStatus.manualFallback: 'MANUAL_FALLBACK',
  JobStatus.accepted: 'ACCEPTED',
  JobStatus.inProgress: 'IN_PROGRESS',
  JobStatus.completed: 'COMPLETED',
  JobStatus.cancelled: 'CANCELLED',
  JobStatus.disputed: 'DISPUTED',
  JobStatus.expired: 'EXPIRED',
  JobStatus.unknown: 'UNKNOWN',
};
