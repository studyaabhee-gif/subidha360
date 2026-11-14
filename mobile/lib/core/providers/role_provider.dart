import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'core_providers.dart';

part 'role_provider.g.dart';

enum UiRole { seeker, provider }

/// The active_ui_state from the spec: which side of the app is showing. It
/// lives on the device, while the account behind it stays a single user.
@Riverpod(keepAlive: true)
class ActiveRole extends _$ActiveRole {
  static const _key = 'active_ui_state';

  @override
  UiRole build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return saved == UiRole.provider.name ? UiRole.provider : UiRole.seeker;
  }

  Future<void> set(UiRole role) async {
    state = role;
    await ref.read(sharedPreferencesProvider).setString(_key, role.name);
  }
}
