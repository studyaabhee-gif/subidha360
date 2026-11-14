import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/job.dart';

/// Where a job is on its normal path. Off-path endings such as cancellation
/// have no step, so the page explains those in its banner instead.
int? progressStep(JobStatus status) => switch (status) {
  JobStatus.broadcasting ||
  JobStatus.escalating ||
  JobStatus.manualFallback => 0,
  JobStatus.accepted => 1,
  JobStatus.inProgress => 2,
  JobStatus.completed => 3,
  _ => null,
};

class JobProgress extends StatelessWidget {
  const JobProgress({required this.step, super.key});

  static const _labels = ['Posted', 'Assigned', 'Working', 'Done'];

  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: tr('Job progress: {0}', [tr(_labels[step])]),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 5,
                      margin: const EdgeInsets.only(right: AppTheme.gapXs),
                      decoration: BoxDecoration(
                        color: i <= step
                            ? colors.primary
                            : context.palette.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(_labels[i]),
                      style: context.text.labelSmall!.copyWith(
                        color: i <= step
                            ? colors.onSurface
                            : context.palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
