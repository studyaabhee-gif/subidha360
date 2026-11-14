import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/provider_models.dart';

final providerApiProvider = Provider<ProviderApi>(
  (ref) => ProviderApi(ref.watch(dioProvider)),
);

/// A provider's own tools: identity check, earnings, hours and gallery.
class ProviderApi {
  const ProviderApi(this._dio);

  final Dio _dio;

  static final _binary = Options(contentType: 'application/octet-stream');

  Future<MyProviderState> state() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me');
    return MyProviderState.fromJson(response.data!);
  });

  Future<List<ProviderDocument>> documents() => apiCall(() async {
    final response = await _dio.get<List<dynamic>>('/v1/me/documents');
    return [
      for (final row in response.data!)
        ProviderDocument.fromJson(row as Map<String, dynamic>),
    ];
  });

  Future<void> addDocument(String kind, Uint8List bytes, {String label = ''}) =>
      apiCall(() async {
        await _dio.post<void>(
          '/v1/me/documents',
          queryParameters: {'kind': kind, if (label.isNotEmpty) 'label': label},
          data: bytes,
          options: _binary,
        );
      });

  Future<Uint8List> document(String id) => _bytes('/v1/me/documents/$id');

  Future<void> deleteDocument(String id) => apiCall(() async {
    await _dio.delete<void>('/v1/me/documents/$id');
  });

  Future<void> submitCheck() => apiCall(() async {
    await _dio.post<void>('/v1/me/verification');
  });

  Future<Earnings> earnings() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me/earnings');
    return Earnings.fromJson(response.data!);
  });

  Future<void> withdraw(int amountPaisa, PayoutDestination destination) =>
      apiCall(() async {
        await _dio.post<void>(
          '/v1/me/withdrawals',
          data: {
            'amount_paisa': amountPaisa,
            'destination': destination.toJson(),
          },
        );
      });

  /// Null clears the schedule, so the provider is offered jobs at any time.
  Future<void> setAvailability(Availability? availability) => apiCall(() async {
    if (availability == null) {
      await _dio.delete<void>('/v1/me/availability');
    } else {
      await _dio.put<void>('/v1/me/availability', data: availability.toJson());
    }
  });

  Future<List<GalleryPhoto>> gallery(String providerId) => apiCall(() async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/providers/$providerId/gallery',
    );
    return [
      for (final row in response.data!)
        GalleryPhoto.fromJson(row as Map<String, dynamic>),
    ];
  });

  Future<Uint8List> galleryPhoto(String providerId, String id) =>
      _bytes('/v1/providers/$providerId/gallery/$id');

  Future<void> addGalleryPhoto(Uint8List bytes, String caption) =>
      apiCall(() async {
        await _dio.post<void>(
          '/v1/me/gallery',
          queryParameters: {if (caption.isNotEmpty) 'caption': caption},
          data: bytes,
          options: _binary,
        );
      });

  Future<void> deleteGalleryPhoto(String id) => apiCall(() async {
    await _dio.delete<void>('/v1/me/gallery/$id');
  });

  Future<Uint8List> _bytes(String path) => apiCall(() async {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });
}

final myProviderStateProvider = FutureProvider.autoDispose<MyProviderState>(
  (ref) => ref.watch(providerApiProvider).state(),
);

final myDocumentsProvider = FutureProvider.autoDispose<List<ProviderDocument>>(
  (ref) => ref.watch(providerApiProvider).documents(),
);

final documentBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>(
      (ref, id) => ref.watch(providerApiProvider).document(id),
    );

final earningsProvider = FutureProvider.autoDispose<Earnings>(
  (ref) => ref.watch(providerApiProvider).earnings(),
);

final galleryProvider = FutureProvider.autoDispose
    .family<List<GalleryPhoto>, String>(
      (ref, providerId) => ref.watch(providerApiProvider).gallery(providerId),
    );

final galleryPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, (String, String)>(
      (ref, key) => ref.watch(providerApiProvider).galleryPhoto(key.$1, key.$2),
    );
