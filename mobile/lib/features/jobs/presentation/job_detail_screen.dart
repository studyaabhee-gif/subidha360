import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/schedule_picker.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/job_repository.dart';
import '../domain/bid.dart';
import '../domain/categories.dart';
import '../domain/job.dart';
import '../domain/job_guidance.dart';
import '../providers/job_providers.dart';
import 'bid_sheet.dart';
import 'favorites_screen.dart';
import 'job_map.dart';
import 'job_progress.dart';
import 'problem_photos.dart';
import 'provider_summary.dart';
import '../../support/presentation/support_screens.dart';
import 'reschedule_sheet.dart';
import 'review_sheet.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  var _busy = false;

  JobRepository get _jobs => ref.read(jobRepositoryProvider);

  void _reload() {
    ref
      ..invalidate(jobDetailProvider(widget.jobId))
      ..invalidate(jobBidsProvider(widget.jobId))
      ..invalidate(myJobsProvider)
      ..invalidate(jobFeedProvider)
      ..invalidate(assignedJobsProvider)
      ..invalidate(walletProvider);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) context.showMessage(done);
    } on ApiException catch (error) {
      if (!mounted) return;
      context.showMessage(
        error.code == 'insufficient_funds'
            ? tr('Your wallet balance is too low. Add money in the Wallet tab.')
            : error.message,
      );
    } finally {
      _reload();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept(Job job, Bid bid) async {
    final yes = await context.confirm(
      title: tr('Accept this bid?'),
      message: tr(
        '{0} moves from your wallet and stays on hold until the job is done. Other bids will be declined.',
        [bid.amountPaisa.asRupees],
      ),
      action: tr('Accept and pay {0}', [bid.amountPaisa.asRupees]),
    );
    if (yes) {
      await _run(
        () => _jobs.acceptBid(job.id, bid.id),
        tr('Provider assigned'),
      );
    }
  }

  Future<void> _bid(Job job) async {
    final draft = await showModalBottomSheet<BidDraft>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const BidSheet(),
    );
    if (draft != null) {
      await _run(() => _jobs.placeBid(job.id, draft), tr('Bid sent'));
    }
  }

  Future<void> _confirm(Job job, {required bool seeker}) async {
    final yes = await context.confirm(
      title: seeker ? tr('Is the job finished?') : tr('Mark as finished?'),
      message: seeker
          ? tr(
              'This tells the provider you are happy. Payment releases once you '
              'have both confirmed, and it cannot be undone.',
            )
          : tr(
              'The seeker will be asked to check the work. Your payment releases '
              'when they confirm, or automatically after 3 days.',
            ),
      action: seeker ? tr('Yes, it is finished') : tr('Mark as finished'),
    );
    if (yes) await _run(() => _jobs.confirm(job.id), tr('Confirmed'));
  }

  Future<void> _dispute(Job job) async {
    final reason = await context.askForText(
      title: tr('Raise a dispute'),
      message: tr(
        'The payment stays on hold while our team reviews what happened.',
      ),
      label: tr('What went wrong?'),
      action: tr('Raise dispute'),
      destructive: true,
    );
    if (reason != null) {
      await _run(() => _jobs.dispute(job.id, reason), tr('Dispute raised'));
    }
  }

  Future<void> _cancel(Job job, {required bool seeker}) async {
    final started = job.status == JobStatus.inProgress;
    final reason = await context.askForText(
      title: tr('Cancel this job?'),
      message: switch ((started, seeker)) {
        (true, true) => tr(
          'Work has started, so the payment is held for review and may be '
          'split with the provider. Repeated cancellations can affect your '
          'account.',
        ),
        (true, false) => tr(
          'The seeker gets a full refund. Repeated cancellations can affect '
          'your account.',
        ),
        _ => tr('Tell us why. Any payment on hold returns to the seeker.'),
      },
      label: tr('Reason for cancelling'),
      action: tr('Cancel job'),
      destructive: true,
    );
    if (reason != null) {
      await _run(() => _jobs.cancel(job.id, reason), tr('Job cancelled'));
    }
  }

  Future<void> _reschedule(Job job) async {
    final time = await showModalBottomSheet<NewTime>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => RescheduleSheet(
        date: job.preferredDate,
        slot: job.preferredSlot,
        assigned: job.providerId != null,
      ),
    );
    if (time != null) {
      await _run(
        () => _jobs.reschedule(job.id, date: time.date, slot: time.slot),
        tr('Time changed'),
      );
    }
  }

  Future<void> _review(Job job) async {
    final draft = await showModalBottomSheet<ReviewDraft>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const ReviewSheet(),
    );
    if (draft != null) {
      await _run(
        () => _jobs.review(
          job.id,
          rating: draft.rating,
          tags: draft.tags,
          comment: draft.comment,
        ),
        tr('Thanks for your review'),
      );
    }
  }

  Future<void> _claim(Job job) async {
    final reason = await context.askForText(
      title: tr('Report a problem'),
      message: tr(
        'Tell us what has gone wrong with the work. Our team will review it '
        'under the 30-day guarantee.',
      ),
      label: tr('What is the problem?'),
      action: tr('Send report'),
    );
    if (reason != null) {
      await _run(() => _jobs.claimWarranty(job.id, reason), tr('Report sent'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDetailProvider(widget.jobId));
    final userId = ref.watch(authControllerProvider).value?.id ?? '';
    final wide = context.isWide;
    final buttons = switch (job) {
      AsyncData(:final value) => _buttons(value, userId),
      _ => const <Widget>[],
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Job details')),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          if (job case AsyncData(:final value))
            PopupMenuButton<String>(
              tooltip: tr('More'),
              onSelected: (choice) => choice == 'help'
                  ? context.push('/help?job=${value.id}')
                  : showReportSheet(context, value.id),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'help',
                  child: Text(tr('Get help with this job')),
                ),
                // Only once both sides are known is there someone to report.
                if ((value.providerId ?? '').isNotEmpty &&
                    (value.seekerId == userId || value.providerId == userId))
                  PopupMenuItem(
                    value: 'report',
                    child: Text(
                      value.seekerId == userId
                          ? tr('Report the provider')
                          : tr('Report the customer'),
                    ),
                  ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: !wide && buttons.isNotEmpty
          ? BottomActionBar(children: buttons)
          : null,
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: switch (job) {
          AsyncData(:final value) => _page(value, userId, buttons),
          AsyncError(:final error) => ListView(
            children: [
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: tr("Couldn't load this job"),
                message: ApiException.from(error).message,
                action: OutlinedButton(
                  onPressed: _reload,
                  child: Text(tr('Try again')),
                ),
              ),
            ],
          ),
          _ => ListView(
            padding: const EdgeInsets.all(AppTheme.gapLg),
            children: const [SkeletonCards(count: 2)],
          ),
        },
      ),
    );
  }

  List<Widget> _buttons(Job job, String userId) {
    final seeker = job.isSeeker(userId);
    final assigned = job.isAssignedProvider(userId);
    final inProgress = job.status == JobStatus.inProgress;
    final hasBid =
        ref.watch(jobBidsProvider(job.id)).value?.isNotEmpty ?? false;
    final confirmed = seeker
        ? job.seekerConfirmedAt != null
        : job.providerConfirmedAt != null;
    final completed = job.status == JobStatus.completed;

    return [
      if (!seeker && job.status.isOpen && !hasBid)
        FilledButton(
          onPressed: _busy ? null : () => _bid(job),
          child: Text(tr('Send a bid')),
        ),
      if (assigned && job.status == JobStatus.accepted)
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(() => _jobs.start(job.id), tr('Work started')),
          child: Text(tr('Start work')),
        ),
      if (inProgress && (seeker || assigned) && !confirmed)
        FilledButton(
          onPressed: _busy ? null : () => _confirm(job, seeker: seeker),
          child: Text(
            seeker ? tr('Confirm job is finished') : tr('Mark as finished'),
          ),
        ),
      if (seeker && completed && !job.reviewed)
        FilledButton(
          onPressed: _busy ? null : () => _review(job),
          child: Text(tr('Rate your provider')),
        ),
      if (job.status.chatOpen && (seeker || assigned))
        OutlinedButton.icon(
          onPressed: () => context.push('/jobs/${job.id}/chat'),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
          label: Text(tr('Messages')),
        ),
      if (inProgress && (seeker || assigned))
        OutlinedButton(
          onPressed: _busy ? null : () => _dispute(job),
          child: Text(tr('Raise a dispute')),
        ),
      if (seeker && job.canClaimWarranty(DateTime.now()))
        OutlinedButton(
          onPressed: _busy ? null : () => _claim(job),
          child: Text(tr('Report a problem')),
        ),
    ];
  }

  Widget _page(Job job, String userId, List<Widget> buttons) {
    final main = _main(job, userId);
    if (!context.isWide) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gapLg,
          AppTheme.gapSm,
          AppTheme.gapLg,
          AppTheme.gapXl,
        ),
        children: main,
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gapXl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    top: AppTheme.gapSm,
                    bottom: AppTheme.gapXl,
                  ),
                  children: main,
                ),
              ),
              const SizedBox(width: AppTheme.gapXl),
              SizedBox(
                width: 340,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppTheme.gapSm),
                  child: _SidePanel(job: job, buttons: buttons),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _main(Job job, String userId) {
    final seeker = job.isSeeker(userId);
    final assigned = job.isAssignedProvider(userId);
    final bids = ref.watch(jobBidsProvider(job.id));
    final hasBid = bids.value?.isNotEmpty ?? false;
    final guidance = guidanceFor(job, seeker: seeker, hasBid: hasBid);
    final category = categoryOf(job.categoryId);
    final step = progressStep(job.status);
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    final canCancel =
        (seeker || assigned) &&
        !job.anyoneConfirmed &&
        (job.status.isOpen ||
            job.status == JobStatus.manualFallback ||
            job.status == JobStatus.accepted ||
            job.status == JobStatus.inProgress);

    Widget fact(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: AppTheme.gapXs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.palette.muted),
          const SizedBox(width: AppTheme.gapXs),
          Expanded(child: Text(text, style: muted)),
        ],
      ),
    );

    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: SizedBox(height: 150, child: AppPhoto(category.banner)),
      ),
      const SizedBox(height: AppTheme.gapMd),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(icon: category.icon),
                const SizedBox(width: AppTheme.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: context.text.titleSmall),
                      Text(
                        tr('Posted {0}', [
                          job.createdAt.timeAgo().toLowerCase(),
                        ]),
                        style: muted,
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Pill(label: job.status.label, tone: job.status.tone),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.gapLg),
            Text(job.description, style: context.text.titleMedium),
            const SizedBox(height: AppTheme.gapXs),
            fact(Icons.place_outlined, job.address),
            fact(
              Icons.event_outlined,
              scheduleLabel(job.preferredDate, job.preferredSlot),
            ),
            if (seeker && job.canReschedule)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _reschedule(job),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: Text(tr('Change time')),
                ),
              ),
            if (step != null) ...[
              const SizedBox(height: AppTheme.gapLg),
              JobProgress(step: step),
            ],
          ],
        ),
      ),
      if (job.photoIds.isNotEmpty || (seeker && job.canChange)) ...[
        const SizedBox(height: AppTheme.gapLg),
        JobPhotos(job: job, seeker: seeker),
      ],
      if (!job.status.finished) ...[
        const SizedBox(height: AppTheme.gapMd),
        JobLocationCard(job: job, seeker: seeker, assigned: assigned),
      ],
      const SizedBox(height: AppTheme.gapMd),
      InfoBanner(
        title: guidance.title,
        message: guidance.message,
        tone: guidance.tone,
        icon: guidance.icon,
      ),
      if (job.warrantyClaim != null) ...[
        const SizedBox(height: AppTheme.gapMd),
        InfoBanner(
          title: job.warrantyClaim!.status == 'OPEN'
              ? tr('Guarantee claim under review')
              : tr('Guarantee claim closed'),
          message: job.warrantyClaim!.closedNote.isNotEmpty
              ? job.warrantyClaim!.closedNote
              : tr('Our team will be in touch about: {0}', [
                  job.warrantyClaim!.reason,
                ]),
          tone: Tone.warning,
          icon: Icons.verified_user_outlined,
        ),
      ],
      if (job.escrowAmountPaisa > 0 && !context.isWide) ...[
        const SizedBox(height: AppTheme.gapMd),
        _PriceCard(job: job, assigned: assigned),
      ],
      if (job.providerId != null && (seeker || assigned) && seeker) ...[
        const SizedBox(height: AppTheme.gapMd),
        _AssignedProvider(providerId: job.providerId!),
      ],
      if (job.status.isOpen || (hasBid && !seeker && !assigned)) ...[
        const SizedBox(height: AppTheme.gapXl),
        _Bids(
          job: job,
          seeker: seeker,
          busy: _busy,
          bids: bids,
          onAccept: (bid) => _accept(job, bid),
        ),
      ],
      if (seeker && job.status.finished) ...[
        const SizedBox(height: AppTheme.gapMd),
        _BookAgain(job: job),
      ],
      if (canCancel) ...[
        const SizedBox(height: AppTheme.gapMd),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => _cancel(job, seeker: seeker),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text(tr('Cancel job')),
          ),
        ),
      ],
    ];
  }
}

