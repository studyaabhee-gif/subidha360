import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/role_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Switches the whole app between hiring and working.
class RoleSwitch extends ConsumerWidget {
  const RoleSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(AppTheme.gapXs),
      decoration: BoxDecoration(
        color: context.palette.tone(Tone.neutral).background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          for (final (value, label) in [
            (UiRole.seeker, tr('Hire someone')),
            (UiRole.provider, tr('Find work')),
          ])
            Expanded(
              child: _Segment(
                label: label,
                selected: role == value,
                onTap: () => ref.read(activeRoleProvider.notifier).set(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            label,
            style: context.text.labelMedium!.copyWith(
              color: selected
                  ? context.colors.onSurface
                  : context.palette.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
