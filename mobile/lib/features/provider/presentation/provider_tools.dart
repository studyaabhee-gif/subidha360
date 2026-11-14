import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/provider_api.dart';
import '../domain/provider_models.dart';
import 'availability_screen.dart';

/// Links from the Profile tab to everything a provider manages.
class ProviderTools extends ConsumerWidget {
  const ProviderTools({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProviderStateProvider).value;
    final (checkLabel, checkTone) = switch (state) {
      null => (null, Tone.neutral),
      MyProviderState(checkStatus: CheckStatus.pending) => (
        tr('Being checked'),
        Tone.warning,
      ),
      MyProviderState(checkStatus: CheckStatus.rejected) => (
        tr('Needs a fix'),
        Tone.danger,
      ),
      MyProviderState(verified: true) => (tr('Verified'), Tone.success),
      _ => (tr('Not verified'), Tone.neutral),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(tr('Your provider tools')),
        _Link(
          icon: Icons.badge_outlined,
          title: tr('Identity check'),
          subtitle: tr('Earn the Verified badge'),
          trailing: checkLabel == null
              ? null
              : Pill(label: checkLabel, tone: checkTone),
          path: '/provider/verify',
        ),
        _Link(
          icon: Icons.payments_outlined,
          title: tr('Earnings'),
          subtitle: tr('What you earned, and withdrawals'),
          path: '/provider/earnings',
        ),
        _Link(
          icon: Icons.event_available_outlined,
          title: tr('Working hours'),
          subtitle: state == null
              ? null
              : availabilitySummary(state.availability),
          path: '/provider/availability',
        ),
        _Link(
          icon: Icons.photo_library_outlined,
          title: tr('Past work'),
          subtitle: tr('Photos customers see on your profile'),
          path: '/provider/gallery',
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.icon,
    required this.title,
    required this.path,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
      child: AppCard(
        onTap: () => context.push(path),
        child: Row(
          children: [
            IconTile(icon: icon),
            const SizedBox(width: AppTheme.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall!.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTheme.gapSm),
              trailing!,
            ],
            Icon(Icons.chevron_right_rounded, color: context.palette.muted),
          ],
        ),
      ),
    );
  }
}