/// Starts a new job from this one, so regular work takes a few taps.
class _BookAgain extends StatelessWidget {
  const _BookAgain({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final provider = job.status == JobStatus.completed ? job.providerId : null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Need this again?'), style: context.text.titleSmall),
          const SizedBox(height: AppTheme.gapSm),
          if (provider != null) ...[
            FilledButton(
              onPressed: () =>
                  context.push('/jobs/new?repeat=${job.id}&provider=$provider'),
              child: Text(tr('Ask the same provider')),
            ),
            const SizedBox(height: AppTheme.gapSm),
          ],
          OutlinedButton(
            onPressed: () => context.push('/jobs/new?repeat=${job.id}'),
            child: Text(tr('Book again')),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends ConsumerWidget {
  const _PriceCard({required this.job, required this.assigned});

  final Job job;
  final bool assigned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Agreed price'), style: context.text.titleSmall),
                if (assigned)
                  Text(
                    tr('You receive {0} after the {1}% fee', [
                      providerTakeHome(job.escrowAmountPaisa).asRupees,
                      commissionPercent,
                    ]),
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
              ],
            ),
          ),
          Text(job.escrowAmountPaisa.asRupees, style: context.text.titleLarge),
        ],
      ),
    );
  }
}

class _SidePanel extends ConsumerWidget {
  const _SidePanel({required this.job, required this.buttons});

