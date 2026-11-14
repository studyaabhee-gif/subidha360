import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/provider_api.dart';
import '../domain/provider_models.dart';
import 'provider_widgets.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _monthLabel(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) return yearMonth;
  return tr(_months[int.parse(parts[1]) - 1]);
}

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    Earnings e,
  ) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => WithdrawSheet(earnings: e),
    );
    if (sent == true) {
      ref.invalidate(earningsProvider);
      ref.invalidate(walletProvider);
      if (context.mounted) {
        context.showMessage(
          tr('Request sent. We send withdrawals within two working days.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(earningsProvider);
    return ToolPage(
      title: tr('Earnings'),
      onRefresh: () => ref.refresh(earningsProvider.future),
      children: [
        ToolAsync(
          value: value,
          onRetry: () => ref.invalidate(earningsProvider),
          builder: (e) {
            final muted = context.text.bodySmall!.copyWith(
              color: context.palette.muted,
            );
            final canWithdraw =
                e.verified &&
                !e.hasWaitingWithdrawal &&
                e.availablePaisa >= e.minWithdrawalPaisa;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Balance(e: e),
                const SizedBox(height: AppTheme.gapMd),
                FilledButton.icon(
                  onPressed: canWithdraw
                      ? () => _withdraw(context, ref, e)
                      : null,
                  icon: const Icon(Icons.account_balance_outlined),
                  label: Text(tr('Withdraw to bank or eSewa')),
                ),
                const SizedBox(height: AppTheme.gapSm),
                if (!e.verified)
                  InfoBanner(
                    tone: Tone.warning,
                    icon: Icons.badge_outlined,
                    title: tr('Verify your identity to withdraw'),
                    message: tr(
                      'We only send money to people we have checked. It '
                      'takes a few minutes to send your documents.',
                    ),
                  )
                else if (e.hasWaitingWithdrawal)
                  Text(
                    tr(
                      'You can ask for another withdrawal once this one is sent.',
                    ),
                    style: muted,
                    textAlign: TextAlign.center,
                  )
                else if (e.availablePaisa < e.minWithdrawalPaisa)
                  Text(
                    tr('The smallest withdrawal is {0}.', [
                      e.minWithdrawalPaisa.asRupeesShort,
                    ]),
                    style: muted,
                    textAlign: TextAlign.center,
                  ),
                if (!e.verified) ...[
                  const SizedBox(height: AppTheme.gapSm),
                  OutlinedButton(
                    onPressed: () => context.push('/provider/verify'),
                    child: Text(tr('Start the identity check')),
                  ),
                ],
                const SizedBox(height: AppTheme.gapXl),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        label: tr('This month'),
                        value: e.thisMonthPaisa.asRupeesShort,
                        note: tr('{0} jobs', [
                          e.months.isEmpty ? 0 : e.months.last.jobs,
                        ]),
                      ),
                    ),
                    const SizedBox(width: AppTheme.gapMd),
                    Expanded(
                      child: _Figure(
                        label: tr('All time'),
                        value: e.totalEarnedPaisa.asRupeesShort,
                        note: tr('{0} jobs', [e.jobsPaid]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.gapMd),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('Earned each month'),
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: AppTheme.gapMd),
                      MonthBars(months: e.months),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.gapSm),
                Text(
                  tr('Platform fee paid so far: {0}', [
                    e.commissionPaidPaisa.asRupees,
                  ]),
                  style: muted,
                ),
                if (e.withdrawals.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.gapXl),
                  SectionTitle(tr('Withdrawals')),
                  for (final w in e.withdrawals) _WithdrawalTile(w: w),
                ],
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('Paid jobs')),
                if (e.payments.isEmpty)
                  Text(
                    tr('Finished jobs and what you earned appear here.'),
                    style: muted,
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < e.payments.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _PaymentTile(p: e.payments[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.e});

  final Earnings e;

  @override
  Widget build(BuildContext context) {
    final on = context.colors.onPrimary;
    final soft = on.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.all(AppTheme.gapXl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.palette.heroStart, context.palette.heroEnd],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Ready to withdraw'), style: TextStyle(color: soft)),
          const SizedBox(height: AppTheme.gapXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              e.availablePaisa.asRupees,
              style: context.text.headlineLarge!.copyWith(color: on),
            ),
          ),
          const SizedBox(height: AppTheme.gapMd),
          Wrap(
            spacing: AppTheme.gapLg,
            runSpacing: AppTheme.gapXs,
            children: [
              Text(
                tr('On hold for current jobs: {0}', [
                  e.onHoldPaisa.asRupeesShort,
                ]),
                style: TextStyle(color: soft),
              ),
              if (e.withdrawingPaisa > 0)
                Text(
                  tr('Being sent: {0}', [e.withdrawingPaisa.asRupeesShort]),
                  style: TextStyle(color: soft),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: muted),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.text.titleLarge),
          ),
          if (note != null) Text(note!, style: muted),
        ],
      ),
    );
  }
}

/// One bar per month. A single series, so the card title names it and each
/// bar has a tooltip with the exact amount.
class MonthBars extends StatelessWidget {
  const MonthBars({required this.months, super.key});

  final List<EarningsMonth> months;

  @override
  Widget build(BuildContext context) {
    final top = months.fold(0, (a, m) => m.earnedPaisa > a ? m.earnedPaisa : a);
    final muted = context.text.labelSmall!.copyWith(
      color: context.palette.muted,
    );
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in months)
            Expanded(
              child: Tooltip(
                message: '${_monthLabel(m.month)}: ${m.earnedPaisa.asRupees}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: top == 0 ? 0 : m.earnedPaisa / top,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: m.earnedPaisa == 0
                                    ? null
                                    : context.colors.primary,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: context.palette.line),
                    const SizedBox(height: 4),
                    Text(_monthLabel(m.month), style: muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.w});

