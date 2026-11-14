import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Adds the access token and transparently renews it.
///
/// Refresh tokens work exactly once, so renewals must never overlap. As a
/// [QueuedInterceptor] this handles one failure at a time: when several requests
/// fail together, the first renews and the rest see the token has already
/// changed and simply retry with it.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.plainDio,
    required this.onSessionExpired,
  });

  final TokenStorage storage;

  /// A client without this interceptor, for renewing and retrying. Because
  /// retries bypass this class, a retry that fails again cannot loop.
  final Dio plainDio;
  final void Function() onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await storage.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.access}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final canRenew =
        err.response?.statusCode == 401 &&
        !options.path.startsWith('/v1/auth/');
    if (!canRenew) return handler.next(err);

    final tokens = await storage.read();
    if (tokens == null) {
      onSessionExpired();
      return handler.next(err);
    }

    var access = tokens.access;
    if (options.headers['Authorization'] == 'Bearer $access') {
      try {
        final renewed = await _renew(tokens.refresh);
        access = renewed.access;
      } on DioException catch (renewError) {
        // Only a refusal ends the session. A network failure must not log the
        // user out, and the refresh token may still be good.
        if (renewError.response?.statusCode == 401) {
          await storage.clear();
          onSessionExpired();
        }
        return handler.next(err);
      }
    }

    options.headers['Authorization'] = 'Bearer $access';
    try {
      handler.resolve(await plainDio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<Tokens> _renew(String refreshToken) async {
    final response = await plainDio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refresh_token': refreshToken},
    );
    final tokens = Tokens.fromJson(response.data!);
    await storage.save(tokens);
    return tokens;
  }
}
