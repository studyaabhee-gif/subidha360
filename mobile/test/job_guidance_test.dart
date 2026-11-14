import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/features/jobs/domain/job.dart';
import 'package:subidha360/features/jobs/domain/job_guidance.dart';
import 'package:subidha360/features/jobs/presentation/bid_sheet.dart';
import 'package:subidha360/features/jobs/presentation/job_progress.dart';

Job job(
  JobStatus status, {
  int bids = 0,
  DateTime? providerConfirmed,
  DateTime? seekerConfirmed,
  DateTime? release,
  bool review = false,
}) => Job(
  id: 'j',
  seekerId: 's',
  categoryId: 1,
  status: status,
  description: 'd',
  address: 'a',
  bidCount: bids,
  escrowAmountPaisa: 0,
  createdAt: DateTime(2026),
  providerConfirmedAt: providerConfirmed,
  seekerConfirmedAt: seekerConfirmed,
  autoReleaseAt: release,
  escrowReviewRequired: review,
);

void main() {
  final now = DateTime(2026, 11, 6, 12);

  test('every status gives both sides something to read', () {
    for (final status in JobStatus.values) {
      for (final seeker in [true, false]) {
        final guidance = guidanceFor(
          job(status),
          seeker: seeker,
          hasBid: false,
        );
        expect(guidance.title, isNotEmpty);
        expect(guidance.message, isNotEmpty);
      }
    }
  });

  test('a silent seeker gets a danger warning with the deadline', () {
    final guidance = guidanceFor(
      job(
        JobStatus.inProgress,
        providerConfirmed: now,
        release: now.add(const Duration(hours: 72)),
      ),
      seeker: true,
      hasBid: false,
      now: now,
    );

    expect(guidance.tone, Tone.danger);
    expect(guidance.message, contains('3 days'));
  });

  test('no warning once the seeker has confirmed', () {
    final guidance = guidanceFor(
      job(JobStatus.inProgress, seekerConfirmed: now),
      seeker: true,
      hasBid: false,
      now: now,
    );

    expect(guidance.tone, isNot(Tone.danger));
  });

  test('held escrow after cancellation is explained', () {
    expect(
      guidanceFor(
        job(JobStatus.cancelled, review: true),
        seeker: true,
        hasBid: false,
      ).title,
      'Payment under review',
    );
  });

  test('a provider who has bid is not asked to bid again', () {
    expect(
      guidanceFor(
        job(JobStatus.broadcasting),
        seeker: false,
        hasBid: true,
      ).title,
      'Bid sent',
    );
  });

  test('finished jobs leave the active list', () {
    expect(JobStatus.completed.isActive, isFalse);
    expect(JobStatus.cancelled.isActive, isFalse);
    expect(JobStatus.expired.isActive, isFalse);
    expect(JobStatus.disputed.isActive, isTrue);
    expect(JobStatus.inProgress.isActive, isTrue);
  });

  test('progress covers the normal path only', () {
    expect(progressStep(JobStatus.escalating), 0);
    expect(progressStep(JobStatus.completed), 3);
    expect(progressStep(JobStatus.cancelled), isNull);
    expect(progressStep(JobStatus.disputed), isNull);
  });

  test('take-home matches the backend commission, rounding in its favour', () {
    expect(providerTakeHome(50000), 45000);
    expect(providerTakeHome(99), 90);
  });
}