  final Job job;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authControllerProvider).value?.id ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (job.escrowAmountPaisa > 0) ...[
          _PriceCard(job: job, assigned: job.isAssignedProvider(userId)),
          const SizedBox(height: AppTheme.gapMd),
        ],
        for (final button in buttons) ...[
          button,
          const SizedBox(height: AppTheme.gapSm),
        ],
        if (buttons.isNotEmpty) const SizedBox(height: AppTheme.gapSm),
        InfoBanner(
          title: tr('Protected by Subidha360'),
          message: tr('Payments stay on hold until the job is done.'),
          tone: Tone.brand,
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }
}

class _AssignedProvider extends ConsumerWidget {
  const _AssignedProvider({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(providerDetailProvider(providerId)).value;
    if (detail == null) return const SizedBox.shrink();
    final (profile, _) = detail;
    return AppCard(
      onTap: () => showProviderSheet(context, providerId),
      child: Row(
        children: [
          const IconTile(icon: Icons.person_rounded),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                    ),
                    if (profile.verified) ...const [
                      SizedBox(width: AppTheme.gapXs),
                      VerifiedBadge(),
                    ],
                  ],
                ),
                RatingLabel(profile: profile),
              ],
            ),
          ),
          FavoriteButton(providerId: providerId),
          Icon(Icons.chevron_right_rounded, color: context.palette.muted),
        ],
      ),
    );
  }
}

