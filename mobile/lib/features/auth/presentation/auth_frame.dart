import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nepal_graphics.dart';
import '../../../core/widgets/photo.dart';

/// Puts sign-in screens beside a photo on desktop, and under one on phones.
class AuthFrame extends StatelessWidget {
  const AuthFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) {
      final short = MediaQuery.sizeOf(context).height < 640;
      return Column(
        children: [
          if (!short) ...[
            const SizedBox(
              height: 150,
              width: double.infinity,
              child: AppPhoto(
                Photos.homeVisit,
                alignment: Alignment(0.15, -0.35),
              ),
            ),
            const DhakaBand(height: 10),
          ],
          Expanded(child: SafeArea(top: false, child: child)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AppPhoto(
                Photos.providerPhone,
                alignment: Alignment(0, -0.4),
              ),
              Positioned(
                left: AppTheme.gapXxl,
                right: AppTheme.gapXxl,
                bottom: AppTheme.gapXxl,
                child: PhotoPanel(
                  child: Text(
                    tr(
                      'Fair quotes from local experts, with your payment safe '
                      'until the work is done.',
                    ),
                    style: context.text.titleLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
