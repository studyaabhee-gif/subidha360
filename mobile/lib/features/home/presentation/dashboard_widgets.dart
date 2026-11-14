import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/schedule_picker.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../../jobs/domain/job.dart';
import '../../jobs/domain/job_guidance.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/inbox_tab.dart';

/// Lays a dashboard out in a main column and a side column on wide screens,
/// and one column on phones.
class DashboardLayout extends StatelessWidget {
  const DashboardLayout({
    required this.header,
    required this.main,
    required this.side,
    required this.onRefresh,
    super.key,
  });

  final Widget header;
  final List<Widget> main;
  final List<Widget> side;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final wide = context.screenWidth >= 1100;
    final pad = context.isWide ? AppTheme.gapXl : AppTheme.gapLg;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, AppTheme.gapLg, pad, AppTheme.gapXxl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: AppTheme.gapXl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: main,
                          ),
                        ),
                        const SizedBox(width: AppTheme.gapXl),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: side,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    ...main,
                    ...side,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card section of a dashboard.
class DashSection extends StatelessWidget {
  const DashSection({
    required this.title,
    required this.child,
    this.action,
    this.onAction,
    this.padded = true,
    super.key,
  });

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: Material(
        color: context.colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: BorderSide(color: context.palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gapLg,
                AppTheme.gapMd,
                AppTheme.gapSm,
                AppTheme.gapXs,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: context.text.titleMedium)),
                  if (action != null)
                    TextButton(onPressed: onAction, child: Text(action!))
                  else
                    const SizedBox(height: 48),
                ],
              ),
            ),
            if (padded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gapLg,
                  0,
                  AppTheme.gapLg,
                  AppTheme.gapLg,
                ),
                child: child,
              )
            else
              child,
          ],
        ),
      ),
    );
  }
}

