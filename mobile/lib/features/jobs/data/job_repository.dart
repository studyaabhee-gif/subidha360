import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/bid.dart';
import '../domain/chat_message.dart';
import '../domain/job.dart';
import '../domain/provider_profile.dart';

part 'job_repository.g.dart';

@Riverpod(keepAlive: true)
JobRepository jobRepository(Ref ref) => JobRepository(ref.watch(dioProvider));

class JobRepository {
  const JobRepository(this._dio);

  final Dio _dio;

  Future<List<Job>> _list(String path) => apiCall(() async {
    final response = await _dio.get<List<dynamic>>(path);
    return response.data!
        .map((row) => Job.fromJson(row as Map<String, dynamic>))
        .toList();
  });

  Future<Job> _action(String path, [Map<String, dynamic>? body]) => apiCall(
    () async {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return Job.fromJson(response.data!);
    },
  );

  Future<List<Job>> myJobs() => _list('/v1/jobs');

  Future<List<Job>> feed() => _list('/v1/jobs/feed');

  Future<List<Job>> assigned() => _list('/v1/jobs/assigned');

  Future<Job> job(String id) => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/jobs/$id');
    return Job.fromJson(response.data!);
  });

  Future<Job> create({
    required int categoryId,
    required String description,
    required String address,
    required double lat,
    required double lng,
    String? serviceId,
    String? preferredDate,
    String? preferredSlot,
    String? preferredProviderId,
  }) => _action('/v1/jobs', {
    'category_id': categoryId,
    'description': description,
    'address': address,
    'lat': lat,
    'lng': lng,
    'service_id': ?serviceId,
    'preferred_date': ?preferredDate,
    'preferred_slot': ?preferredSlot,
    'preferred_provider_id': ?preferredProviderId,
  });

  Future<void> uploadPhoto(String jobId, Uint8List bytes) => apiCall(() async {
    await _dio.post<void>(
      '/v1/jobs/$jobId/photos',
      data: bytes,
      options: Options(contentType: 'application/octet-stream'),
    );
  });

  Future<Uint8List> photo(String jobId, String photoId) => apiCall(() async {
    final response = await _dio.get<List<int>>(
      '/v1/jobs/$jobId/photos/$photoId',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });

  Future<void> deletePhoto(String jobId, String photoId) => apiCall(() async {
    await _dio.delete<void>('/v1/jobs/$jobId/photos/$photoId');
  });

  /// A null date means as soon as possible.
  Future<Job> reschedule(String id, {String? date, String? slot}) => _action(
    '/v1/jobs/$id/reschedule',
    {'preferred_date': date ?? '', 'preferred_slot': slot ?? ''},
  );

  Future<void> shareLocation(String id, double lat, double lng) =>
      apiCall(() async {
        await _dio.put<void>(
          '/v1/jobs/$id/tracking',
          data: {'lat': lat, 'lng': lng},
        );
      });

  Future<void> stopSharing(String id) => apiCall(() async {
    await _dio.delete<void>('/v1/jobs/$id/tracking');
  });

  /// Null when the provider isn't sharing their position.
  Future<LiveLocation?> tracking(String id) => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/jobs/$id/tracking',
    );
    final body = response.data!;
    if (body['active'] != true) return null;
    return LiveLocation(
      lat: (body['lat'] as num).toDouble(),
      lng: (body['lng'] as num).toDouble(),
    );
  });

  Future<List<PublicProfile>> favorites() => apiCall(() async {
    final response = await _dio.get<List<dynamic>>('/v1/me/favorites');
    return response.data!
        .map((row) => PublicProfile.fromJson(row as Map<String, dynamic>))
        .toList();
  });

  Future<void> addFavorite(String providerId) => apiCall(() async {
    await _dio.put<void>('/v1/me/favorites/$providerId');
  });

  Future<void> removeFavorite(String providerId) => apiCall(() async {
    await _dio.delete<void>('/v1/me/favorites/$providerId');
  });

  Future<List<Bid>> bids(String jobId) => apiCall(() async {
    final response = await _dio.get<List<dynamic>>('/v1/jobs/$jobId/bids');
    return response.data!
        .map((row) => Bid.fromJson(row as Map<String, dynamic>))
        .toList();
  });

  Future<void> placeBid(String jobId, BidDraft draft) => apiCall(() async {
    await _dio.post<void>(
      '/v1/jobs/$jobId/bids',
      data: {
        'amount_paisa': draft.amountPaisa,
        'parts_included': draft.partsIncluded,
        'note': draft.note,
      },
    );
  });

  Future<void> acceptBid(String jobId, String bidId) => apiCall(() async {
    await _dio.post<void>('/v1/jobs/$jobId/bids/$bidId/accept');
  });

  Future<Job> start(String id) => _action('/v1/jobs/$id/start');

  Future<Job> confirm(String id) => _action('/v1/jobs/$id/confirm');

  Future<Job> cancel(String id, String reason) =>
      _action('/v1/jobs/$id/cancel', {'reason': reason});

  Future<Job> dispute(String id, String reason) =>
      _action('/v1/jobs/$id/dispute', {'reason': reason});

  Future<Job> claimWarranty(String id, String reason) =>
      _action('/v1/jobs/$id/warranty-claim', {'reason': reason});

  Future<void> review(
    String id, {
    required int rating,
    required List<String> tags,
    required String comment,
  }) => apiCall(() async {
    await _dio.post<void>(
      '/v1/jobs/$id/review',
      data: {'rating': rating, 'tags': tags, 'comment': comment},
    );
  });

  Future<(PublicProfile, List<Review>)> provider(String id) =>
      apiCall(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/v1/providers/$id',
        );
        final body = response.data!;
        return (
          PublicProfile.fromJson(body['profile'] as Map<String, dynamic>),
          (body['reviews'] as List<dynamic>)
              .map((row) => Review.fromJson(row as Map<String, dynamic>))
              .toList(),
        );
      });

  Future<List<ChatMessage>> messages(String jobId) => apiCall(() async {
    final response = await _dio.get<List<dynamic>>('/v1/jobs/$jobId/messages');
    return response.data!
        .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
        .toList();
  });

  Future<void> sendMessage(String jobId, String body) => apiCall(() async {
    await _dio.post<void>('/v1/jobs/$jobId/messages', data: {'body': body});
  });
}
