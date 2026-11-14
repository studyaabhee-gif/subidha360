import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/role_provider.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

part 'auth_controller.g.dart';

/// The signed-in user, or null when signed out.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  Future<User?> build() async {
    final signal = ref.watch(sessionExpiredSignalProvider);
    void onExpired() => state = const AsyncData(null);
    signal.addListener(onExpired);
    ref.onDispose(() => signal.removeListener(onExpired));

    final tokens = await ref.watch(tokenStorageProvider).read();
    if (tokens == null) return null;
    try {
      return await ref.watch(authRepositoryProvider).me();
    } on ApiException catch (error) {
      if (error.status == 401) return null;
      rethrow;
    }
  }

  Future<void> verifyOtp(String phone, String code) async {
    final (user, tokens) = await ref
        .read(authRepositoryProvider)
        .verifyOtp(phone, code);
    await ref.read(tokenStorageProvider).save(tokens);
    state = AsyncData(user);
  }

  void setUser(User user) => state = AsyncData(user);

  Future<void> logout() async {
    final storage = ref.read(tokenStorageProvider);
    final tokens = await storage.read();
    if (tokens != null) {
      try {
        await ref.read(authRepositoryProvider).logout(tokens.refresh);
      } on ApiException {
        // Signing out on this device must still work when offline.
      }
    }
    await storage.clear();
    await ref.read(activeRoleProvider.notifier).set(UiRole.seeker);
    state = const AsyncData(null);
  }
}
