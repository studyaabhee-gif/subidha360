import 'package:dio/dio.dart';

import '../../core/l10n/tr.dart';

/// An API failure with text that is safe to show the user.
class ApiException implements Exception {
  const ApiException({required this.message, this.code, this.status});

  /// Converts anything thrown by a request. The backend sends
  /// {"error": {"code": ..., "message": ...}}.
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        final body = data['error'] as Map;
        return ApiException(
          message: tr(body['message'] as String? ?? _fallback),
          code: body['code'] as String?,
          status: error.response?.statusCode,
        );
      }
      if (error.response == null) {
        return ApiException(
          message: tr('Could not reach the server. Check your connection.'),
        );
      }
      return ApiException(
        message: tr(_fallback),
        status: error.response?.statusCode,
      );
    }
    return ApiException(message: tr(_fallback));
  }

  static const _fallback = 'Something went wrong. Please try again.';

  final String message;
  final String? code;
  final int? status;

  @override
  String toString() => message;
}

/// Runs a request, turning any failure into an [ApiException].
Future<T> apiCall<T>(Future<T> Function() request) async {
  try {
    return await request();
  } catch (error) {
    throw ApiException.from(error);
  }
}
