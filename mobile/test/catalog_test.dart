import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/core/widgets/photo.dart';
import 'package:subidha360/features/catalog/domain/catalog.dart';
import 'package:subidha360/features/jobs/domain/categories.dart';

CatalogService _service(String id, int categoryId, {bool popular = true}) =>
    CatalogService(
      id: id,
      name: id,
      summary: '',
      categoryId: categoryId,
      guideFromPaisa: 0,
      guideToPaisa: 0,
      popular: popular,
    );

CatalogCategory _category(int id, List<CatalogService> services) =>
    CatalogCategory(
      id: id,
      slug: 'c$id',
      name: 'c$id',
      tagline: '',
      services: services,
    );

void main() {
  test('popularVariety keeps the first popular service of each category', () {
    final catalog = [
      _category(1, [
        _service('hidden', 1, popular: false),
        _service('tap', 1),
        _service('pipe', 1),
      ]),
      _category(2, [_service('fan', 2), _service('wiring', 2)]),
      _category(3, [_service('quiet', 3, popular: false)]),
    ];

    expect(catalog.popularVariety.map((service) => service.id), ['tap', 'fan']);
  });

  test('every category shows its own photo, and the files exist', () {
    final seen = <String>{};
    for (final c in serviceCategories) {
      expect(c.banner, c.photo, reason: c.name);
      expect(seen.add(c.photo), isTrue, reason: '${c.name} reuses a photo');
      expect(File(c.photo).existsSync(), isTrue, reason: c.photo);
    }
    for (final p in [
      Photos.homeVisit,
      Photos.team,
      Photos.providerPhone,
      Photos.providerTools,
    ]) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });
}