/// A small figure, such as a balance or a count.
class StatBox extends StatelessWidget {
  const StatBox({
    required this.label,
    required this.value,
    this.icon,
    this.tone = Tone.brand,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Tone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.gapMd + 2),
      child: Row(
        children: [
          if (icon != null) ...[
            IconTile(icon: icon!, tone: tone, size: 40),
            const SizedBox(width: AppTheme.gapMd),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: context.text.titleLarge),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Places stat boxes side by side, wrapping on narrow screens.
class StatRow extends StatelessWidget {
  const StatRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: LayoutBuilder(
        builder: (context, box) {
          final fitsOneRow = box.maxWidth >= 170.0 * children.length;
          final columns = fitsOneRow ? children.length : 2;
          final width =
              (box.maxWidth - AppTheme.gapMd * (columns - 1)) / columns;
          // An odd box left over on its own row takes the full width.
          final lonely = !fitsOneRow && children.length.isOdd;
          return Wrap(
            spacing: AppTheme.gapMd,
            runSpacing: AppTheme.gapMd,
            children: [
              for (var i = 0; i < children.length; i++)
                SizedBox(
                  width: lonely && i == children.length - 1
                      ? box.maxWidth
                      : width,
                  child: children[i],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One job that needs the person to do something, with what to do.
class ActionRow extends StatelessWidget {
  const ActionRow({required this.job, required this.seeker, super.key});

  final Job job;
  final bool seeker;

  @override
  Widget build(BuildContext context) {
    final g = guidanceFor(job, seeker: seeker, hasBid: true);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.gapLg),
      onTap: () => context.push('/jobs/${job.id}'),
      leading: IconTile(icon: g.icon, tone: g.tone, size: 42),
      title: Text(g.title, style: context.text.titleSmall),
      subtitle: Text(
        '${job.description}\n${g.message}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// A calm line for when a section has nothing in it.
class QuietNote extends StatelessWidget {
  const QuietNote(
    this.text, {
    this.icon = Icons.check_circle_outline,
    super.key,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.muted;
    return Row(
      children: [
        Icon(icon, size: 20, color: muted),
        const SizedBox(width: AppTheme.gapSm),
        Expanded(
          child: Text(
            text,
            style: context.text.bodySmall!.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// "Good morning", "Good afternoon" or "Good evening", for the local time.
String greeting([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 12) return tr('Good morning');
  if (hour < 17) return tr('Good afternoon');
  return tr('Good evening');
}

/// The first letters of a name, for an avatar.
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '';
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

/// The steps every job goes through, so people can see how far along it is.
const _steps = ['Posted', 'Bids in', 'Hired', 'Working', 'Done'];

/// Which of [_steps] a job has reached.
int jobStep(Job j) => switch (j.status) {
  JobStatus.broadcasting ||
  JobStatus.escalating ||
  JobStatus.manualFallback => j.bidCount > 0 ? 1 : 0,
  JobStatus.accepted => 2,
  JobStatus.inProgress || JobStatus.disputed => 3,
  JobStatus.completed => 4,
  _ => 0,
};

/// A row of dots joined by lines, from Posted to Done.
class JobProgress extends StatelessWidget {
  const JobProgress({required this.job, super.key});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final step = jobStep(job);
    final done = context.colors.primary;
    final todo = context.palette.line;
    Widget line(bool reached, {bool hidden = false}) => Expanded(
      child: Container(
        height: 2,
        color: hidden ? Colors.transparent : (reached ? done : todo),
      ),
    );
    return Semantics(
      label: tr('Step {0} of {1}: {2}', [
        step + 1,
        _steps.length,
        tr(_steps[step]),
      ]),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      line(i <= step, hidden: i == 0),
                      Container(
                        width: i == step ? 14 : 10,
                        height: i == step ? 14 : 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= step ? done : context.colors.surface,
                          border: Border.all(
                            color: i <= step ? done : todo,
                            width: 2,
                          ),
                        ),
                      ),
                      line(i < step, hidden: i == _steps.length - 1),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr(_steps[i]),
                      maxLines: 1,
                      style: context.text.labelSmall!.copyWith(
                        color: i == step ? null : context.palette.muted,
                        fontWeight: i == step ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One live job with everything about it at a glance: what, where, when,
/// how far along, the money involved and what happens next.
class JobTrackerCard extends StatelessWidget {
  const JobTrackerCard({required this.job, required this.seeker, super.key});

  final Job job;
  final bool seeker;

  @override
  Widget build(BuildContext context) {
    final category = categoryOf(job.categoryId);
    final g = guidanceFor(job, seeker: seeker, hasBid: true);
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    final deadline = job.seekerMustRespond
        ? job.autoReleaseAt?.timeLeft()
        : (job.status.isOpen ? job.selectionDeadline?.timeLeft() : null);
    final facts = <(IconData, String)>[
      (
        Icons.event_outlined,
        scheduleLabel(job.preferredDate, job.preferredSlot),
      ),
      if (job.status.isOpen || job.status == JobStatus.manualFallback)
        (
          Icons.sell_outlined,
          job.bidCount == 1 ? tr('1 bid') : tr('{0} bids', [job.bidCount]),
        ),
      if (job.escrowAmountPaisa > 0)
        (
          Icons.lock_outline_rounded,
          tr('{0} held safely', [job.escrowAmountPaisa.asRupeesShort]),
        ),
      if (deadline != null) (Icons.timer_outlined, tr('{0} left', [deadline])),
    ];
    final tone = context.palette.tone(g.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapMd),
      child: AppCard(
        onTap: () => context.push('/jobs/${job.id}'),
        padding: const EdgeInsets.all(AppTheme.gapMd + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhotoThumb(category.photo, size: 52),
                const SizedBox(width: AppTheme.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${category.name} · ${job.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.gapSm),
                Pill(label: job.status.label, tone: job.status.tone),
              ],
            ),
            const SizedBox(height: AppTheme.gapMd),
            JobProgress(job: job),
            const SizedBox(height: AppTheme.gapMd),
            Wrap(
              spacing: AppTheme.gapMd,
              runSpacing: AppTheme.gapXs,
              children: [
                for (final (icon, text) in facts)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: context.palette.muted),
                      const SizedBox(width: 4),
                      Text(text, style: muted),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.gapSm),
            Container(
              padding: const EdgeInsets.all(AppTheme.gapSm + 2),
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(g.icon, size: 18, color: tone.foreground),
                  const SizedBox(width: AppTheme.gapSm),
                  Expanded(
                    child: Text(
                      '${g.title}. ${g.message}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall!.copyWith(
                        color: tone.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The latest few notifications.
class RecentActivity extends ConsumerWidget {
  const RecentActivity({required this.onSeeAll, super.key});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inboxProvider).value ?? const [];
    return DashSection(
      title: tr('Recent activity'),
      action: items.isEmpty ? null : tr('See all'),
      onAction: onSeeAll,
      padded: items.isEmpty,
      child: items.isEmpty
          ? QuietNote(
              tr('Bids, bookings and payments will show here as they happen.'),
              icon: Icons.notifications_none_rounded,
            )
          : Column(
              children: [
                for (var i = 0; i < items.length && i < 4; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 70),
                  NotificationRow(item: items[i]),
                ],
              ],
            ),
    );
  }
}

/// Numbered steps, such as how booking works.
class NumberedSteps extends StatelessWidget {
  const NumberedSteps({required this.steps, super.key});

  /// Title and explanation of each step.
  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == steps.length - 1 ? 0 : AppTheme.gapMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: context.colors.primaryContainer,
                  foregroundColor: context.colors.onPrimaryContainer,
                  child: Text('${i + 1}', style: context.text.labelMedium),
                ),
                const SizedBox(width: AppTheme.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$1, style: context.text.titleSmall),
                      Text(
                        steps[i].$2,
                        style: context.text.bodySmall!.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A label and an amount on one line, for money breakdowns.
class AmountLine extends StatelessWidget {
  const AmountLine({
    required this.label,
    required this.paisa,
    this.icon,
    this.strong = false,
    super.key,
  });

  final String label;
  final int paisa;
  final IconData? icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? context.text.titleSmall : context.text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: context.palette.muted),
            const SizedBox(width: AppTheme.gapSm),
          ],
          Expanded(child: Text(label, style: style)),
          Text(paisa.asRupees, style: style),
        ],
      ),
    );
  }
}
