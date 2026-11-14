// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bid.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Bid _$BidFromJson(Map<String, dynamic> json) => _Bid(
  id: json['id'] as String,
  jobId: json['job_id'] as String,
  providerId: json['provider_id'] as String,
  amountPaisa: (json['amount_paisa'] as num).toInt(),
  status: json['status'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  partsIncluded: json['parts_included'] as bool? ?? false,
  note: json['note'] as String? ?? '',
  provider: json['provider'] == null
      ? null
      : PublicProfile.fromJson(json['provider'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BidToJson(_Bid instance) => <String, dynamic>{
  'id': instance.id,
  'job_id': instance.jobId,
  'provider_id': instance.providerId,
  'amount_paisa': instance.amountPaisa,
  'status': instance.status,
  'created_at': instance.createdAt.toIso8601String(),
  'parts_included': instance.partsIncluded,
  'note': instance.note,
  'provider': instance.provider?.toJson(),
};
