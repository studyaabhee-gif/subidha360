import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/ui.dart';
import '../../home/presentation/dashboard_widgets.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

/// Which wallet movements to list.
enum _Show { all, moneyIn, moneyOut }

class WalletTab extends ConsumerStatefulWidget {
  const WalletTab({super.key});

  @override
  ConsumerState<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends ConsumerState<WalletTab> {
  var _show = _Show.all;

  Future<void> _testTopUp(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(walletRepositoryProvider).devTopUp(100000);
      ref.invalidate(walletProvider);
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  /// The history, newest first, under a heading for each month.
  List<Widget> _history(List<WalletTransaction> all) {
    final rows = all.where(
      (t) => switch (_show) {
        _Show.all => true,
        _Show.moneyIn => t.amountPaisa > 0,
        _Show.moneyOut => t.amountPaisa < 0,
      },
    );
    final byMonth = <String, List<WalletTransaction>>{};
    for (final t in rows) {
      final d = t.createdAt.toLocal();
      byMonth.putIfAbsent(monthTitle(d), () => []).add(t);
    }
    if (byMonth.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppTheme.gapLg),
          child: Text(
            tr('Nothing to show.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.muted),
          ),
        ),
      ];
    }
    return [
      for (final MapEntry(key: month, value: items) in byMonth.entries) ...[
        SectionTitle(
          month,
          trailing: tr('{0} in · {1} out', [
            items
                .where((t) => t.amountPaisa > 0)
                .fold(0, (s, t) => s + t.amountPaisa)
                .asRupeesShort,
            items
                .where((t) => t.amountPaisa < 0)
                .fold(0, (s, t) => s - t.amountPaisa)
                .asRupeesShort,
          ]),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(indent: 70),
                _TransactionRow(item: items[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.gapLg),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final moneyIn = wallet.value?.transactions
        .where((t) => t.amountPaisa > 0)
        .fold(0, (s, t) => s + t.amountPaisa);
    final moneyOut = wallet.value?.transactions
        .where((t) => t.amountPaisa < 0)
        .fold(0, (s, t) => s - t.amountPaisa);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(walletProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gapLg,
          AppTheme.gapSm,
          AppTheme.gapLg,
          AppTheme.gapXl,
        ),
        children: switch (wallet) {
          AsyncData(:final value) => [
            _BalanceCard(
              balance: value.balancePaisa,
              onTestTopUp: kDebugMode ? () => _testTopUp(context, ref) : null,
            ),
            const SizedBox(height: AppTheme.gapLg),
            StatRow(
              children: [
                StatBox(
                  icon: Icons.south_west_rounded,
                  tone: Tone.success,
                  label: tr('Money in'),
                  value: (moneyIn ?? 0).asRupeesShort,
                ),
                StatBox(
                  icon: Icons.north_east_rounded,
                  tone: Tone.neutral,
                  label: tr('Money out'),
                  value: (moneyOut ?? 0).asRupeesShort,
                ),
              ],
            ),
            AppCard(
              child: NumberedSteps(
                steps: [
                  (
                    tr('Held, not paid'),
                    tr(
                      'When you hire someone, the price is held here until '
                      'you confirm the work is done.',
                    ),
                  ),
                  (
                    tr('Refunded if it falls through'),
                    tr(
                      'If a job is cancelled before work starts, the money '
                      'comes back to this wallet.',
                    ),
                  ),
                  (
                    tr('Covered for 30 days'),
                    tr(
                      'If the work fails within 30 days, tell us through the '
                      'job and we help put it right.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.gapXl),
            if (value.transactions.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_rounded,
                title: tr('No transactions yet'),
                message: tr('Your payments and earnings will appear here.'),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(tr('History'), style: context.text.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.gapSm),
              Wrap(
                spacing: AppTheme.gapSm,
                runSpacing: AppTheme.gapSm,
                children: [
                  for (final (s, label) in [
                    (_Show.all, tr('All')),
                    (_Show.moneyIn, tr('Money in')),
                    (_Show.moneyOut, tr('Money out')),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _show == s,
                      onSelected: (_) => setState(() => _show = s),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.gapMd),
              ..._history(value.transactions),
            ],
          ],
          AsyncError(:final error) => [
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: tr("Couldn't load your wallet"),
              message: ApiException.from(error).message,
              action: OutlinedButton(
                onPressed: () => ref.invalidate(walletProvider),
                child: Text(tr('Try again')),
              ),
            ),
          ],
          _ => [const SkeletonCards(count: 2)],
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, this.onTestTopUp});

  final int balance;
  final VoidCallback? onTestTopUp;

  @override
  Widget build(BuildContext context) {
    const onHero = Colors.white;
    return Container(
      padding: const EdgeInsets.all(AppTheme.gapXl),
      decoration: BoxDecoration(
        color: context.palette.heroEnd,
        image: const DecorationImage(
          image: AssetImage(Photos.himalaya),
          fit: BoxFit.cover,
          alignment: Alignment(0.4, 0.4),
          colorFilter: ColorFilter.mode(AppTheme.heroTint, BlendMode.srcATop),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Available balance'),
            style: context.text.labelMedium!.copyWith(
              color: onHero.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppTheme.gapXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              balance.asRupees,
              style: context.text.displaySmall!.copyWith(color: onHero),
            ),
          ),
          const SizedBox(height: AppTheme.gapLg),
          if (onTestTopUp != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: onHero,
                side: BorderSide(color: onHero.withValues(alpha: 0.5)),
                minimumSize: const Size(0, 44),
              ),
              onPressed: onTestTopUp,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(tr('Add Rs 1,000 test money')),
            )
          else
            Text(
              tr('Top-ups with eSewa and Khalti are coming soon.'),
              style: context.text.bodySmall!.copyWith(
                color: onHero.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item});

  final WalletTransaction item;

  @override
  Widget build(BuildContext context) {
    final incoming = item.amountPaisa > 0;
    final amount = item.amountPaisa.abs().asRupees;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.gapMd + 2),
      child: Row(
        children: [
          IconTile(
            icon: incoming
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            tone: incoming ? Tone.success : Tone.neutral,
            size: 42,
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    transactionLabels[item.transactionType] ??
                        item.transactionType,
                  ),
                  style: context.text.titleSmall,
                ),
                Text(
                  item.createdAt.timeAgo(),
                  style: context.text.bodySmall!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            incoming ? '+$amount' : '-$amount',
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: incoming
                  ? context.palette.tone(Tone.success).foreground
                  : context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
