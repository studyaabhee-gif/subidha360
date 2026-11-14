import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/schedule_picker.dart';
import '../../../core/widgets/ui.dart';
import '../domain/categories.dart';
import '../domain/job.dart';
import '../domain/job_guidance.dart';

class JobCard extends StatelessWidget {
  const JobCard({required this.job, this.showAddress = false, super.key});

  final Job job;

  /// Providers need to judge the distance before bidding.
  final bool showAddress;

  @override
  Widget build(BuildContext context) {
    final category = categoryOf(job.categoryId);
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapMd),
      child: AppCard(
        onTap: () => context.push('/jobs/${job.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhotoThumb(category.photo, size: 64),
                const SizedBox(width: AppTheme.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${category.name} · ${job.createdAt.timeAgo()}',
                        style: muted,
                      ),
                      if (showAddress) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${job.address} · '
                          '${scheduleLabel(job.preferredDate, job.preferredSlot)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.gapMd),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Pill(label: job.status.label, tone: job.status.tone),
                  ),
                ),
                const SizedBox(width: AppTheme.gapSm),
                Text(_trailing, style: context.text.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _trailing {
    if (job.escrowAmountPaisa > 0) return job.escrowAmountPaisa.asRupees;
    if (!job.status.isOpen) return '';
    return switch (job.bidCount) {
      0 => tr('No bids yet'),
      1 => tr('1 bid'),
      final count => tr('{0} bids', [count]),
    };
  }
}
