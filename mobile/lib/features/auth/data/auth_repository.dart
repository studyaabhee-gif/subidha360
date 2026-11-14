import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';
import '../../legal/legal_text.dart' show termsVersion;

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepository(ref.watch(dioProvider));

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<void> requestOtp(String phone) => apiCall(() async {
    await _dio.post<void>('/v1/auth/otp/request', data: {'phone': phone});
  });

  Future<(User, Tokens)> verifyOtp(String phone, String code) =>
      apiCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/v1/auth/otp/verify',
          // Logging in agrees to the terms shown on the login screen.
          data: {'phone': phone, 'code': code, 'terms_version': termsVersion},
        );
        final body = response.data!;
        return (
          User.fromJson(body['user'] as Map<String, dynamic>),
          Tokens.fromJson(body['tokens'] as Map<String, dynamic>),
        );
      });

  Future<User> me() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me');
    return User.fromJson(response.data!);
  });

  Future<void> logout(String refreshToken) => apiCall(() async {
    await _dio.post<void>(
      '/v1/auth/logout',
      data: {'refresh_token': refreshToken},
    );
  });

  Future<User> updateName(String name) => apiCall(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/me',
      data: {'display_name': name},
    );
    return User.fromJson(response.data!);
  });

  /// [radiusMeters] around a fixed point, per the spec's static matching.
  Future<User> saveProviderProfile({
    required List<int> categoryIds,
    required double lat,
    required double lng,
    required double radiusMeters,
    String bio = '',
    int yearsExperience = 0,
  }) => apiCall(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/me/provider-profile',
      data: {
        'category_ids': categoryIds,
        'bio': bio,
        'years_experience': yearsExperience,
        'radius': {'lat': lat, 'lng': lng, 'meters': radiusMeters},
      },
    );
    return User.fromJson(response.data!);
  });
}
