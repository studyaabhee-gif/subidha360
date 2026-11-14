import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/schedule_picker.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../jobs/domain/categories.dart';
import '../../jobs/domain/job.dart';
import '../../jobs/domain/provider_profile.dart';
import '../../jobs/domain/job_guidance.dart';
import '../../jobs/providers/job_providers.dart';
import '../../provider/data/provider_api.dart';
import '../../provider/domain/provider_models.dart';
import '../../provider/presentation/earnings_screen.dart' show MonthBars;
import '../data/account_api.dart';
import 'dashboard_widgets.dart';
import 'seeker_dashboard.dart' show DashLinkCard;

/// Jobs where the provider has something to do now.
bool needsProvider(Job j) =>
    j.status == JobStatus.accepted ||
    (j.status == JobStatus.inProgress && j.providerConfirmedAt == null);

/// The provider's home: whether they get jobs, what they earn, what needs
/// doing, and what is left to set up.
class ProviderDashboard extends ConsumerWidget {
  const ProviderDashboard({required this.onOpenTab, super.key});

  /// 1 is Find work, 2 is My work.
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final state = ref.watch(myProviderStateProvider).value;
    final feed = ref.watch(jobFeedProvider).value ?? const <Job>[];
    final work = ref.watch(assignedJobsProvider).value ?? const <Job>[];
    final earnings = ref.watch(earningsProvider).value;
    final todo = work.where(needsProvider).toList();
    final live = work.where((j) => j.status.isActive).toList()
      ..sort(
        (a, b) => (a.preferredDate ?? '').compareTo(b.preferredDate ?? ''),
      );
    final first = (user?.displayName ?? '').trim().split(' ').first;
    final detail = user == null
        ? null
        : ref.watch(providerDetailProvider(user.id)).value;
    final profile = detail?.$1;

    return DashboardLayout(
      onRefresh: () async {
        ref.invalidate(myProviderStateProvider);
        ref.invalidate(jobFeedProvider);
        ref.invalidate(assignedJobsProvider);
        ref.invalidate(earningsProvider);
        await ref.read(jobFeedProvider.future);
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            first.isEmpty ? greeting() : '${greeting()}, $first',
            style: context.text.headlineMedium,
          ),
          const SizedBox(height: AppTheme.gapXs),
          Text(
            tr('Here is your work at a glance.'),
            style: context.text.bodyLarge!.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: AppTheme.gapLg),
          _OnlineSwitch(state: state),
        ],
      ),
      main: [
        StatRow(
          children: [
            StatBox(
              icon: Icons.account_balance_wallet_outlined,
              tone: Tone.success,
              label: tr('Ready to withdraw'),
              value: earnings == null
                  ? '…'
                  : earnings.availablePaisa.asRupeesShort,
              onTap: () => context.push('/provider/earnings'),
            ),
            StatBox(
              icon: Icons.trending_up_rounded,
              label: tr('Earned this month'),
              value: earnings == null
                  ? '…'
                  : earnings.thisMonthPaisa.asRupeesShort,
              onTap: () => context.push('/provider/earnings'),
            ),
            StatBox(
              icon: Icons.star_outline_rounded,
              tone: Tone.warning,
              label: profile == null
                  ? tr('Your rating')
                  : profile.hasRating
                  ? tr('Rating from {0} reviews', [profile.reviewCount])
                  : tr('No reviews yet'),
              value: profile == null
                  ? '…'
                  : profile.hasRating
                  ? profile.rating.toStringAsFixed(1)
                  : tr('New'),
            ),
            StatBox(
              icon: Icons.task_alt_rounded,
              tone: Tone.info,
              label: tr('Jobs paid'),
              value: earnings == null ? '…' : '${earnings.jobsPaid}',
              onTap: () => context.push('/provider/earnings'),
            ),
          ],
        ),
        DashSection(
          title: tr('Needs your attention'),
          padded: todo.isEmpty,
          child: todo.isEmpty
              ? QuietNote(tr('Nothing needs you right now.'))
              : Column(
                  children: [
                    for (final j in todo) ActionRow(job: j, seeker: false),
                    const SizedBox(height: AppTheme.gapSm),
                  ],
                ),
        ),
        DashSection(
          title: live.isEmpty
              ? tr('Upcoming work')
              : tr('Upcoming work ({0})', [live.length]),
          action: work.isEmpty ? null : tr('See all'),
          onAction: () => onOpenTab(2),
          child: live.isEmpty
              ? QuietNote(
                  tr('Jobs you win will show here.'),
                  icon: Icons.event_outlined,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final j in live.take(3))
                      JobTrackerCard(job: j, seeker: false),
                  ],
                ),
        ),
        DashSection(
          title: feed.isEmpty
              ? tr('New jobs near you')
              : tr('New jobs near you ({0})', [feed.length]),
          action: feed.isEmpty ? null : tr('See all'),
          onAction: () => onOpenTab(1),
          padded: feed.isEmpty,
          child: feed.isEmpty
              ? QuietNote(
                  state?.online == false
                      ? tr('You are offline, so no new jobs are sent to you.')
                      : tr('New jobs in your area appear here.'),
                  icon: Icons.travel_explore_rounded,
                )
              : Column(
                  children: [
                    for (final j in feed.take(4)) _FeedLine(job: j),
                    const SizedBox(height: AppTheme.gapSm),
                  ],
                ),
        ),
        RecentActivity(onSeeAll: () => onOpenTab(3)),
      ],
      side: [
        _Checklist(
          state: state,
          userId: user?.id ?? '',
          hasName: (user?.displayName ?? '').trim().isNotEmpty,
        ),
        _EarningsCard(earnings: earnings),
        _Reviews(detail: detail),
        DashSection(
          title: tr('How to win more jobs'),
          child: NumberedSteps(
            steps: [
              (
                tr('Bid quickly'),
                tr('Customers often choose from the first few bids.'),
              ),
              (
                tr('Explain your price'),
                tr('Say what is included, such as parts and travel.'),
              ),
              (
                tr('Keep your promises'),
                tr('Arrive on time and confirm the job when it is done.'),
              ),
              (
                tr('Ask for a review'),
                tr('Good ratings put your bids in front of more people.'),
              ),
            ],
          ),
        ),
        DashLinkCard(
          icon: Icons.support_agent_outlined,
          title: tr('Need help?'),
          message: tr(
            'Write to our team about a job, a payment or your account.',
          ),
          onTap: () => context.push('/help'),
        ),
      ],
    );
  }
}

