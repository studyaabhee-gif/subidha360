import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../theme/app_theme.dart';
import '../widgets/sheets.dart';

extension ContextHelpers on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  void showMessage(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void showError(Object error) => showMessage(ApiException.from(error).message);

  /// Asks for required text, such as a cancellation reason. Null if dismissed.
  Future<String?> askForText({
    required String title,
    required String message,
    required String label,
    required String action,
    bool destructive = false,
  }) => showModalBottomSheet<String>(
    context: this,
    isScrollControlled: true,
    builder: (_) => TextSheet(
      title: title,
      message: message,
      label: label,
      action: action,
      destructive: destructive,
    ),
  );

  /// Asks before anything that moves money or can't be undone.
  Future<bool> confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: this,
      builder: (_) => ConfirmSheet(
        title: title,
        message: message,
        action: action,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }
}
