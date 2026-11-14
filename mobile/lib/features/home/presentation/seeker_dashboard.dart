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
import '../../jobs/domain/job_guidance.dart';
import '../../jobs/providers/job_providers.dart';
import '../../notifications/data/notification_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet.dart';
import 'dashboard_widgets.dart';

/// Jobs where the customer has something to do now.
bool needsSeeker(Job j) =>
    (j.status.isOpen && j.bidCount > 0) ||
    j.status == JobStatus.manualFallback ||
    j.seekerMustRespond;

/// The customer's home: start a job, see what needs doing, and get back to
/// what they use most.
class SeekerDashboard extends ConsumerWidget {
  const SeekerDashboard({required this.onOpenTab, super.key});

  /// Switches the home screen to another tab: 1 is My jobs, 2 is Wallet.
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final jobs = ref.watch(myJobsProvider).value ?? const <Job>[];
    final active = jobs.where((j) => j.status.isActive).toList();
    final todo = active.where(needsSeeker).toList();
    final toReview = jobs
        .where((j) => j.status == JobStatus.completed && !j.reviewed)
        .take(3)
        .toList();
    final upcoming =
        active
            .where(
              (j) =>
                  j.status == JobStatus.accepted ||
                  j.status == JobStatus.inProgress,
            )
            .toList()
          ..sort(
            (a, b) => (a.preferredDate ?? '').compareTo(b.preferredDate ?? ''),
          );
    final bookAgain = <int, Job>{};
    for (final j in jobs.where((j) => j.status == JobStatus.completed)) {
      bookAgain.putIfAbsent(j.categoryId, () => j);
    }
    final completed = jobs.where((j) => j.status == JobStatus.completed);
    final bidsWaiting = active
        .where((j) => j.status.isOpen)
        .fold(0, (sum, j) => sum + j.bidCount);
    final onHold = active.fold(0, (sum, j) => sum + j.escrowAmountPaisa);
    final loaded = ref.watch(myJobsProvider).hasValue;

