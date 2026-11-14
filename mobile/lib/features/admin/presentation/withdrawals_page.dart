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

const _filters = {
  'PENDING': 'To send',
  'PAID': 'Sent',
  'REJECTED': 'Refused',
  '': 'All',
};

/// Withdrawal requests. An admin sends the money by bank transfer or eWallet,
/// then records the reference here. Until merchant payouts are connected,
/// nothing is sent automatically.
class AdminWithdrawalsPage extends ConsumerWidget {
  const AdminWithdrawalsPage({
    this.status = 'PENDING',
    this.page = 1,
    super.key,
  });

  final String status;
  final int page;

  void _go(BuildContext context, {String? status, int page = 1}) => context.go(
    Uri(
      path: '/admin/withdrawals',
      queryParameters: {
        'status': status ?? this.status,
        if (page > 1) 'page': '$page',
      },
    ).toString(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (status: status, page: page);
    final value = ref.watch(adminWithdrawalsProvider(query));
    return AdminScaffold(
      section: AdminSection.withdrawals,
      title: 'Withdrawals',
      body: AdminPage(
        onRefresh: () => ref.refresh(adminWithdrawalsProvider(query).future),
        children: [
          FilterBar(
            hint: '',
            query: '',
            onSearch: (_) {},
            filters: _filters,
            selected: status,
            onFilter: (s) => _go(context, status: s),
          ),
          const InfoBanner(
            title: 'Sent by hand for now',
            message:
                'eSewa and Khalti payouts are not connected yet. Send each one '
                'from the company account, check the name matches the verified '
                'provider, then record the reference.',
          ),
          const SizedBox(height: AppTheme.gapLg),
          AdminAsync(
            value: value,
            onRetry: () => ref.invalidate(adminWithdrawalsProvider(query)),
            builder: (p) => p.items.isEmpty
                ? EmptyState(
                    icon: Icons.task_alt_rounded,
                    title: status == 'PENDING' ? 'Nothing to send' : 'None yet',
                    message: status == 'PENDING'
                        ? 'No provider is waiting for a withdrawal.'
                        : 'Withdrawals will appear here.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final w in p.items) WithdrawalCard(w: w),
                      Pager(
                        page: page,
                        hasMore: p.hasMore,
                        onPage: (n) => _go(context, page: n),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One withdrawal, with send and refuse actions while it waits.
class WithdrawalCard extends ConsumerWidget {
  const WithdrawalCard({required this.w, this.showPerson = true, super.key});

  final WithdrawalRow w;
  final bool showPerson;

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool paid,
  }) async {
    final note = await context.askForText(
      title: paid
          ? 'Record ${w.amountPaisa.asRupees} as sent'
          : 'Refuse this withdrawal?',
      message: paid
          ? 'Send the money first, to ${w.sendTo}. Then enter the transfer '
                'reference. The provider sees it.'
          : 'The money goes back to their wallet. Tell them why, for example '
                'a name that does not match their ID.',
      label: paid ? 'Transfer reference' : 'Reason (the provider sees this)',
      action: paid ? 'Record as sent' : 'Refuse',
      destructive: !paid,
    );
    if (note == null || !context.mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .decideWithdrawal(w.id, paid: paid, note: note);
      ref.invalidate(adminWithdrawalsProvider);
      ref.invalidate(adminUserProvider(w.userId));
      ref.invalidate(overviewProvider);
      ref.invalidate(adminMoneyProvider);
      if (context.mounted) {
        context.showMessage(paid ? 'Recorded as sent' : 'Refused and returned');
      }
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Panel(
      child: Wrap(
        spacing: AppTheme.gapLg,
        runSpacing: AppTheme.gapMd,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showPerson
                      ? '${w.amountPaisa.asRupees} to ${w.person.label}'
                      : w.amountPaisa.asRupees,
                  style: context.text.titleMedium,
                ),
                SelectableText(w.sendTo),
                Text(
                  [
                    'Asked ${dateTime(w.createdAt)}',
                    if (showPerson && !w.verified) 'Not verified',
                    if (w.reference.isNotEmpty) 'Reference ${w.reference}',
                    if (w.reason.isNotEmpty) w.reason,
                  ].join(' · '),
                  style: muted,
                ),
              ],
            ),
          ),
          if (w.status == 'PENDING')
            Wrap(
              spacing: AppTheme.gapSm,
              runSpacing: AppTheme.gapSm,
              children: [
                FilledButton(
                  onPressed: () => _decide(context, ref, paid: true),
                  child: const Text('Record as sent'),
                ),
                OutlinedButton(
                  onPressed: () => _decide(context, ref, paid: false),
                  child: const Text('Refuse'),
                ),
                if (showPerson)
                  TextButton(
                    onPressed: () => context.push('/admin/people/${w.userId}'),
                    child: const Text('Their account'),
                  ),
              ],
            )
          else
            Pill(
              label: w.status == 'PAID' ? 'Sent' : 'Refused',
              tone: w.status == 'PAID' ? Tone.success : Tone.neutral,
            ),
        ],
      ),
    );
  }
}
