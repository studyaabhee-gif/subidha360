import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_theme.dart';
import 'job.dart';

/// The one thing a person needs to know about a job right now.
class JobGuidance {
  const JobGuidance(this.title, this.message, this.tone, this.icon);

  final String title;
  final String message;
  final Tone tone;
  final IconData icon;
}

const _clock = Icons.schedule_rounded;
const _done = Icons.check_circle_rounded;
const _alert = Icons.warning_amber_rounded;
const _lock = Icons.lock_rounded;

JobGuidance guidanceFor(
  Job job, {
  required bool seeker,
  required bool hasBid,
  DateTime? now,
}) {
  return seeker
      ? _forSeeker(job, now)
      : _forProvider(job, hasBid: hasBid, now: now);
}

JobGuidance _forSeeker(Job job, DateTime? now) {
  switch (job.status) {
    case JobStatus.broadcasting || JobStatus.escalating:
      if (job.bidCount == 0) {
        return JobGuidance(
          tr('Finding providers'),
          tr('Providers near you have been told. Their bids will appear here.'),
          Tone.info,
          Icons.search_rounded,
        );
      }
      final left = job.selectionDeadline?.timeLeft(now);
      return JobGuidance(
        tr('Choose a bid'),
        left == null
            ? tr('Compare the bids below and pick one.')
            : tr('Pick one within {0}, or this job will close.', [left]),
        Tone.brand,
        _clock,
      );
    case JobStatus.manualFallback:
      return JobGuidance(
        tr('No bids yet'),
        tr('No provider has bid on this job. You can cancel it and try again.'),
        Tone.warning,
        _alert,
      );
    case JobStatus.accepted:
      return JobGuidance(
        tr('Your payment is safe'),
        tr(
          'It stays on hold until the job is done. Your provider will start soon.',
        ),
        Tone.success,
        _lock,
      );
    case JobStatus.inProgress:
      if (job.seekerMustRespond) {
        final left = job.autoReleaseAt?.timeLeft(now);
        return JobGuidance(
          tr('Check the work'),
          left == null
              ? tr(
                  'The provider says this is finished. Payment releases very soon.',
                )
              : tr(
                  'The provider says this is finished. Payment releases in {0} unless you raise a dispute.',
                  [left],
                ),
          Tone.danger,
          _alert,
        );
      }
      if (job.seekerConfirmedAt != null) {
        return JobGuidance(
          tr('Waiting for the provider'),
          tr("You've confirmed. Payment releases once they confirm too."),
          Tone.info,
          _clock,
        );
      }
      return JobGuidance(
        tr('Work in progress'),
        tr('Confirm here once the job is finished to release the payment.'),
        Tone.info,
        Icons.construction_rounded,
      );
    case JobStatus.completed:
      return JobGuidance(
        tr('Job complete'),
        tr('The payment has been released to your provider.'),
        Tone.success,
        _done,
      );
    case JobStatus.disputed:
      return JobGuidance(
        tr('Payment on hold'),
        tr('Our team is reviewing this job and will decide how to settle it.'),
        Tone.warning,
        Icons.gavel_rounded,
      );
    case JobStatus.cancelled:
      return job.escrowReviewRequired
          ? JobGuidance(
              tr('Payment under review'),
              tr(
                'This job was cancelled during work. We will settle the payment '
                'within 3 days.',
              ),
              Tone.warning,
              Icons.gavel_rounded,
            )
          : JobGuidance(
              tr('Job cancelled'),
              tr('Any payment on hold has been returned to your wallet.'),
              Tone.neutral,
              Icons.block_rounded,
            );
    case JobStatus.expired:
      return JobGuidance(
        tr('Job closed'),
        tr(
          "No bid was chosen in time. You weren't charged. Post it again any time.",
        ),
        Tone.neutral,
        Icons.history_rounded,
      );
    case JobStatus.unknown:
      return JobGuidance(
        tr('Updating'),
        tr('Pull down to refresh this job.'),
        Tone.neutral,
        _clock,
      );
  }
}

JobGuidance _forProvider(Job job, {required bool hasBid, DateTime? now}) {
  switch (job.status) {
    case JobStatus.broadcasting || JobStatus.escalating:
      return hasBid
          ? JobGuidance(
              tr('Bid sent'),
              tr("You'll be told if the seeker chooses you."),
              Tone.success,
              _done,
            )
          : JobGuidance(
              tr('Open for bids'),
              tr('Send your best price. You can only bid once.'),
              Tone.brand,
              Icons.sell_rounded,
            );
    case JobStatus.accepted:
      return JobGuidance(
        tr('You won this job'),
        tr('The payment is secured. Tap Start work when you arrive.'),
        Tone.success,
        _lock,
      );
    case JobStatus.inProgress:
      if (job.providerConfirmedAt != null) {
        final left = job.autoReleaseAt?.timeLeft(now);
        return JobGuidance(
          tr('Waiting for the seeker'),
          left == null
              ? tr('Your payment releases very soon.')
              : tr('Your payment releases in {0} if they do not respond.', [
                  left,
                ]),
          Tone.info,
          _clock,
        );
      }
      return JobGuidance(
        tr('Work in progress'),
        tr('Confirm here when the job is finished to get paid.'),
        Tone.info,
        Icons.construction_rounded,
      );
    case JobStatus.completed:
      return JobGuidance(
        tr('Job complete'),
        tr('Your earnings are in your wallet.'),
        Tone.success,
        _done,
      );
    case JobStatus.disputed:
      return JobGuidance(
        tr('Payment on hold'),
        tr('Our team is reviewing this job and will decide how to settle it.'),
        Tone.warning,
        Icons.gavel_rounded,
      );
    case JobStatus.cancelled:
      return job.escrowReviewRequired
          ? JobGuidance(
              tr('Payment under review'),
              tr(
                'The seeker cancelled during work. We will settle the payment '
                'within 3 days.',
              ),
              Tone.warning,
              Icons.gavel_rounded,
            )
          : JobGuidance(
              tr('Job cancelled'),
              tr('This job is no longer available.'),
              Tone.neutral,
              Icons.block_rounded,
            );
    case JobStatus.manualFallback || JobStatus.expired || JobStatus.unknown:
      return JobGuidance(
        tr('Job closed'),
        tr('This job is no longer taking bids.'),
        Tone.neutral,
        Icons.history_rounded,
      );
  }
}

extension JobStatusUi on JobStatus {
  Tone get tone => switch (this) {
    JobStatus.broadcasting || JobStatus.escalating => Tone.info,
    JobStatus.accepted || JobStatus.inProgress => Tone.brand,
    JobStatus.completed => Tone.success,
    JobStatus.manualFallback || JobStatus.disputed => Tone.warning,
    JobStatus.cancelled ||
    JobStatus.expired ||
    JobStatus.unknown => Tone.neutral,
  };

  /// Finished jobs move to the Past section.
  bool get isActive => switch (this) {
    JobStatus.completed || JobStatus.cancelled || JobStatus.expired => false,
    _ => true,
  };
}