class _Bids extends StatelessWidget {
  const _Bids({
    required this.job,
    required this.seeker,
    required this.busy,
    required this.bids,
    required this.onAccept,
  });

  final Job job;
  final bool seeker;
  final bool busy;
  final AsyncValue<List<Bid>> bids;
  final void Function(Bid bid) onAccept;

  @override
  Widget build(BuildContext context) {
    final rows = [...?bids.value]
      ..sort((a, b) => a.amountPaisa.compareTo(b.amountPaisa));
    if (bids.isLoading && rows.isEmpty) return const SkeletonCards(count: 1);
    if (rows.isEmpty) {
      return seeker
          ? EmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: tr('No bids yet'),
              message: tr("We'll notify you as soon as a provider responds."),
            )
          : const SizedBox.shrink();
    }
    final canPick = seeker && job.status.isOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          canPick ? tr('Bids') : tr('Your bid'),
          trailing: canPick ? tr('Lowest first') : null,
        ),
        for (final bid in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
            child: _BidCard(
              bid: bid,
              canPick: canPick,
              busy: busy,
              onAccept: () => onAccept(bid),
            ),
          ),
      ],
    );
  }
}

class _BidCard extends StatelessWidget {
  const _BidCard({
    required this.bid,
    required this.canPick,
    required this.busy,
    required this.onAccept,
  });