    return DashboardLayout(
      onRefresh: () async {
        ref.invalidate(walletProvider);
        ref.invalidate(favoritesProvider);
        ref.invalidate(inboxProvider);
        ref.invalidate(myJobsProvider);
        await ref.read(myJobsProvider.future);
      },
      header: _Header(name: user?.displayName ?? ''),
      main: [
        StatRow(
          children: [
            StatBox(
              icon: Icons.assignment_outlined,
              label: tr('Active jobs'),
              value: loaded ? '${active.length}' : '…',
              onTap: () => onOpenTab(1),
            ),
            StatBox(
              icon: Icons.sell_outlined,
              tone: Tone.info,
              label: tr('Bids to compare'),
              value: loaded ? '$bidsWaiting' : '…',
              onTap: () => onOpenTab(1),
            ),
            StatBox(
              icon: Icons.lock_outline_rounded,
              tone: Tone.warning,
              label: tr('Held for jobs'),
              value: loaded ? onHold.asRupeesShort : '…',
              onTap: () => onOpenTab(2),
            ),
            StatBox(
              icon: Icons.task_alt_rounded,
              tone: Tone.success,
              label: tr('Jobs done'),
              value: loaded ? '${completed.length}' : '…',
              onTap: () => onOpenTab(1),
            ),
          ],
        ),
        if (active.isEmpty) const _Services(),
        DashSection(
          title: tr('Needs your attention'),
          padded: todo.isEmpty && toReview.isEmpty,
          child: todo.isEmpty && toReview.isEmpty
              ? QuietNote(tr('Nothing needs you right now.'))
              : Column(
                  children: [
                    for (final j in todo) ActionRow(job: j, seeker: true),
                    for (final j in toReview)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.gapLg,
                        ),
                        onTap: () => context.push('/jobs/${j.id}'),
                        leading: const IconTile(
                          icon: Icons.star_outline_rounded,
                          tone: Tone.warning,
                          size: 42,
                        ),
                        title: Text(
                          tr('Rate your provider'),
                          style: context.text.titleSmall,
                        ),
                        subtitle: Text(
                          j.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    const SizedBox(height: AppTheme.gapSm),
                  ],
                ),
        ),
        DashSection(
          title: active.isEmpty
              ? tr('Your jobs')
              : tr('Your jobs in progress ({0})', [active.length]),
          action: jobs.isEmpty ? null : tr('See all'),
          onAction: () => onOpenTab(1),
          child: active.isEmpty
              ? QuietNote(
                  tr('No jobs in progress. Pick a service above to start one.'),
                  icon: Icons.assignment_outlined,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final j in active.take(3))
                      JobTrackerCard(job: j, seeker: true),
                    if (active.length > 3)
                      TextButton(
                        onPressed: () => onOpenTab(1),
                        child: Text(tr('{0} more jobs', [active.length - 3])),
                      ),
                  ],
                ),
        ),
        if (active.isNotEmpty) const _Services(),
        RecentActivity(onSeeAll: () => onOpenTab(3)),
        if (bookAgain.isNotEmpty)
          DashSection(
            title: tr('Book again'),
            child: Wrap(
              spacing: AppTheme.gapSm,
              runSpacing: AppTheme.gapSm,
              children: [
                for (final j in bookAgain.values.take(4))
                  ActionChip(
                    avatar: Icon(categoryOf(j.categoryId).icon, size: 18),
                    label: Text(categoryOf(j.categoryId).name),
                    onPressed: () => context.push('/jobs/new?repeat=${j.id}'),
                  ),
              ],
            ),
          ),
      ],
      side: [
        _WalletCard(onOpen: () => onOpenTab(2)),
        _RecentPayments(onSeeAll: () => onOpenTab(2)),
        DashSection(
          title: tr('Upcoming visits'),
          child: upcoming.isEmpty
              ? QuietNote(
                  tr('Booked visits will show here.'),
                  icon: Icons.event_outlined,
                )
              : Column(
                  children: [
                    for (final j in upcoming.take(3))
                      InkWell(
                        onTap: () => context.push('/jobs/${j.id}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const IconTile(
                                icon: Icons.event_available_outlined,
                                size: 38,
                              ),
                              const SizedBox(width: AppTheme.gapMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scheduleLabel(
                                        j.preferredDate,
                                        j.preferredSlot,
                                      ),
                                      style: context.text.titleSmall,
                                    ),
                                    Text(
                                      categoryOf(j.categoryId).name,
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
                      ),
                  ],
                ),
        ),
        const _Favourites(),
        if (loaded && completed.isEmpty)
          DashSection(
            title: tr('How Subidha360 works'),
            child: NumberedSteps(
              steps: [
                (
                  tr('Post your job'),
                  tr('Say what needs fixing, where and when. It is free.'),
                ),
                (
                  tr('Compare bids'),
                  tr('Nearby providers send prices. See their ratings first.'),
                ),
                (
                  tr('Pay safely'),
                  tr('Your money is held, not paid, until the work is done.'),
                ),
                (
                  tr('Confirm and rate'),
                  tr('Release the payment when you are happy, then rate.'),
                ),
              ],
            ),
          ),
        _LinkCard(
          icon: Icons.verified_user_outlined,
          tone: Tone.success,
          title: tr('Our 30-day service guarantee'),
          message: tr('You can claim up to 30 days after a job is completed.'),
          onTap: () => context.push('/guarantee'),
        ),
        _LinkCard(
          icon: Icons.support_agent_outlined,
          title: tr('Need help?'),
          message: tr(
            'Write to our team about a job, a payment or your account.',
          ),
          onTap: () => context.push('/help'),
        ),
        if (!(user?.hasProviderProfile ?? true))
          _LinkCard(
            icon: Icons.handyman_rounded,
            tone: Tone.warning,
            title: tr('Earn with Subidha360'),
            message: tr('Become a provider and bid on jobs near you.'),
            onTap: () => context.push('/provider-setup'),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final first = name.trim().split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          first.isEmpty ? greeting() : '${greeting()}, $first',
          style: context.text.headlineMedium,
        ),
        const SizedBox(height: AppTheme.gapXs),
        Text(
          tr('What can we help you with today?'),
          style: context.text.bodyLarge!.copyWith(color: context.palette.muted),
        ),
        const SizedBox(height: AppTheme.gapLg),
        Wrap(
          spacing: AppTheme.gapMd,
          runSpacing: AppTheme.gapMd,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: tr('Describe the problem, like "tap dripping"'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onSubmitted: (text) {
                  if (text.trim().isEmpty) return;
                  context.push(
                    Uri(
                      path: '/services',
                      queryParameters: {'q': text.trim()},
                    ).toString(),
                  );
                },
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: () => context.push('/jobs/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('Post a job')),
            ),
          ],
        ),
      ],
    );
  }
}

