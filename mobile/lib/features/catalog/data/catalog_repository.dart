import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/catalog.dart';

part 'catalog_repository.g.dart';

/// Kept alive because the catalogue rarely changes and every page uses it.
@Riverpod(keepAlive: true)
Future<List<CatalogCategory>> catalog(Ref ref) {
  final dio = ref.watch(dioProvider);
  return apiCall(() async {
    final response = await dio.get<List<dynamic>>('/v1/catalog');
    return response.data!
        .map((row) => CatalogCategory.fromJson(row as Map<String, dynamic>))
        .toList();
  });
}
