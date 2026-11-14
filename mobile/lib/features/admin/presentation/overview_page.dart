import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/admin_api.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';

class AdminOverviewPage extends ConsumerWidget {
  const AdminOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(overviewProvider);
    return AdminScaffold(
      section: AdminSection.overview,
      title: 'Overview',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(overviewProvider),
        ),
      ],
      body: AdminAsync(
        value: value,
        onRetry: () => ref.invalidate(overviewProvider),
        builder: (o) => AdminPage(
          onRefresh: () => ref.refresh(overviewProvider.future),
          children: [
            _Attention(o),
            if (!o.money.healthy) const _BooksWarning(),
            const SectionTitle('Last 30 days'),
            TileGrid(
              children: [
                StatTile(
                  icon: Icons.payments_outlined,
                  label: 'Customer spend on finished work',
                  value: o.last30.gmvPaisa.asRupeesShort,
                  note: '${o.last30.completed} jobs completed',
                ),
                StatTile(
                  icon: Icons.savings_outlined,
                  tone: Tone.success,
                  label: 'Commission earned',
                  value: o.last30.commissionPaisa.asRupeesShort,
                ),
                StatTile(
                  icon: Icons.post_add_rounded,
                  label: 'Jobs posted',
                  value: '${o.last30.posted}',
                  note: '${o.last30.cancelled} cancelled',
                ),
                StatTile(
                  icon: Icons.person_add_alt_rounded,
                  label: 'New accounts',
                  value: '${o.last30.newUsers}',
                  note: '${o.newThisWeek} in the last 7 days',
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, box) {
                final posted = Panel(
                  title: 'Jobs posted, last 14 days',
                  child: DailyBars(
                    labels: [for (final d in o.days) dayLabel(d.date)],
                    values: [for (final d in o.days) d.posted],
                    format: (v) => '$v',
                  ),
                );
                final gmv = Panel(
                  title: 'Customer spend, last 14 days',
                  child: DailyBars(
                    labels: [for (final d in o.days) dayLabel(d.date)],
                    values: [for (final d in o.days) d.gmvPaisa],
                    format: (v) => v.asRupeesShort,
                  ),
                );
                if (box.maxWidth < 760) return Column(children: [posted, gmv]);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: posted),
                    const SizedBox(width: AppTheme.gapLg),
                    Expanded(child: gmv),
                  ],
                );
              },
            ),
            const SectionTitle('Money right now'),
            TileGrid(
              children: [
                StatTile(
                  label: 'Held for jobs in progress',
                  value: o.money.escrowHeldPaisa.asRupeesShort,
                  onTap: () => context.go('/admin/payments'),
                ),
                StatTile(
                  label: 'Waiting to be withdrawn',
                  value: o.money.withdrawalsWaitingPaisa.asRupeesShort,
                  onTap: () => context.go('/admin/withdrawals?status=PENDING'),
                ),
                StatTile(
                  label: 'In customer and provider wallets',
                  value: o.money.walletsPaisa.asRupeesShort,
                  onTap: () => context.go('/admin/payments'),
                ),
                StatTile(
                  label: 'Commission collected, all time',
                  value: o.money.commissionPaisa.asRupeesShort,
                  onTap: () => context.go('/admin/payments?type=COMMISSION'),
                ),
              ],
            ),
            const SectionTitle('People and jobs'),
            TileGrid(
              children: [
                StatTile(
                  label: 'Accounts',
                  value: '${o.users}',
                  note:
                      '${o.providers} providers, ${o.verifiedProviders} verified',
                  onTap: () => context.go('/admin/people'),
                ),
                StatTile(
                  label: 'Collecting bids',
                  value: '${o.status('BROADCASTING') + o.status('ESCALATING')}',
                  onTap: () => context.go('/admin/jobs?status=open'),
                ),
                StatTile(
                  label: 'Booked or under way',
                  value:
                      '${o.status('ACCEPTED') + o.status('IN_PROGRESS') + o.status('DISPUTED')}',
                  onTap: () => context.go('/admin/jobs?status=active'),
                ),
                StatTile(
                  label: 'Completed, all time',
                  value: '${o.status('COMPLETED')}',
                  onTap: () => context.go('/admin/jobs?status=COMPLETED'),
                ),
                StatTile(
                  label: 'Suspended accounts',
                  value: '${o.suspended}',
                  tone: Tone.danger,
                  onTap: () => context.go('/admin/people?filter=suspended'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention(this.o);

  final Overview o;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        o.disputes,
        'Disputes',
        'Payment is frozen until you decide the split.',
        Icons.gavel_rounded,
        '/admin/jobs?status=DISPUTED',
      ),
      (
        o.cancellationReviews,
        'Cancelled during work',
        'Decide the split before the 72-hour default applies.',
        Icons.cancel_outlined,
        '/admin/jobs?status=attention',
      ),
      (
        o.guaranteeClaims,
        'Guarantee claims',
        'Arrange a re-visit, then close the claim.',
        Icons.verified_user_outlined,
        '/admin/jobs?status=attention',
      ),
      (
        o.unmatched,
        'No provider found',
        'Call the customer or find a provider by hand.',
        Icons.person_search_outlined,
        '/admin/jobs?status=MANUAL_FALLBACK',
      ),
      (
        o.identityChecks,
        'Identity checks waiting',
        'Compare the citizenship card with the provider, then approve or reject.',
        Icons.badge_outlined,
        '/admin/people?filter=checks',
      ),
      (
        o.withdrawals,
        'Withdrawals to send',
        'Send the money, then record the transfer reference.',
        Icons.outbound_outlined,
        '/admin/withdrawals?status=PENDING',
      ),
      (
        o.support,
        'Support messages waiting',
        'People wrote to the team and are waiting for a reply.',
        Icons.support_agent_outlined,
        '/admin/support?status=OPEN',
      ),
      (
        o.flags,
        'Safety flags to review',
        'Reports from customers and providers, and warning signs in chat.',
        Icons.shield_outlined,
        '/admin/safety?status=OPEN',
      ),
    ];
    final waiting = items.where((i) => i.$1 > 0).toList();
    if (waiting.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppTheme.gapLg),
        child: InfoBanner(
          tone: Tone.success,
          icon: Icons.check_circle_outline_rounded,
          title: 'Nothing is waiting on you',
          message:
              'No disputes, claims, unmatched jobs or providers to verify.',
        ),
      );
    }
    return Panel(
      title: 'Needs your attention',
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gapLg,
        AppTheme.gapLg,
        AppTheme.gapLg,
        AppTheme.gapSm,
      ),
      child: Column(
        children: [
          for (final i in waiting)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconTile(
                icon: i.$4,
                tone: i.$5.contains('people') || i.$5.contains('withdrawals')
                    ? Tone.warning
                    : Tone.danger,
                size: 40,
              ),
              title: Text(i.$2, style: context.text.titleSmall),
              subtitle: Text(i.$3),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${i.$1}', style: context.text.titleLarge),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => context.go(i.$5),
            ),
        ],
      ),
    );
  }
}

class _BooksWarning extends StatelessWidget {
  const _BooksWarning();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: InkWell(
        onTap: () => context.go('/admin/payments'),
        child: const InfoBanner(
          tone: Tone.danger,
          icon: Icons.error_outline_rounded,
          title: 'The books do not add up',
          message: 'Some balances differ from the ledger. Stop payouts and check the Payments page.',
        ),
      ),
    );
  }
}
