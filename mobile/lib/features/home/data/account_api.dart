import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';

final accountApiProvider = Provider<AccountApi>(
  (ref) => AccountApi(ref.watch(dioProvider)),
);

/// A reason the account cannot be deleted yet.
typedef DeletionBlocker = ({String code, String message});

class AccountApi {
  const AccountApi(this._dio);

  final Dio _dio;

  Future<int> unread() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notifications/unread',
    );
    return (response.data!['count'] as num).toInt();
  });

  Future<void> markRead() => apiCall(() async {
    await _dio.post<void>('/v1/notifications/read');
  });

  /// Turns job alerts on or off for a provider.
  Future<void> setOnline(bool online) => apiCall(() async {
    await _dio.put<void>('/v1/me/online', data: {'online': online});
  });

  Future<List<DeletionBlocker>> deletionBlockers() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me/deletion');
    return [
      for (final b in response.data!['blockers'] as List)
        (
          code: (b as Map<String, dynamic>)['code'] as String,
          message: b['message'] as String,
        ),
    ];
  });

  Future<void> deleteAccount() => apiCall(() async {
    await _dio.delete<void>('/v1/me', data: {'confirm': 'DELETE'});
  });
}

/// Unread notifications, checked every minute while the app is open.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  try {
    return await ref.watch(accountApiProvider).unread();
  } on ApiException {
    // A badge is not worth an error on screen.
    return 0;
  }
});
