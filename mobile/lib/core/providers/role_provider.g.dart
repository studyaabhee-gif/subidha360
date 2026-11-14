// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The active_ui_state from the spec: which side of the app is showing. It
/// lives on the device, while the account behind it stays a single user.

@ProviderFor(ActiveRole)
final activeRoleProvider = ActiveRoleProvider._();

/// The active_ui_state from the spec: which side of the app is showing. It
/// lives on the device, while the account behind it stays a single user.
final class ActiveRoleProvider extends $NotifierProvider<ActiveRole, UiRole> {
  /// The active_ui_state from the spec: which side of the app is showing. It
  /// lives on the device, while the account behind it stays a single user.
  ActiveRoleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeRoleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeRoleHash();

  @$internal
  @override
  ActiveRole create() => ActiveRole();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UiRole value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UiRole>(value),
    );
  }
}

String _$activeRoleHash() => r'c891c0ca3c911fe6e19eaa19d7c7ded2992fa4ac';

/// The active_ui_state from the spec: which side of the app is showing. It
/// lives on the device, while the account behind it stays a single user.

abstract class _$ActiveRole extends $Notifier<UiRole> {
  UiRole build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UiRole, UiRole>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UiRole, UiRole>,
              UiRole,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
