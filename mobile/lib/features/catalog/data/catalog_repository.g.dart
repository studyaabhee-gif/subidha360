// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Kept alive because the catalogue rarely changes and every page uses it.

@ProviderFor(catalog)
final catalogProvider = CatalogProvider._();

/// Kept alive because the catalogue rarely changes and every page uses it.

final class CatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatalogCategory>>,
          List<CatalogCategory>,
          FutureOr<List<CatalogCategory>>
        >
    with
        $FutureModifier<List<CatalogCategory>>,
        $FutureProvider<List<CatalogCategory>> {
  /// Kept alive because the catalogue rarely changes and every page uses it.
  CatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogHash();

  @$internal
  @override
  $FutureProviderElement<List<CatalogCategory>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CatalogCategory>> create(Ref ref) {
    return catalog(ref);
  }
}

String _$catalogHash() => r'fd2abbc8f429a2de9ac22f9ec298698567fc1dda';