  final Bid bid;
  final bool canPick;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final provider = bid.provider;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bid.amountPaisa.asRupees,
                      style: context.text.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.gapXs),
                    Pill(
                      label: bid.partsIncluded
                          ? tr('Parts included')
                          : tr('Parts extra'),
                      tone: bid.partsIncluded ? Tone.success : Tone.neutral,
                    ),
                  ],
                ),
              ),
              if (canPick)
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 44),
                  ),
                  onPressed: busy ? null : onAccept,
                  child: Text(tr('Accept')),
                )
              else
                Pill(
                  label: switch (bid.status) {
                    'ACCEPTED' => tr('Accepted'),
                    'REJECTED' => tr('Not chosen'),
                    _ => tr('Pending'),
                  },
                  tone: switch (bid.status) {
                    'ACCEPTED' => Tone.success,
                    'REJECTED' => Tone.neutral,
                    _ => Tone.info,
                  },
                ),
            ],
          ),
          if (bid.note.isNotEmpty) ...[
            const SizedBox(height: AppTheme.gapSm),
            Text(bid.note, style: context.text.bodyMedium),
          ],
          if (provider != null && canPick) ...[
            const SizedBox(height: AppTheme.gapSm),
            const Divider(),
            InkWell(
              onTap: () => showProviderSheet(context, provider.id),
              child: Padding(
                padding: const EdgeInsets.only(top: AppTheme.gapSm),
                child: Row(
                  children: [
                    const IconTile(icon: Icons.person_rounded, size: 36),
                    const SizedBox(width: AppTheme.gapSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  provider.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.titleSmall,
                                ),
                              ),
                              if (provider.verified) ...const [
                                SizedBox(width: AppTheme.gapXs),
                                VerifiedBadge(),
                              ],
                            ],
                          ),
                          RatingLabel(profile: provider),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.palette.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
