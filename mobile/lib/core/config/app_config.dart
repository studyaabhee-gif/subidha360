import 'package:flutter/foundation.dart';

/// Build-time settings. Override with --dart-define=API_BASE_URL=https://...
abstract final class AppConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// The Android emulator reaches the host computer through 10.0.2.2.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
