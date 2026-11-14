import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_list.dart';
import '../../../core/widgets/ui.dart';
import '../../home/presentation/dashboard_widgets.dart';
import '../domain/job.dart';
import '../domain/job_guidance.dart';
import '../providers/job_providers.dart';
import 'job_card.dart';

/// The ways a customer can narrow their job list.
enum _Filter { all, active, done, closed }

extension on _Filter {
  String get label => switch (this) {
    _Filter.all => tr('All'),
    _Filter.active => tr('Active'),
    _Filter.done => tr('Completed'),
    _Filter.closed => tr('Cancelled or expired'),
  };

  bool keeps(Job j) => switch (this) {
    _Filter.all => true,
    _Filter.active => j.status.isActive,
    _Filter.done => j.status == JobStatus.completed,
    _Filter.closed =>
      j.status == JobStatus.cancelled || j.status == JobStatus.expired,
  };
}

class MyJobsTab extends ConsumerStatefulWidget {
  const MyJobsTab({super.key});

  @override
  ConsumerState<MyJobsTab> createState() => _MyJobsTabState();
}

class _MyJobsTabState extends ConsumerState<MyJobsTab> {
  var _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(myJobsProvider);
    final jobs = value.value ?? const <Job>[];
    return AsyncListPage<Job>(
      value: value,
      onRefresh: () => ref.refresh(myJobsProvider.future),
      header: [
        Row(
          children: [
            Expanded(
              child: Text(tr('My jobs'), style: context.text.headlineSmall),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => context.push('/jobs/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('Post a job')),
            ),
          ],
        ),
        if (jobs.isNotEmpty) ...[
          const SizedBox(height: AppTheme.gapMd),
          Wrap(
            spacing: AppTheme.gapSm,
            runSpacing: AppTheme.gapSm,
            children: [
              for (final f in _Filter.values)
                ChoiceChip(
                  label: Text('${f.label} (${jobs.where(f.keeps).length})'),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppTheme.gapLg),
      ],
      empty: EmptyState(
        icon: Icons.assignment_outlined,
        title: tr('No jobs yet'),
        message: tr('Post a job and nearby providers will send you bids.'),
      ),
      builder: (context, jobs) {
        final shown = jobs.where(_filter.keeps).toList();
        if (shown.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.gapXl),
              child: QuietNote(
                tr('No jobs here.'),
                icon: Icons.filter_list_off_rounded,
              ),
            ),
          ];
        }
        return _activeAndPast(shown, seeker: true);
      },
    );
  }
}

List<Widget> _activeAndPast(List<Job> jobs, {required bool seeker}) {
  final active = jobs.where((job) => job.status.isActive).toList();
  final past = jobs.where((job) => !job.status.isActive).toList();
  return [
    if (active.isNotEmpty) ...[
      SectionTitle(tr('Active'), trailing: '${active.length}'),
      for (final job in active) JobTrackerCard(job: job, seeker: seeker),
    ],
    if (past.isNotEmpty) ...[
      if (active.isNotEmpty) const SizedBox(height: AppTheme.gapMd),
      SectionTitle(tr('Past'), trailing: '${past.length}'),
      for (final job in past) JobCard(job: job),
    ],
  ];
}

/// Which list the provider sees.
enum ProviderView { open, mine }

/// Open jobs to bid on, and the jobs a provider has already won.
class JobFeedTab extends ConsumerStatefulWidget {
  const JobFeedTab({this.only, super.key});

  /// Shows one list without the switch, when the home screen has a tab for
  /// each.
  final ProviderView? only;

  @override
  ConsumerState<JobFeedTab> createState() => _JobFeedTabState();
}

class _JobFeedTabState extends ConsumerState<JobFeedTab> {
  late var _view = widget.only ?? ProviderView.open;

  @override
  Widget build(BuildContext context) {
    final tabs = SegmentedButton<ProviderView>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: ProviderView.open, label: Text(tr('Open jobs'))),
        ButtonSegment(value: ProviderView.mine, label: Text(tr('My work'))),
      ],
      selected: {_view},
      onSelectionChanged: (value) => setState(() => _view = value.first),
    );
    final header = widget.only == null
        ? [tabs, const SizedBox(height: AppTheme.gapLg)]
        : const <Widget>[];

    return switch (_view) {
      ProviderView.open => AsyncListPage<Job>(
        value: ref.watch(jobFeedProvider),
        onRefresh: () => ref.refresh(jobFeedProvider.future),
        header: header,
        empty: EmptyState(
          icon: Icons.travel_explore_rounded,
          title: tr('No open jobs right now'),
          message: tr(
            'New jobs in your area appear here. Pull down to check again.',
          ),
        ),
        builder: (context, jobs) => [
          SectionTitle(tr('Near you'), trailing: tr('{0} open', [jobs.length])),
          for (final job in jobs) JobCard(job: job, showAddress: true),
        ],
      ),
      ProviderView.mine => AsyncListPage<Job>(
        value: ref.watch(assignedJobsProvider),
        onRefresh: () => ref.refresh(assignedJobsProvider.future),
        header: header,
        empty: EmptyState(
          icon: Icons.handshake_outlined,
          title: tr('No work yet'),
          message: tr('Jobs you win will appear here.'),
        ),
        builder: (context, jobs) => _activeAndPast(jobs, seeker: false),
      ),
    };
  }
}