class _OnlineSwitch extends ConsumerStatefulWidget {
  const _OnlineSwitch({required this.state});

  final MyProviderState? state;

  @override
  ConsumerState<_OnlineSwitch> createState() => _OnlineSwitchState();
}

class _OnlineSwitchState extends ConsumerState<_OnlineSwitch> {
  bool? _pending;

  Future<void> _set(bool online) async {
    setState(() => _pending = online);
    try {
      await ref.read(accountApiProvider).setOnline(online);
      ref.invalidate(myProviderStateProvider);
      ref.invalidate(jobFeedProvider);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _pending ?? widget.state?.online ?? true;
    final tone = context.palette.tone(online ? Tone.success : Tone.neutral);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gapLg,
        vertical: AppTheme.gapMd,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Icon(
            online
                ? Icons.wifi_tethering_rounded
                : Icons.do_not_disturb_on_outlined,
            color: tone.foreground,
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? tr('You are online') : tr('You are offline'),
                  style: context.text.titleSmall!.copyWith(
                    color: tone.foreground,
                  ),
                ),
                Text(
                  online
                      ? tr('New jobs near you are sent to you.')
                      : tr(
                          'Turn this on to get new jobs. Jobs you already won are not affected.',
                        ),
                  style: context.text.bodySmall!.copyWith(
                    color: tone.foreground,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: online,
            onChanged: widget.state == null || _pending != null ? null : _set,
          ),
        ],
      ),
    );
  }
}

class _FeedLine extends StatelessWidget {
  const _FeedLine({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final category = categoryOf(job.categoryId);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTheme.gapLg),
      onTap: () => context.push('/jobs/${job.id}'),
      leading: PhotoThumb(category.photo, size: 48),
      title: Text(
        job.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.titleSmall,
      ),
      subtitle: Text(
        '${category.name} · ${job.address} · ${scheduleLabel(job.preferredDate, job.preferredSlot)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        job.bidCount == 1 ? tr('1 bid') : tr('{0} bids', [job.bidCount]),
        style: context.text.labelMedium,
      ),
    );
  }
}

/// What is left to set up, so customers trust the profile.
class _Checklist extends ConsumerWidget {
  const _Checklist({
    required this.state,
    required this.userId,
    required this.hasName,
  });