/// Every service, so nothing is hidden off the edge of the screen.
class _Services extends StatelessWidget {
  const _Services();

  @override
  Widget build(BuildContext context) {
    return DashSection(
      title: tr('Services'),
      action: tr('Browse all'),
      onAction: () => context.push('/services'),
      child: LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 560 ? 4 : 2;
          final width =
              (box.maxWidth - AppTheme.gapSm * (columns - 1)) / columns;
          return Wrap(
            spacing: AppTheme.gapSm,
            runSpacing: AppTheme.gapSm,
            children: [
              for (final c in serviceCategories)
                SizedBox(
                  width: width,
                  child: PhotoTile(
                    photo: c.photo,
                    title: c.name,
                    aspectRatio: 16 / 10,
                    oneLineTitle: true,
                    onTap: () => context.push('/services/${c.slug}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The last few wallet movements, so nobody has to open the wallet to check
/// a payment went through.
class _RecentPayments extends ConsumerWidget {
  const _RecentPayments({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(walletProvider).value?.transactions ?? const [];
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return DashSection(
      title: tr('Recent payments'),
      action: items.isEmpty ? null : tr('See all'),
      onAction: onSeeAll,
      child: items.isEmpty
          ? QuietNote(
              tr('Money you add, pay and get back shows here.'),
              icon: Icons.receipt_long_outlined,
            )
          : Column(
              children: [
                for (final t in items.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        IconTile(
                          icon: t.amountPaisa >= 0
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          tone: t.amountPaisa >= 0
                              ? Tone.success
                              : Tone.neutral,
                          size: 34,
                        ),
                        const SizedBox(width: AppTheme.gapMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                  transactionLabels[t.transactionType] ??
                                      t.transactionType,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium,
                              ),
                              Text(t.createdAt.timeAgo(), style: muted),
                            ],
                          ),
                        ),
                        Text(
                          '${t.amountPaisa >= 0 ? '+' : '−'}'
                          '${t.amountPaisa.abs().asRupeesShort}',
                          style: context.text.titleSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletProvider).value?.balancePaisa;
    final on = context.colors.onPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Ink(
            padding: const EdgeInsets.all(AppTheme.gapLg + 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.palette.heroStart, context.palette.heroEnd],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Wallet balance'),
                        style: TextStyle(color: on.withValues(alpha: 0.85)),
                      ),
                      const SizedBox(height: AppTheme.gapXs),
                      Text(
                        balance == null ? '…' : balance.asRupees,
                        style: context.text.headlineSmall!.copyWith(color: on),
                      ),
                      const SizedBox(height: AppTheme.gapXs),
                      Text(
                        tr('Payments for jobs are held safely from here.'),
                        style: context.text.bodySmall!.copyWith(
                          color: on.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: on),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Favourites extends ConsumerWidget {
  const _Favourites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(favoritesProvider).value ?? const [];
    return DashSection(
      title: tr('Favourite providers'),
      action: rows.isEmpty ? null : tr('See all'),
      onAction: () => context.push('/favorites'),
      child: rows.isEmpty
          ? QuietNote(
              tr('Tap the heart on a provider you liked to book them again.'),
              icon: Icons.favorite_border_rounded,
            )
          : Column(
              children: [
                for (final p in rows.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: context.colors.primaryContainer,
                      foregroundColor: context.colors.onPrimaryContainer,
                      child: Text(initials(p.name)),
                    ),
                    title: Text(p.name, style: context.text.titleSmall),
                    trailing: TextButton(
                      onPressed: () =>
                          context.push('/jobs/new?provider=${p.id}'),
                      child: Text(tr('Book')),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
    this.tone = Tone.brand,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            IconTile(icon: icon, tone: tone),
            const SizedBox(width: AppTheme.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  Text(
                    message,
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.palette.muted),
          ],
        ),
      ),
    );
  }
}

/// Shared with the provider dashboard.
class DashLinkCard extends _LinkCard {
  const DashLinkCard({
    required super.icon,
    required super.title,
    required super.message,
    required super.onTap,
    super.tone,
    super.key,
  });
}