  final Withdrawal w;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    final (label, tone) = switch (w.status) {
      WithdrawalStatus.paid => (tr('Sent'), Tone.success),
      WithdrawalStatus.rejected => (tr('Returned to wallet'), Tone.danger),
      _ => (tr('Being sent'), Tone.warning),
    };
    final detail = switch (w.status) {
      WithdrawalStatus.paid => tr('Reference: {0}', [w.reference]),
      WithdrawalStatus.rejected => w.reason,
      _ => tr('Asked {0}', [w.createdAt.timeAgo()]),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
      child: AppCard(
        padding: const EdgeInsets.all(AppTheme.gapMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.amountPaisa.asRupees, style: context.text.titleMedium),
                  Text(w.destination.summary, style: muted),
                  Text(detail, style: muted),
                ],
              ),
            ),
            Pill(label: label, tone: tone),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.p});

  final JobPayment p;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return ListTile(
      onTap: () => context.push('/jobs/${p.jobId}'),
      leading: IconTile(icon: categoryOf(p.categoryId).icon, size: 40),
      title: Text(categoryOf(p.categoryId).name),
      subtitle: Text(
        tr('Price {0}, fee {1} · {2}', [
          p.pricePaisa.asRupeesShort,
          p.commissionPaisa.asRupees,
          p.at.timeAgo(),
        ]),
        style: muted,
      ),
      trailing: Text(
        '+${p.earnedPaisa.asRupees}',
        style: context.text.titleSmall!.copyWith(
          color: context.palette.tone(Tone.success).foreground,
        ),
      ),
    );
  }
}

/// Asks how much to withdraw and where to send it.
class WithdrawSheet extends ConsumerStatefulWidget {
  const WithdrawSheet({required this.earnings, super.key});

  final Earnings earnings;

  @override
  ConsumerState<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<WithdrawSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: (widget.earnings.availablePaisa ~/ 100).toString(),
  );
  final _bank = TextEditingController();
  final _name = TextEditingController();
  final _number = TextEditingController();
  final _wallet = TextEditingController();
  var _method = PayoutMethod.esewa;
  var _busy = false;

  @override
  void dispose() {
    for (final c in [_amount, _bank, _name, _number, _wallet]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _amountError(String? text) {
    final paisa = (text ?? '').toPaisa;
    if (paisa == null) return tr('Enter an amount in rupees');
    if (paisa < widget.earnings.minWithdrawalPaisa) {
      return tr('The smallest withdrawal is {0}.', [
        widget.earnings.minWithdrawalPaisa.asRupeesShort,
      ]);
    }
    if (paisa > widget.earnings.availablePaisa) {
      return tr('You have {0} to withdraw', [
        widget.earnings.availablePaisa.asRupees,
      ]);
    }
    return null;
  }

  String? _required(String? text) =>
      (text ?? '').trim().length < 2 ? tr('Required') : null;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final dest = _method == PayoutMethod.bank
        ? PayoutDestination(
            method: _method,
            bankName: _bank.text.trim(),
            accountName: _name.text.trim(),
            accountNumber: _number.text.trim(),
          )
        : PayoutDestination(
            method: _method,
            accountName: _name.text.trim(),
            walletId: _wallet.text.trim(),
          );
    setState(() => _busy = true);
    try {
      await ref.read(providerApiProvider).withdraw(_amount.text.toPaisa!, dest);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Withdraw earnings'), style: context.text.titleLarge),
              const SizedBox(height: AppTheme.gapLg),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: tr('Amount (Rs)'),
                  helperText: tr('Available: {0}', [
                    widget.earnings.availablePaisa.asRupees,
                  ]),
                ),
                validator: _amountError,
              ),
              const SizedBox(height: AppTheme.gapLg),
              SegmentedButton<String>(
                segments: [
                  const ButtonSegment(
                    value: PayoutMethod.esewa,
                    label: Text('eSewa'),
                  ),
                  const ButtonSegment(
                    value: PayoutMethod.khalti,
                    label: Text('Khalti'),
                  ),
                  ButtonSegment(
                    value: PayoutMethod.bank,
                    label: Text(tr('Bank')),
                  ),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
              const SizedBox(height: AppTheme.gapLg),
              if (_method == PayoutMethod.bank) ...[
                TextFormField(
                  controller: _bank,
                  decoration: InputDecoration(labelText: tr('Bank name')),
                  validator: _required,
                ),
                const SizedBox(height: AppTheme.gapMd),
                TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: InputDecoration(labelText: tr('Account number')),
                  validator: (t) => RegExp(r'^\d{6,20}$').hasMatch(t ?? '')
                      ? null
                      : tr('Account numbers are 6 to 20 digits'),
                ),
              ] else
                TextFormField(
                  controller: _wallet,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    ...digits,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('eWallet mobile number'),
                  ),
                  validator: (t) => RegExp(r'^9[78]\d{8}$').hasMatch(t ?? '')
                      ? null
                      : tr(
                          'Enter a 10-digit mobile number starting with 97 or 98',
                        ),
                ),
              const SizedBox(height: AppTheme.gapMd),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Name on the account'),
                  helperText: tr('Must match your citizenship card'),
                ),
                validator: _required,
              ),
              const SizedBox(height: AppTheme.gapXl),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(tr('Send request')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