  final MyProviderState? state;
  final String userId;
  final bool hasName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = state;
    // Until the profile loads, a checklist would wrongly show nothing done.
    if (s == null) return const SizedBox.shrink();
    final photos = userId.isEmpty
        ? 0
        : ref.watch(galleryProvider(userId)).value?.length ?? 0;
    final items = [
      (hasName, tr('Add your name'), '/home'),
      (s.bio.isNotEmpty, tr('Describe your skills'), '/provider-setup'),
      (
        (s.verified || s.checkStatus == CheckStatus.pending),
        tr('Verify your identity'),
        '/provider/verify',
      ),
      (
        s.availability != null,
        tr('Set your working hours'),
        '/provider/availability',
      ),
      (photos > 0, tr('Add photos of past work'), '/provider/gallery'),
    ];
    final done = items.where((i) => i.$1).length;
    if (done == items.length) return const SizedBox.shrink();
    return DashSection(
      title: tr('Finish your profile'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: done / items.length,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppTheme.gapSm),
          Text(
            tr('{0} of {1} done. Complete profiles win more jobs.', [
              done,
              items.length,
            ]),
            style: context.text.bodySmall!.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: AppTheme.gapSm),
          for (final (ok, label, path) in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: ok || path == '/home' ? null : () => context.push(path),
              leading: Icon(
                ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: ok
                    ? context.palette.tone(Tone.success).foreground
                    : context.palette.muted,
              ),
              title: Text(
                label,
                style: context.text.bodyMedium!.copyWith(
                  decoration: ok ? TextDecoration.lineThrough : null,
                  color: ok ? context.palette.muted : null,
                ),
              ),
              trailing: ok || path == '/home'
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    );
  }
}

/// Where the provider's money is, and how it has grown month by month.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings});

  final Earnings? earnings;

  @override
  Widget build(BuildContext context) {
    final e = earnings;
    return DashSection(
      title: tr('Earnings'),
      action: tr('Details'),
      onAction: () => context.push('/provider/earnings'),
      child: e == null
          ? const SkeletonBox(height: 150)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (e.months.isNotEmpty) ...[
                  MonthBars(
                    months: e.months.length > 6
                        ? e.months.sublist(e.months.length - 6)
                        : e.months,
                  ),
                  const SizedBox(height: AppTheme.gapMd),
                ],
                AmountLine(
                  icon: Icons.account_balance_wallet_outlined,
                  label: tr('Ready to withdraw'),
                  paisa: e.availablePaisa,
                  strong: true,
                ),
                AmountLine(
                  icon: Icons.lock_clock_outlined,
                  label: tr('Waiting for customers to confirm'),
                  paisa: e.onHoldPaisa,
                ),
                if (e.withdrawingPaisa > 0)
                  AmountLine(
                    icon: Icons.outbox_outlined,
                    label: tr('Being sent to you'),
                    paisa: e.withdrawingPaisa,
                  ),
                AmountLine(
                  icon: Icons.percent_rounded,
                  label: tr('Service fee paid'),
                  paisa: e.commissionPaidPaisa,
                ),
                const Divider(height: AppTheme.gapLg),
                AmountLine(
                  label: tr('Earned in total'),
                  paisa: e.totalEarnedPaisa,
                  strong: true,
                ),
                const SizedBox(height: AppTheme.gapMd),
                FilledButton.icon(
                  onPressed: e.availablePaisa >= e.minWithdrawalPaisa
                      ? () => context.push('/provider/earnings')
                      : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(tr('Withdraw')),
                ),
                if (e.availablePaisa < e.minWithdrawalPaisa) ...[
                  const SizedBox(height: AppTheme.gapXs),
                  Text(
                    tr('You can withdraw once you have {0}.', [
                      e.minWithdrawalPaisa.asRupeesShort,
                    ]),
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// What customers said most recently.
class _Reviews extends StatelessWidget {
  const _Reviews({required this.detail});

  final (PublicProfile, List<Review>)? detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    if (d == null) return const SizedBox.shrink();
    final (profile, reviews) = d;
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    final star = context.palette.tone(Tone.warning).foreground;
    return DashSection(
      title: profile.hasRating
          ? tr('Reviews ({0})', [profile.reviewCount])
          : tr('Reviews'),
      child: reviews.isEmpty
          ? QuietNote(
              tr('Reviews from your customers will show here.'),
              icon: Icons.star_outline_rounded,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in reviews.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < 5; i++)
                              Icon(
                                i < r.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 16,
                                color: star,
                              ),
                            const SizedBox(width: AppTheme.gapSm),
                            Text(r.createdAt.timeAgo(), style: muted),
                          ],
                        ),
                        if (r.comment.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.comment,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium,
                          ),
                        ],
                        if (r.tags.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(r.tags.map(tr).join(' · '), style: muted),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
