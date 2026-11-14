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
import 'download.dart';

const _types = {
  '': 'All',
  'TOP_UP': 'Top-ups',
  'ESCROW_HOLD': 'Held for jobs',
  'PAYOUT': 'Payouts',
  'COMMISSION': 'Commission',
  'ESCROW_REFUND': 'Refunds',
  'WITHDRAWAL': 'Withdrawals',
  'WITHDRAWAL_PAID': 'Withdrawals sent',
};

class AdminPaymentsPage extends ConsumerWidget {
  const AdminPaymentsPage({
    this.type = '',
    this.q = '',
    this.page = 1,
    super.key,
  });

  final String type;
  final String q;
  final int page;

  void _go(BuildContext context, {String? type, String? q, int page = 1}) {
    context.go(
      Uri(
        path: '/admin/payments',
        queryParameters: {
          if ((type ?? this.type).isNotEmpty) 'type': type ?? this.type,
          if ((q ?? this.q).isNotEmpty) 'q': q ?? this.q,
          if (page > 1) 'page': '$page',
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (type: type, q: q, page: page);
    final value = ref.watch(adminPaymentsProvider(query));
    final money = ref.watch(adminMoneyProvider);
    return AdminScaffold(
      section: AdminSection.payments,
      title: 'Payments',
      body: AdminPage(
        onRefresh: () {
          ref.invalidate(adminMoneyProvider);
          return ref.refresh(adminPaymentsProvider(query).future);
        },
        children: [
          AdminAsync(
            value: money,
            onRetry: () => ref.invalidate(adminMoneyProvider),
            builder: (m) => _Books(m),
          ),
          const InfoBanner(
            title: 'Test money only',
            message: 'Real eSewa and Khalti payments are not connected yet, so every top-up here came from the development button.',
          ),
          const SizedBox(height: AppTheme.gapLg),
          FilterBar(
            key: ValueKey('pay-$q'),
            hint: 'A person ID, job ID or account',
            query: q,
            onSearch: (text) => _go(context, q: text.trim()),
            filters: _types,
            selected: type,
            onFilter: (t) => _go(context, type: t),
          ),
          AdminAsync(
            value: value,
            onRetry: () => ref.invalidate(adminPaymentsProvider(query)),
            builder: (p) => p.items.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions match',
                    message: 'Try another filter.',
                  )
                : Panel(
                    padding: const EdgeInsets.all(AppTheme.gapSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminTable(
                          columns: const [
                            'When',
                            'What',
                            'Account',
                            'Amount',
                            'Job',
                          ],
                          numeric: const {3},
                          rows: [
                            for (final e in p.items)
                              [
                                Text(dateTime(e.createdAt)),
                                Text(entryTypeLabels[e.type] ?? e.type),
                                e.userId.isEmpty
                                    ? Text(e.accountLabel)
                                    : TextButton(
                                        onPressed: () => context.push(
                                          '/admin/people/${e.userId}',
                                        ),
                                        child: Text(e.accountLabel),
                                      ),
                                Text(
                                  signedRupees(e.amountPaisa),
                                  style: TextStyle(
                                    color: e.amountPaisa < 0
                                        ? context.palette
                                              .tone(Tone.danger)
                                              .foreground
                                        : context.palette
                                              .tone(Tone.success)
                                              .foreground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                e.jobId.isEmpty
                                    ? const Text('—')
                                    : TextButton(
                                        onPressed: () => context.push(
                                          '/admin/jobs/${e.jobId}',
                                        ),
                                        child: Text(shortId(e.jobId)),
                                      ),
                              ],
                          ],
                        ),
                        Pager(
                          page: page,
                          hasMore: p.hasMore,
                          onPage: (n) => _go(context, page: n),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Books extends StatelessWidget {
  const _Books(this.m);

  final Money m;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
          child: m.healthy
              ? const InfoBanner(
                  tone: Tone.success,
                  icon: Icons.verified_outlined,
                  title: 'The books balance',
                  message: 'Every posting sums to zero and every balance matches its ledger, checked just now.',
                )
              : InfoBanner(
                  tone: Tone.danger,
                  icon: Icons.error_outline_rounded,
                  title: 'The books do not balance',
                  message: [
                    if (m.booksBalancePaisa != 0)
                      'All balances add up to ${m.booksBalancePaisa.asRupees}, not zero.',
                    if (m.mismatched.isNotEmpty)
                      'Balance differs from the ledger: ${m.mismatched.join(', ')}.',
                    if (m.unbalanced.isNotEmpty)
                      'Postings that do not sum to zero: ${m.unbalanced.join(', ')}.',
                    'Pause payouts and ask a developer to investigate before anything else moves.',
                  ].join(' '),
                ),
        ),
        TileGrid(
          minWidth: 200,
          children: [
            StatTile(
              label: 'Net money in',
              value: m.toppedUpPaisa.asRupees,
              note: 'Top-ups less withdrawals sent',
            ),
            StatTile(label: 'In wallets', value: m.walletsPaisa.asRupees),
            StatTile(label: 'Held for jobs', value: m.escrowHeldPaisa.asRupees),
            StatTile(
              label: 'Waiting to be withdrawn',
              value: m.withdrawalsWaitingPaisa.asRupees,
            ),
            StatTile(
              label: 'Commission',
              value: m.commissionPaisa.asRupees,
              tone: Tone.success,
            ),
          ],
        ),
      ],
    );
  }
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({this.from = '', this.to = '', super.key});

  final String from;
  final String to;

  void _go(BuildContext context, String from, String to) => context.go(
    Uri(
      path: '/admin/reports',
      queryParameters: {'from': from, 'to': to},
    ).toString(),
  );

  Future<void> _pick(BuildContext context, Report r) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(r.from),
        end: DateTime.parse(r.to),
      ),
    );
    if (range != null && context.mounted) {
      _go(context, _iso(range.start), _iso(range.end));
    }
  }

  Future<void> _download(BuildContext context, WidgetRef ref, Report r) async {
    try {
      final csv = await ref.read(adminApiProvider).reportCsv(r.from, r.to);
      final saved = saveTextFile(
        'subidha360-${r.from}-to-${r.to}.csv',
        csv,
        'text/csv',
      );
      if (!saved && context.mounted) {
        context.showMessage('Downloads work in the web version');
      }
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = (from: from, to: to);
    final value = ref.watch(adminReportProvider(range));
    final now = DateTime.now();
    final presets = {
      'Last 7 days': (_iso(now.subtract(const Duration(days: 6))), _iso(now)),
      'Last 30 days': (_iso(now.subtract(const Duration(days: 29))), _iso(now)),
      'This month': (_iso(DateTime(now.year, now.month)), _iso(now)),
      'Last 90 days': (_iso(now.subtract(const Duration(days: 89))), _iso(now)),
    };
    return AdminScaffold(
      section: AdminSection.reports,
      title: 'Reports',
      actions: [
        if (value.value != null)
          TextButton.icon(
            onPressed: () => _download(context, ref, value.value!),
            icon: const Icon(Icons.download_rounded),
            label: const Text('CSV'),
          ),
      ],
      body: AdminAsync(
        value: value,
        onRetry: () => ref.invalidate(adminReportProvider(range)),
        builder: (r) {
          final t = r.totals;
          final labels = [for (final d in r.days) dayLabel(d.date)];
          return AdminPage(
            onRefresh: () => ref.refresh(adminReportProvider(range).future),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
                child: Wrap(
                  spacing: AppTheme.gapSm,
                  runSpacing: AppTheme.gapSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final p in presets.entries)
                      ChoiceChip(
                        label: Text(p.key),
                        selected: r.from == p.value.$1 && r.to == p.value.$2,
                        onSelected: (_) => _go(context, p.value.$1, p.value.$2),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text('${dayLabel(r.from)} to ${dayLabel(r.to)}'),
                      onPressed: () => _pick(context, r),
                    ),
                  ],
                ),
              ),
              Text(
                'Days are Nepal time. Money comes straight from the ledger.',
                style: context.text.bodySmall!.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppTheme.gapMd),
              TileGrid(
                minWidth: 190,
                children: [
                  StatTile(
                    label: 'Customer spend on finished work',
                    value: t.gmvPaisa.asRupeesShort,
                  ),
                  StatTile(
                    label: 'Commission',
                    value: t.commissionPaisa.asRupeesShort,
                    tone: Tone.success,
                  ),
                  StatTile(
                    label: 'Paid to providers',
                    value: t.payoutsPaisa.asRupeesShort,
                  ),
                  StatTile(
                    label: 'Refunds',
                    value: t.refundsPaisa.asRupeesShort,
                  ),
                  StatTile(
                    label: 'Withdrawals sent',
                    value: t.withdrawalsPaisa.asRupeesShort,
                  ),
                  StatTile(
                    label: 'Jobs posted',
                    value: '${t.posted}',
                    note: '${t.completed} completed, ${t.cancelled} cancelled',
                  ),
                  StatTile(
                    label: 'Completion rate',
                    value: t.posted == 0
                        ? '—'
                        : '${(t.completed * 100 / t.posted).round()}%',
                    note: 'Completed ÷ posted in this period',
                  ),
                  StatTile(label: 'New accounts', value: '${t.newUsers}'),
                ],
              ),
              _Visitors(range: (from: r.from, to: r.to)),
              Panel(
                title: 'Jobs posted per day',
                child: DailyBars(
                  labels: labels,
                  values: [for (final d in r.days) d.posted],
                  format: (v) => '$v',
                ),
              ),
              Panel(
                title: 'Commission per day',
                child: DailyBars(
                  labels: labels,
                  values: [for (final d in r.days) d.commissionPaisa],
                  format: (v) => v.asRupees,
                ),
              ),
              Panel(
                title: 'By service',
                padding: const EdgeInsets.all(AppTheme.gapSm),
                child: AdminTable(
                  columns: const [
                    'Service',
                    'Posted',
                    'Completed',
                    'Cancelled',
                    'Value completed',
                  ],
                  numeric: const {1, 2, 3, 4},
                  rows: [
                    for (final c in r.categories)
                      [
                        Text(c.name),
                        Text('${c.posted}'),
                        Text('${c.completed}'),
                        Text('${c.cancelled}'),
                        Text(c.valuePaisa.asRupeesShort),
                      ],
                  ],
                ),
              ),
              Panel(
                title: 'Busiest providers',
                padding: const EdgeInsets.all(AppTheme.gapSm),
                child: r.topProviders.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(AppTheme.gapMd),
                        child: Text('No jobs were completed in this period.'),
                      )
                    : AdminTable(
                        columns: const [
                          'Provider',
                          'Completed',
                          'Value',
                          'Rating',
                          'Verified',
                        ],
                        numeric: const {1, 2},
                        onTap: (i) => context.push(
                          '/admin/people/${r.topProviders[i].person.id}',
                        ),
                        rows: [
                          for (final p in r.topProviders)
                            [
                              Text(p.person.label),
                              Text('${p.completed}'),
                              Text(p.valuePaisa.asRupeesShort),
                              Text(
                                p.rating == 0
                                    ? '—'
                                    : '${p.rating.toStringAsFixed(1)} / 5',
                              ),
                              Text(p.verified ? 'Yes' : 'No'),
                            ],
                        ],
                      ),
              ),
              Panel(
                title: 'Day by day',
                padding: const EdgeInsets.all(AppTheme.gapSm),
                child: AdminTable(
                  columns: const [
                    'Day',
                    'Posted',
                    'Completed',
                    'Cancelled',
                    'Spend',
                    'Commission',
                    'Refunds',
                    'Withdrawals',
                    'New accounts',
                  ],
                  numeric: const {1, 2, 3, 4, 5, 6, 7, 8},
                  rows: [
                    for (final d in r.days.reversed)
                      [
                        Text(d.date),
                        Text('${d.posted}'),
                        Text('${d.completed}'),
                        Text('${d.cancelled}'),
                        Text(d.gmvPaisa.asRupeesShort),
                        Text(d.commissionPaisa.asRupees),
                        Text(d.refundsPaisa.asRupeesShort),
                        Text(d.withdrawalsPaisa.asRupeesShort),
                        Text('${d.newUsers}'),
                      ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AdminAuditPage extends ConsumerWidget {
  const AdminAuditPage({this.page = 1, super.key});

  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminActionsProvider(page));
    return AdminScaffold(
      section: AdminSection.audit,
      title: 'Audit log',
      body: AdminPage(
        onRefresh: () => ref.refresh(adminActionsProvider(page).future),
        children: [
          Text(
            'Every change an admin makes is recorded here and cannot be edited.',
            style: context.text.bodySmall!.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: AppTheme.gapMd),
          AdminAsync(
            value: value,
            onRetry: () => ref.invalidate(adminActionsProvider(page)),
            builder: (p) => p.items.isEmpty
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nothing yet',
                    message: 'Admin actions will appear here.',
                  )
                : Panel(
                    padding: const EdgeInsets.all(AppTheme.gapSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminTable(
                          columns: const [
                            'When',
                            'Admin',
                            'Action',
                            'On',
                            'Details',
                          ],
                          onTap: (i) {
                            final a = p.items[i];
                            context.push(
                              a.targetType == 'job'
                                  ? '/admin/jobs/${a.targetId}'
                                  : '/admin/people/${a.targetId}',
                            );
                          },
                          rows: [
                            for (final a in p.items)
                              [
                                Text(dateTime(a.at)),
                                Text(
                                  a.adminName.isEmpty
                                      ? shortId(a.adminId)
                                      : a.adminName,
                                ),
                                Text(a.label),
                                Text('${a.targetType} ${shortId(a.targetId)}'),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 360,
                                  ),
                                  child: Text(
                                    a.detail.isEmpty ? '—' : a.detail,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                          ],
                        ),
                        Pager(
                          page: page,
                          hasMore: p.hasMore,
                          onPage: (n) => context.go('/admin/audit?page=$n'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Page views per day and how far visitors get towards posting a job.
class _Visitors extends ConsumerWidget {
  const _Visitors({required this.range});

  final ReportRange range;

  static const _funnelLabels = {
    '/': 'Saw the home page',
    '/service/:id': 'Opened a service',
    '/login': 'Started to log in',
    '/jobs/new': 'Opened the job form',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminTrafficProvider(range));
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Panel(
      title: 'Visitors',
      trailing: value.value == null
          ? null
          : Text('${value.value!.total} page views', style: muted),
      child: switch (value) {
        AsyncData(value: final t) when t.total == 0 => Text(
          'No visits counted yet. Views are counted from release builds only, '
          'without cookies or anything that identifies a person.',
          style: muted,
        ),
        AsyncData(value: final t) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DailyBars(
              labels: [for (final d in t.days) dayLabel(d.$1)],
              values: [for (final d in t.days) d.$2],
              format: (v) => '$v views',
              height: 120,
            ),
            const SizedBox(height: AppTheme.gapLg),
            Text('From visit to job', style: context.text.titleSmall),
            const SizedBox(height: AppTheme.gapSm),
            AdminTable(
              columns: const ['Step', 'Views', 'Of home page views'],
              numeric: const {1, 2},
              rows: [
                for (final (route, n) in t.funnel)
                  [
                    Text(_funnelLabels[route] ?? route),
                    Text('$n'),
                    Text(
                      t.funnel.first.$2 == 0
                          ? '—'
                          : '${(n * 100 / t.funnel.first.$2).round()}%',
                    ),
                  ],
              ],
            ),
            const SizedBox(height: AppTheme.gapSm),
            Text(
              'Counted without cookies or anything that identifies a person.',
              style: muted,
            ),
          ],
        ),
        AsyncError() => Text('Could not load visitor numbers.', style: muted),
        _ => const SkeletonBox(height: 120),
      },
    );
  }
}
