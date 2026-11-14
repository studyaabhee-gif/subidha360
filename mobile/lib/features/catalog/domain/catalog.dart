import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/l10n/tr.dart';

part 'catalog.freezed.dart';
part 'catalog.g.dart';

@freezed
abstract class CatalogService with _$CatalogService {
  const CatalogService._();

  const factory CatalogService({
    required String id,
    required String name,
    required String summary,
    required int categoryId,
    required int guideFromPaisa,
    required int guideToPaisa,
    @Default(<String>[]) List<String> symptoms,
    @Default(<String>[]) List<String> includes,
    @Default(false) bool popular,

    /// Nepali set by an admin. Built-in services have theirs in the app.
    @Default('') String nameNe,
    @Default('') String summaryNe,
  }) = _CatalogService;

  factory CatalogService.fromJson(Map<String, dynamic> json) =>
      _$CatalogServiceFromJson(json);

  String get displayName =>
      appLanguage == AppLanguage.nepali && nameNe.isNotEmpty
      ? nameNe
      : tr(name);

  String get displaySummary =>
      appLanguage == AppLanguage.nepali && summaryNe.isNotEmpty
      ? summaryNe
      : tr(summary);
}

@freezed
abstract class CatalogCategory with _$CatalogCategory {
  const CatalogCategory._();

  const factory CatalogCategory({
    required int id,
    required String slug,
    required String name,
    required String tagline,
    required List<CatalogService> services,
    @Default('') String nameNe,
    @Default('') String taglineNe,
  }) = _CatalogCategory;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) =>
      _$CatalogCategoryFromJson(json);

  String get displayName =>
      appLanguage == AppLanguage.nepali && nameNe.isNotEmpty
      ? nameNe
      : tr(name);

  String get displayTagline =>
      appLanguage == AppLanguage.nepali && taglineNe.isNotEmpty
      ? taglineNe
      : tr(tagline);
}

extension CatalogQueries on List<CatalogCategory> {
  List<CatalogService> get allServices => [
    for (final category in this) ...category.services,
  ];

  List<CatalogService> get popular =>
      allServices.where((service) => service.popular).toList();

  /// One popular service per category, so a row of them looks varied.
  List<CatalogService> get popularVariety {
    final seen = <int>{};
    return popular.where((service) => seen.add(service.categoryId)).toList();
  }

  CatalogService? serviceById(String id) {
    for (final service in allServices) {
      if (service.id == id) return service;
    }
    return null;
  }

  CatalogCategory? categoryBySlug(String slug) {
    for (final category in this) {
      if (category.slug == slug) return category;
    }
    return null;
  }

  /// Finds services by the problem in the person's own words. A name match
  /// outranks a symptom match, which outranks the description or category.
  List<CatalogService> search(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1)
        .toList();
    if (words.isEmpty) return const [];

    final scored = <(int, CatalogService)>[];
    for (final category in this) {
      for (final service in category.services) {
        // Both languages match, so people can search in Nepali.
        final name = '${service.name} ${service.displayName}'.toLowerCase();
        final symptoms = [
          ...service.symptoms,
          ...service.symptoms.map(tr),
        ].join(' ').toLowerCase();
        final other =
            '${service.summary} ${category.name} '
                    '${service.displaySummary} ${category.displayName}'
                .toLowerCase();
        var score = 0;
        for (final word in words) {
          if (name.contains(word)) {
            score += 3;
          } else if (symptoms.contains(word)) {
            score += 2;
          } else if (other.contains(word)) {
            score += 1;
          }
        }
        if (score > 0) scored.add((score, service));
      }
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final (_, service) in scored) service];
  }
}
