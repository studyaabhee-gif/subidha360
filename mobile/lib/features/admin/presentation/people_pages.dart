import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/extensions/phone_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../data/admin_api.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';
import 'identity_panel.dart';
import 'operations_pages.dart';
import '../data/admin_ops_api.dart';
import '../../provider/domain/provider_models.dart';
import '../../provider/presentation/availability_screen.dart';

const _filters = {
  '': 'Everyone',
  'providers': 'Providers',
  'checks': 'Identity checks',
  'unverified': 'To verify',
  'seekers': 'Customers only',
  'suspended': 'Suspended',
  'admins': 'Admins',
};

class AdminPeoplePage extends ConsumerWidget {
  const AdminPeoplePage({
    this.q = '',
    this.filter = '',
    this.page = 1,
    super.key,
  });

  final String q;
  final String filter;
  final int page;

  void _go(BuildContext context, {String? q, String? filter, int page = 1}) {
    context.go(
      Uri(
        path: '/admin/people',
        queryParameters: {
          if ((q ?? this.q).isNotEmpty) 'q': q ?? this.q,
          if ((filter ?? this.filter).isNotEmpty)
            'filter': filter ?? this.filter,
          if (page > 1) 'page': '$page',
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (q: q, filter: filter, page: page);
    final value = ref.watch(adminUsersProvider(query));
    return AdminScaffold(
      section: AdminSection.people,
      title: 'People',
      body: AdminPage(
        onRefresh: () => ref.refresh(adminUsersProvider(query).future),
        children: [
          FilterBar(
            key: ValueKey('people-$q'),
            hint: 'Search by name, phone number or ID',
            query: q,
            onSearch: (text) => _go(context, q: text.trim()),
            filters: _filters,
            selected: filter,
            onFilter: (f) => _go(context, filter: f),
          ),
          AdminAsync(
            value: value,
            onRetry: () => ref.invalidate(adminUsersProvider(query)),
            builder: (p) => p.items.isEmpty
                ? const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No one matches',
                    message: 'Try another search or filter.',
                  )
                : Panel(
                    padding: const EdgeInsets.all(AppTheme.gapSm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AdminTable(
                          columns: const [
                            'Name',
                            'Phone',
                            'Role',
                            'Record',
                            'Joined',
                          ],
                          onTap: (i) =>
                              context.push('/admin/people/${p.items[i].id}'),
                          rows: [
                            for (final u in p.items)
                              [
                                Text(u.label, style: context.text.titleSmall),
                                Text(u.phone.asDisplayPhone),
                                _RolePills(u),
                                Text(
                                  u.isProvider
                                      ? '${u.jobsCompleted} jobs · ${u.reviewCount == 0 ? 'no reviews' : '${u.rating.toStringAsFixed(1)} / 5 (${u.reviewCount})'}'
                                      : '—',
                                ),
                                Text(dateTime(u.createdAt)),
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

class _RolePills extends StatelessWidget {
  const _RolePills(this.u);

  final UserRow u;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (u.suspension != null)
          const Pill(
            label: 'Suspended',
            tone: Tone.danger,
            icon: Icons.block_rounded,
          ),
        if (u.isAdmin) const Pill(label: 'Admin', tone: Tone.brand),
        if (u.check == 'PENDING')
          const Pill(label: 'Check waiting', tone: Tone.warning),
        if (u.isProvider)
          u.isVerified
              ? const Pill(
                  label: 'Verified provider',
                  tone: Tone.success,
                  icon: Icons.verified_rounded,
                )
              : const Pill(label: 'Provider, not verified', tone: Tone.warning)
        else
          const Pill(label: 'Customer', tone: Tone.neutral),
      ],
    );
  }
}

class AdminPersonPage extends ConsumerWidget {
  const AdminPersonPage({required this.id, super.key});

  final String id;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      ref.invalidate(adminUserProvider(id));
      ref.invalidate(overviewProvider);
      if (context.mounted) context.showMessage(done);
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  Future<void> _suspend(
    BuildContext context,
    WidgetRef ref,
    UserDetail d,
  ) async {
    final reason = await context.askForText(
      title: 'Suspend ${d.user.label}?',
      message: d.activeJobs > 0
          ? 'They have ${d.activeJobs} active jobs. Those stay open, so contact the other side and decide each one. Their waiting bids are withdrawn and they are logged out everywhere.'
          : 'They are logged out everywhere and cannot log in, bid or post. Waiting bids are withdrawn.',
      label: 'Reason (other admins see this)',
      action: 'Suspend',
      destructive: true,
    );
    if (reason == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(adminApiProvider).suspend(id, reason),
      'Account suspended',
    );
  }

  Future<void> _unsuspend(
    BuildContext context,
    WidgetRef ref,
    UserDetail d,
  ) async {
    final note = await context.askForText(
      title: 'Lift the suspension?',
      message: '${d.user.label} will be able to log in again straight away.',
      label: 'Note for the audit log',
      action: 'Lift suspension',
    );
    if (note == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(adminApiProvider).unsuspend(id, note),
      'Suspension lifted',
    );
  }

  Future<void> _verify(
    BuildContext context,
    WidgetRef ref,
    UserDetail d,
    bool verified,
  ) async {
    final note = await context.askForText(
      title: verified
          ? 'Verify ${d.user.label}?'
          : 'Remove the verified badge?',
      message: verified
          ? 'Only after you have seen their citizenship card and it matches the person. Customers see a Verified badge on every bid.'
          : 'Customers will no longer see the Verified badge.',
      label: verified ? 'What did you check?' : 'Why?',
      action: verified ? 'Verify' : 'Remove badge',
      destructive: !verified,
    );
    if (note == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(adminApiProvider).setVerified(id, verified, note),
      verified ? 'Provider verified' : 'Badge removed',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminUserProvider(id));
    return AdminScaffold(
      section: AdminSection.people,
      title: value.value?.user.label ?? 'Person',
      back: '/admin/people',
      body: AdminAsync(
        value: value,
        onRetry: () => ref.invalidate(adminUserProvider(id)),
        builder: (d) {
          final u = d.user;
          final muted = context.text.bodySmall!.copyWith(
            color: context.palette.muted,
          );
          return AdminPage(
            onRefresh: () => ref.refresh(adminUserProvider(id).future),
            children: [
              if (u.suspension != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
                  child: InfoBanner(
                    tone: Tone.danger,
                    icon: Icons.block_rounded,
                    title: 'Suspended ${dateTime(u.suspension!.at)}',
                    message: u.suspension!.reason,
                  ),
                ),
              Panel(
                child: Wrap(
                  spacing: AppTheme.gapLg,
                  runSpacing: AppTheme.gapMd,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 260,
                        maxWidth: 520,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.label, style: context.text.headlineSmall),
                          const SizedBox(height: 4),
                          SelectableText(
                            u.phone.asDisplayPhone,
                            style: context.text.bodyLarge,
                          ),
                          const SizedBox(height: AppTheme.gapSm),
                          _RolePills(u),
                          const SizedBox(height: AppTheme.gapSm),
                          IdText(u.id),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: AppTheme.gapSm,
                      runSpacing: AppTheme.gapSm,
                      children: [
                        if (u.isProvider &&
                            !u.isVerified &&
                            u.check != 'PENDING')
                          FilledButton.icon(
                            onPressed: () => _verify(context, ref, d, true),
                            icon: const Icon(Icons.verified_rounded),
                            label: const Text('Verify identity'),
                          ),
                        if (u.isProvider && u.isVerified)
                          OutlinedButton(
                            onPressed: () => _verify(context, ref, d, false),
                            child: const Text('Remove badge'),
                          ),
                        if (!u.isAdmin && u.suspension == null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.colors.error,
                            ),
                            onPressed: () => _suspend(context, ref, d),
                            icon: const Icon(Icons.block_rounded),
                            label: const Text('Suspend'),
                          ),
                        if (u.suspension != null)
                          FilledButton(
                            onPressed: () => _unsuspend(context, ref, d),
                            child: const Text('Lift suspension'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              TileGrid(
                minWidth: 180,
                children: [
                  StatTile(
                    label: 'Wallet balance',
                    value: d.balancePaisa.asRupees,
                  ),
                  StatTile(label: 'Active jobs', value: '${d.activeJobs}'),
                  if (u.isProvider) ...[
                    StatTile(
                      label: 'Jobs completed',
                      value: '${u.jobsCompleted}',
                    ),
                    StatTile(
                      label: 'Rating',
                      value: u.reviewCount == 0
                          ? '—'
                          : '${u.rating.toStringAsFixed(1)} / 5',
                      note: '${u.reviewCount} reviews',
                    ),
                  ],
                  StatTile(
                    label: 'Joined',
                    value: dateTime(u.createdAt).split(',').first,
                  ),
                ],
              ),
              _RiskPanel(detail: d),
              if (u.isProvider) IdentityPanel(detail: d),
              WithdrawalsPanel(rows: d.withdrawals),
              if (d.profile != null)
                Panel(
                  title: 'Provider profile',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Fact(
                        'Services',
                        Text(
                          d.profile!.categoryIds
                              .map((c) => categoryOf(c).name)
                              .join(', '),
                        ),
                      ),
                      Fact(
                        'Experience',
                        Text('${d.profile!.yearsExperience} years'),
                      ),
                      Fact(
                        'Receiving jobs',
                        Text(u.online ? 'Yes, online' : 'No, offline'),
                      ),
                      Fact(
                        'Working hours',
                        Text(
                          availabilitySummary(
                            d.availability == null
                                ? null
                                : Availability.fromJson(d.availability!),
                          ),
                        ),
                      ),
                      Fact(
                        'About',
                        Text(
                          d.profile!.bio.isEmpty
                              ? 'Not written yet'
                              : d.profile!.bio,
                        ),
                      ),
                    ],
                  ),
                ),
              Panel(
                title: 'Jobs',
                child: d.jobs.isEmpty
                    ? Text('No jobs yet.', style: muted)
                    : JobTable(jobs: d.jobs, personId: id),
              ),
              Panel(
                title: 'Wallet history',
                child: d.transactions.isEmpty
                    ? Text('No money has moved yet.', style: muted)
                    : AdminTable(
                        columns: const ['When', 'What', 'Amount', 'Job'],
                        numeric: const {2},
                        rows: [
                          for (final e in d.transactions)
                            [
                              Text(dateTime(e.createdAt)),
                              Text(entryTypeLabels[e.type] ?? e.type),
                              Text(signedRupees(e.amountPaisa)),
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
              ),
              if (u.isProvider)
                Panel(
                  title: 'Reviews received',
                  child: d.reviews.isEmpty
                      ? Text('No reviews yet.', style: muted)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final r in d.reviews)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Text(
                                  '${r.rating} / 5',
                                  style: context.text.titleMedium,
                                ),
                                title: Text(
                                  r.comment.isEmpty
                                      ? r.tags.join(', ')
                                      : r.comment,
                                ),
                                subtitle: Text(dateTime(r.createdAt)),
                                onTap: () =>
                                    context.push('/admin/jobs/${r.jobId}'),
                              ),
                          ],
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

/// Jobs, with the person's part in each when shown on their page.
class JobTable extends StatelessWidget {
  const JobTable({required this.jobs, this.personId, super.key});

  final List<JobRow> jobs;
  final String? personId;

  @override
  Widget build(BuildContext context) {
    return AdminTable(
      columns: [
        'Job',
        'Status',
        if (personId == null) 'Customer' else 'Their part',
        'Provider',
        'Price',
        'Posted',
      ],
      numeric: const {4},
      onTap: (i) => context.push('/admin/jobs/${jobs[i].id}'),
      rows: [
        for (final j in jobs)
          [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(j.category, style: context.text.titleSmall),
                  Text(
                    j.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                JobStatusPill(j.status),
                if (j.claimOpen) const Pill(label: 'Claim', tone: Tone.warning),
                if (j.needsReview)
                  const Pill(label: 'Decide split', tone: Tone.danger),
              ],
            ),
            if (personId == null)
              Text(j.seeker.label)
            else
              Text(j.seeker.id == personId ? 'Customer' : 'Provider'),
            Text(j.provider?.label ?? '—'),
            Text(j.escrowPaisa == 0 ? '—' : j.escrowPaisa.asRupees),
            Text(dateTime(j.createdAt)),
          ],
      ],
    );
  }
}

/// The audit rows for one record.
class ActionsPanel extends StatelessWidget {
  const ActionsPanel({required this.actions, super.key});

  final List<AdminAction> actions;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Panel(
      title: 'Admin history',
      child: actions.isEmpty
          ? Text('No admin has changed this yet.', style: muted)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final a in actions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(
                      '${a.label} · ${a.adminName.isEmpty ? shortId(a.adminId) : a.adminName}',
                    ),
                    subtitle: Text(
                      [
                        dateTime(a.at),
                        if (a.detail.isNotEmpty) a.detail,
                      ].join('\n'),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Warning signs about an account, newest flags first.
class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.detail});

  final UserDetail detail;

  @override
  Widget build(BuildContext context) {
    final r = detail.risk;
    int n(String key) => (r[key] as num?)?.toInt() ?? 0;
    final open = n('flags_open');
    final flags = detail.flags.map(FlagRow.fromJson).toList();
    return Panel(
      title: 'Safety',
      trailing: open > 0
          ? Pill(label: '$open to review', tone: Tone.warning)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppTheme.gapXl,
            runSpacing: AppTheme.gapSm,
            children: [
              Text('Flags: ${n('flags_total')}'),
              Text('Disputes on their jobs: ${n('disputes')}'),
              Text('Jobs they cancelled after booking: ${n('cancellations')}'),
            ],
          ),
          for (final f in flags) ...[
            const SizedBox(height: AppTheme.gapMd),
            FlagCard(flag: f, showReported: false),
          ],
        ],
      ),
    );
  }
}
