import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../providers/auth_controller.dart';

/// Shown while restoring a session, or when the server can't be reached.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gapXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 76),
              const SizedBox(height: AppTheme.gapLg),
              Wordmark(style: context.text.headlineMedium),
              const SizedBox(height: AppTheme.gapXl),
              if (auth.hasError) ...[
                Text(
                  ApiException.from(auth.error!).message,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: AppTheme.gapLg),
                OutlinedButton(
                  onPressed: () => ref.invalidate(authControllerProvider),
                  child: Text(tr('Try again')),
                ),
              ] else
                const SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
