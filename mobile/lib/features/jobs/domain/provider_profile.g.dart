// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PublicProfile _$PublicProfileFromJson(Map<String, dynamic> json) =>
    _PublicProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String? ?? '',
      yearsExperience: (json['years_experience'] as num?)?.toInt() ?? 0,
      verified: json['verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      jobsCompleted: (json['jobs_completed'] as num?)?.toInt() ?? 0,
      categoryIds:
          (json['category_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const <int>[],
      availability: json['availability'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$PublicProfileToJson(_PublicProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'bio': instance.bio,
      'years_experience': instance.yearsExperience,
      'verified': instance.verified,
      'rating': instance.rating,
      'review_count': instance.reviewCount,
      'jobs_completed': instance.jobsCompleted,
      'category_ids': instance.categoryIds,
      'availability': instance.availability,
    };

_Review _$ReviewFromJson(Map<String, dynamic> json) => _Review(
  rating: (json['rating'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  comment: json['comment'] as String? ?? '',
);

Map<String, dynamic> _$ReviewToJson(_Review instance) => <String, dynamic>{
  'rating': instance.rating,
  'created_at': instance.createdAt.toIso8601String(),
  'tags': instance.tags,
  'comment': instance.comment,
};
