// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  phoneNumber: json['phone_number'] as String,
  hasProviderProfile: json['has_provider_profile'] as bool,
  displayName: json['display_name'] as String? ?? '',
  isVerified: json['is_verified'] as bool? ?? false,
  isAdmin: json['is_admin'] as bool? ?? false,
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'phone_number': instance.phoneNumber,
  'has_provider_profile': instance.hasProviderProfile,
  'display_name': instance.displayName,
  'is_verified': instance.isVerified,
  'is_admin': instance.isAdmin,
};
