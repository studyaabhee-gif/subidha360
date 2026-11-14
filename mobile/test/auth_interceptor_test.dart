import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/core/network/auth_interceptor.dart';
import 'package:subidha360/core/storage/token_storage.dart';

import 'support/memory_token_storage.dart';

/// A fake server whose refresh tokens work once, like the real backend.
class FakeServer implements HttpClientAdapter {
  var validAccess = 'new-access';
  var validRefresh = 'old-refresh';
  var refreshCalls = 0;
  var dataCalls = 0;
  var refreshFailsWithNetworkError = false;
  var alwaysUnauthorized = false;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (options.path == '/v1/auth/refresh') {
      refreshCalls++;
      if (refreshFailsWithNetworkError) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      }
      final sent = (options.data as Map)['refresh_token'];
      if (sent != validRefresh) return _json(401, {});
      validRefresh = 'used-up-$refreshCalls';
      return _json(200, {
        'access_token': validAccess,
        'refresh_token': validRefresh,
      });
    }
    dataCalls++;
    final ok = options.headers['Authorization'] == 'Bearer $validAccess';
    if (alwaysUnauthorized || !ok) return _json(401, {});
    return _json(200, {'ok': true});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeServer server;
  late MemoryTokenStorage storage;
  late Dio dio;
  late int expiredCalls;

  setUp(() {
    server = FakeServer();
    storage = MemoryTokenStorage(
      const Tokens(access: 'expired-access', refresh: 'old-refresh'),
    );
    expiredCalls = 0;
    final plain = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server;
    dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = server
      ..interceptors.add(
        AuthInterceptor(
          storage: storage,
          plainDio: plain,
          onSessionExpired: () => expiredCalls++,
        ),
      );
  });

  test('renews an expired token and retries', () async {
    final response = await dio.get<Map<String, dynamic>>('/v1/me');

    expect(response.data!['ok'], isTrue);
    expect(server.refreshCalls, 1);
    expect(storage.tokens!.access, 'new-access');
    expect(expiredCalls, 0);
  });

  test('concurrent failures share one renewal', () async {
    final responses = await Future.wait([
      for (var i = 0; i < 5; i++) dio.get<Map<String, dynamic>>('/v1/jobs/$i'),
    ]);

    expect(responses.every((r) => r.data!['ok'] == true), isTrue);
    expect(server.refreshCalls, 1);
    expect(expiredCalls, 0);
  });

  test('a refused renewal ends the session', () async {
    server.validRefresh = 'something-else';

    await expectLater(dio.get<void>('/v1/me'), throwsA(isA<DioException>()));

    expect(storage.tokens, isNull);
    expect(expiredCalls, 1);
  });

  test('a network failure during renewal keeps the session', () async {
    server.refreshFailsWithNetworkError = true;

    await expectLater(dio.get<void>('/v1/me'), throwsA(isA<DioException>()));

    expect(storage.tokens, isNotNull);
    expect(expiredCalls, 0);
  });

  test('a retry that fails again does not loop', () async {
    server.alwaysUnauthorized = true;

    await expectLater(dio.get<void>('/v1/me'), throwsA(isA<DioException>()));

    expect(server.refreshCalls, 1);
    expect(server.dataCalls, 2);
  });

  test('auth endpoints are never renewed', () async {
    await expectLater(
      dio.post<void>('/v1/auth/otp/verify'),
      throwsA(isA<DioException>()),
    );

    expect(server.refreshCalls, 0);
  });

  test('no stored tokens ends the session', () async {
    storage.tokens = null;

    await expectLater(dio.get<void>('/v1/me'), throwsA(isA<DioException>()));

    expect(server.refreshCalls, 0);
    expect(expiredCalls, 1);
  });
}
