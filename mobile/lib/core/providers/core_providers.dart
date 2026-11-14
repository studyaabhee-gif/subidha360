import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../network/auth_interceptor.dart';
import '../storage/token_storage.dart';

part 'core_providers.g.dart';

/// Overridden in main() once preferences have loaded.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError();

@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => const SecureTokenStorage();

/// Fires when the server refuses to renew a session. A signal rather than a
/// direct call, because the auth controller itself depends on [dio].
@Riverpod(keepAlive: true)
ValueNotifier<int> sessionExpiredSignal(Ref ref) {
  final signal = ValueNotifier(0);
  ref.onDispose(signal.dispose);
  return signal;
}

BaseOptions _options() => BaseOptions(
  baseUrl: AppConfig.apiBaseUrl,
  connectTimeout: const Duration(seconds: 15),
  receiveTimeout: const Duration(seconds: 20),
  contentType: Headers.jsonContentType,
);

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final signal = ref.watch(sessionExpiredSignalProvider);
  return Dio(_options())
    ..interceptors.add(
      AuthInterceptor(
        storage: ref.watch(tokenStorageProvider),
        plainDio: Dio(_options()),
        onSessionExpired: () => signal.value++,
      ),
    );
}
