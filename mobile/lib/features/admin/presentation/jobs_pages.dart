import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/extensions/phone_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/admin_api.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';
import 'people_pages.dart';

const _filters = {
  '': 'All',
  'attention': 'Needs action',
  'open': 'Collecting bids',
  'active': 'Booked or under way',
  'DISPUTED': 'Disputed',
  'MANUAL_FALLBACK': 'No provider found',
  'COMPLETED': 'Completed',
  'CANCELLED': 'Cancelled',
  'EXPIRED': 'Expired',
};

class AdminJobsPage extends ConsumerWidget {
  const AdminJobsPage({
    this.q = '',
    this.status = '',
    this.page = 1,
    super.key,
  });

  final String q;
  final String status;
  final int page;

  void _go(BuildContext context, {String? q, String? status, int page = 1}) {
    context.go(
      Uri(
        path: '/admin/jobs',
        queryParameters: {
          if ((q ?? this.q).isNotEmpty) 'q': q ?? this.q,
          if ((status ?? this.status).isNotEmpty)
            'status': status ?? this.status,
          if (page > 1) 'page': '$page',
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (q: q, status: status, page: page);
    final value = ref.watch(adminJobsProvider(query));
    return AdminScaffold(
      section: AdminSection.jobs,
      title: 'Jobs',
      body: AdminPage(
        onRefresh: () => ref.refresh(adminJobsProvider(query).future),
        children: [
          FilterBar(
            key: ValueKey('jobs-$q'),
            hint: 'Search the description, address, or a job or person ID',
            query: q,
            onSearch: (text) => _go(context, q: text.trim()),
            filters: _filters,
            selected: status,
            onFilter: (s) => _go(context, status: s),
          ),
          AdminAsync(
            value: value,
            onRetry: () => ref.invalidate(adminJobsProvider(query)),
            builder: (p) => p.items.isEmpty
                ? EmptyState(
                    icon: status == 'attention'
                        ? Icons.task_alt_rounded
                        : Icons.work_off_outlined,
                    title: status == 'attention'
                        ? 'All clear'
                        : 'No jobs match',
                    message: status == 'attention'
                        ? 'No job is waiting on an admin.'
                        : 'Try another search or filter.',
                  )
                : Panel(
                    padding: const EdgeInsets.all(AppTheme.gapSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JobTable(jobs: p.items),
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

class AdminJobPage extends ConsumerWidget {
  const AdminJobPage({required this.id, super.key});

  final String id;

  Future<void> _decide(BuildContext context, WidgetRef ref, JobDetail d) async {
    final result = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DecideSheet(detail: d),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref.read(adminApiProvider).resolveEscrow(id, result.$1, result.$2);
      ref.invalidate(adminJobProvider(id));
      ref.invalidate(overviewProvider);
      if (context.mounted) {
        context.showMessage('Decision applied and both sides told');
      }
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  Future<void> _closeClaim(BuildContext context, WidgetRef ref) async {
    final note = await context.askForText(
      title: 'Close the guarantee claim?',
      message: 'The customer is sent your note, so write it for them.',
      label: 'What was done',
      action: 'Close claim',
    );
    if (note == null || !context.mounted) return;
    try {
      await ref.read(adminApiProvider).closeClaim(id, note);
      ref.invalidate(adminJobProvider(id));
      ref.invalidate(overviewProvider);
      if (context.mounted) context.showMessage('Claim closed');
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminJobProvider(id));
    return AdminScaffold(
      section: AdminSection.jobs,
      title: value.value == null
          ? 'Job'
          : '${value.value!.summary.category} job',
      back: '/admin/jobs',
      body: AdminAsync(
        value: value,
        onRetry: () => ref.invalidate(adminJobProvider(id)),
        builder: (d) {
          final s = d.summary;
          final r = d.record;
          final muted = context.text.bodySmall!.copyWith(
            color: context.palette.muted,
          );
          final canDecide = s.disputed || s.needsReview;
          String who(String userId) => userId == s.seeker.id
              ? 'Customer'
              : userId == s.provider?.id
              ? 'Provider'
              : shortId(userId);
          return AdminPage(
            onRefresh: () => ref.refresh(adminJobProvider(id).future),
            children: [
              if (canDecide)
                _DecisionBanner(
                  detail: d,
                  onDecide: () => _decide(context, ref, d),
                ),
              if (s.claimOpen)
                Panel(
                  title: 'Guarantee claim',
                  trailing: FilledButton(
                    onPressed: () => _closeClaim(context, ref),
                    child: const Text('Close claim'),
                  ),
                  child: Text(
                    '${r.claim?['reason'] ?? ''}\nRaised ${dateTime(DateTime.parse(r.claim!['at'] as String))}',
                  ),
                ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppTheme.gapSm,
                      runSpacing: AppTheme.gapSm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(s.category, style: context.text.headlineSmall),
                        JobStatusPill(s.status),
                      ],
                    ),
                    const SizedBox(height: AppTheme.gapSm),
                    Text(s.description, style: context.text.bodyLarge),
                    const SizedBox(height: AppTheme.gapMd),
                    Fact('Customer', _PersonLink(s.seeker)),
                    Fact(
                      'Provider',
                      s.provider == null
                          ? const Text('Not chosen yet')
                          : _PersonLink(s.provider!),
                    ),
                    Fact(
                      'Agreed price',
                      Text(s.escrowPaisa == 0 ? '—' : s.escrowPaisa.asRupees),
                    ),
                    Fact('Address', SelectableText(s.address)),
                    if (r.lat != null)
                      Fact(
                        'Map pin',
                        SelectableText(
                          '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}',
                        ),
                      ),
                    Fact(
                      'Wanted',
                      Text(
                        r.preferredDate.isEmpty
                            ? 'As soon as possible'
                            : '${dayLabel(r.preferredDate)}${r.preferredSlot.isEmpty ? '' : ', ${r.preferredSlot.replaceAll('-', ':00 to ')}:00'}',
                      ),
                    ),
                    Fact(
                      'Photos',
                      Text(r.photoCount == 0 ? 'None' : '${r.photoCount}'),
                    ),
                    Fact('Posted', Text(dateTime(s.createdAt))),
                    if (r.seekerConfirmedAt != null)
                      Fact(
                        'Customer confirmed',
                        Text(dateTime(r.seekerConfirmedAt!)),
                      ),
                    if (r.providerConfirmedAt != null)
                      Fact(
                        'Provider confirmed',
                        Text(dateTime(r.providerConfirmedAt!)),
                      ),
                    if (r.autoReleaseAt != null && s.status == 'IN_PROGRESS')
                      Fact(
                        'Pays out automatically',
                        Text(dateTime(r.autoReleaseAt!)),
                      ),
                    if (r.cancellation != null)
                      Fact(
                        'Cancelled',
                        Text(
                          'By ${who(r.cancellation!['cancelled_by'] as String)}: ${r.cancellation!['reason']}',
                        ),
                      ),
                    if (r.resolution != null)
                      Fact(
                        'Payment decision',
                        Text(
                          '${r.resolution!['provider_percent']}% to the provider, '
                          '${r.resolution!['resolved_by'] == 'system' ? 'applied automatically after the review window' : 'decided by an admin'}',
                        ),
                      ),
                    Fact('Job ID', IdText(s.id)),
                  ],
                ),
              ),
              Panel(
                title: 'Bids (${d.bids.length})',
                child: d.bids.isEmpty
                    ? Text('No bids.', style: muted)
                    : AdminTable(
                        columns: const [
                          'Provider',
                          'Price',
                          'Parts',
                          'Status',
                          'Note',
                          'When',
                        ],
                        numeric: const {1},
                        onTap: (i) => context.push(
                          '/admin/people/${d.bids[i].provider.id}',
                        ),
                        rows: [
                          for (final b in d.bids)
                            [
                              Text(b.provider.label),
                              Text(b.amountPaisa.asRupees),
                              Text(b.partsIncluded ? 'Included' : 'Extra'),
                              Text(b.status.toLowerCase()),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                ),
                                child: Text(
                                  b.note.isEmpty ? '—' : b.note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(dateTime(b.createdAt)),
                            ],
                        ],
                      ),
              ),
              Panel(
                title: 'Chat (${d.messages.length})',
                child: d.messages.isEmpty
                    ? Text('No messages.', style: muted)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Read chats only to decide a dispute or claim.',
                            style: muted,
                          ),
                          const SizedBox(height: AppTheme.gapSm),
                          for (final m in d.messages)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${who(m.senderId)}  ',
                                      style: context.text.titleSmall,
                                    ),
                                    TextSpan(text: m.body),
                                    TextSpan(
                                      text: '   ${dateTime(m.createdAt)}',
                                      style: muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              Panel(
                title: 'Money for this job',
                child: d.ledger.isEmpty
                    ? Text('No money has moved.', style: muted)
                    : AdminTable(
                        columns: const ['When', 'What', 'Account', 'Amount'],
                        numeric: const {3},
                        rows: [
                          for (final e in d.ledger)
                            [
                              Text(dateTime(e.createdAt)),
                              Text(entryTypeLabels[e.type] ?? e.type),
                              Text(e.accountLabel),
                              Text(signedRupees(e.amountPaisa)),
                            ],
                        ],
                      ),
              ),
              if (d.review != null)
                Panel(
                  title: 'Review',
                  child: Text(
                    '${d.review!.rating} / 5  ${[...d.review!.tags, if (d.review!.comment.isNotEmpty) d.review!.comment].join(' · ')}',
                  ),
                ),
              ActionsPanel(actions: d.actions),
            ],
          );
        },
      ),
    );
  }
}

class _PersonLink extends StatelessWidget {
  const _PersonLink(this.p);

  final Person p;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => context.push('/admin/people/${p.id}'),
        child: Text(
          '${p.label}${p.phone.isNotEmpty && p.name.isNotEmpty ? '  ${p.phone.asDisplayPhone}' : ''}',
          style: context.text.bodyMedium!.copyWith(
            color: context.colors.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _DecisionBanner extends StatelessWidget {
  const _DecisionBanner({required this.detail, required this.onDecide});

  final JobDetail detail;
  final VoidCallback onDecide;

  @override
  Widget build(BuildContext context) {
    final r = detail.record;
    final disputed = detail.summary.disputed;
    final colors = context.palette.tone(Tone.danger);
    final reason = disputed
        ? 'Dispute: ${r.dispute?['reason'] ?? ''}'
        : 'The customer cancelled after work started: ${r.cancellation?['reason'] ?? ''}';
    final due = r.escrowReviewDueAt;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.gapLg),
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Wrap(
        spacing: AppTheme.gapLg,
        runSpacing: AppTheme.gapMd,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${detail.summary.escrowPaisa.asRupees} is waiting on your decision',
                  style: context.text.titleMedium!.copyWith(
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(reason, style: TextStyle(color: colors.foreground)),
                if (!disputed && due != null)
                  Text(
                    'If no one decides by ${dateTime(due)}, it splits 50/50.',
                    style: TextStyle(color: colors.foreground),
                  ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onDecide,
            icon: const Icon(Icons.gavel_rounded),
            label: const Text('Decide the payment'),
          ),
        ],
      ),
    );
  }
}

/// Picks how much of the held payment goes to the provider.
class _DecideSheet extends StatefulWidget {
  const _DecideSheet({required this.detail});

  final JobDetail detail;

  @override
  State<_DecideSheet> createState() => _DecideSheetState();
}

class _DecideSheetState extends State<_DecideSheet> {
  double _percent = 50;
  final _note = TextEditingController();
  bool _checked = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Mirrors the server: provider share less 10% commission, rest refunded.
  /// The commission rate is shown for guidance; the server applies the real one.
  (int, int, int) _split(int amount, int percent) {
    final share = amount * percent ~/ 100;
    final commission = share * 1000 ~/ 10000;
    return (share - commission, commission, amount - share);
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.detail.summary.escrowPaisa;
    final p = _percent.round();
    final (payout, commission, refund) = _split(amount, p);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Decide the payment', style: context.text.titleLarge),
          const SizedBox(height: AppTheme.gapSm),
          Text(
            'This is final. Money moves at once and both sides are told.',
            style: context.text.bodySmall!.copyWith(
              color: context.palette.muted,
            ),
          ),
          const SizedBox(height: AppTheme.gapLg),
          Wrap(
            spacing: AppTheme.gapSm,
            children: [
              for (final preset in const [0, 25, 50, 75, 100])
                ChoiceChip(
                  label: Text(
                    preset == 0
                        ? 'Full refund'
                        : preset == 100
                        ? 'Pay provider in full'
                        : '$preset%',
                  ),
                  selected: p == preset,
                  onSelected: (_) =>
                      setState(() => _percent = preset.toDouble()),
                ),
            ],
          ),
          Slider(
            value: _percent,
            max: 100,
            divisions: 20,
            label: '$p% to the provider',
            onChanged: (v) => setState(() => _percent = v),
          ),
          Fact(
            'Provider receives',
            Text('${payout.asRupees} ($p% less commission)'),
          ),
          Fact('Commission', Text(commission.asRupees)),
          Fact('Customer refunded', Text(refund.asRupees)),
          const SizedBox(height: AppTheme.gapMd),
          TextField(
            controller: _note,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Why (kept in the audit log)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _checked,
            onChanged: (v) => setState(() => _checked = v ?? false),
            title: const Text('I have read the chat and heard from both sides'),
          ),
          const SizedBox(height: AppTheme.gapSm),
          FilledButton(
            onPressed: _checked && _note.text.trim().isNotEmpty
                ? () => Navigator.pop(context, (p, _note.text.trim()))
                : null,
            child: Text('Apply: $p% to the provider'),
          ),
        ],
      ),
    );
  }
}
