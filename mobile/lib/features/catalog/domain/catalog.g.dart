// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CatalogService _$CatalogServiceFromJson(
  Map<String, dynamic> json,
) => _CatalogService(
  id: json['id'] as String,
  name: json['name'] as String,
  summary: json['summary'] as String,
  categoryId: (json['category_id'] as num).toInt(),
  guideFromPaisa: (json['guide_from_paisa'] as num).toInt(),
  guideToPaisa: (json['guide_to_paisa'] as num).toInt(),
  symptoms:
      (json['symptoms'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  includes:
      (json['includes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  popular: json['popular'] as bool? ?? false,
  nameNe: json['name_ne'] as String? ?? '',
  summaryNe: json['summary_ne'] as String? ?? '',
);

Map<String, dynamic> _$CatalogServiceToJson(_CatalogService instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'summary': instance.summary,
      'category_id': instance.categoryId,
      'guide_from_paisa': instance.guideFromPaisa,
      'guide_to_paisa': instance.guideToPaisa,
      'symptoms': instance.symptoms,
      'includes': instance.includes,
      'popular': instance.popular,
      'name_ne': instance.nameNe,
      'summary_ne': instance.summaryNe,
    };

_CatalogCategory _$CatalogCategoryFromJson(Map<String, dynamic> json) =>
    _CatalogCategory(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      name: json['name'] as String,
      tagline: json['tagline'] as String,
      services: (json['services'] as List<dynamic>)
          .map((e) => CatalogService.fromJson(e as Map<String, dynamic>))
          .toList(),
      nameNe: json['name_ne'] as String? ?? '',
      taglineNe: json['tagline_ne'] as String? ?? '',
    );

Map<String, dynamic> _$CatalogCategoryToJson(_CatalogCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'tagline': instance.tagline,
      'services': instance.services.map((e) => e.toJson()).toList(),
      'name_ne': instance.nameNe,
      'tagline_ne': instance.taglineNe,
    };
