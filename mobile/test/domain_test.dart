import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/features/jobs/domain/job.dart';

Map<String, dynamic> jobJson(Map<String, dynamic> extra) => {
  'id': 'j1',
  'seeker_id': 's1',
  'category_id': 1,
  'status': 'IN_PROGRESS',
  'description': 'Leaking tap',
  'address': 'Baneshwor',
  'bid_count': 1,
  'escrow_amount_paisa': 50000,
  'created_at': '2026-11-06T12:00:00Z',
  ...extra,
};

void main() {
  test('reads the backend job format', () {
    final job = Job.fromJson(
      jobJson({
        'provider_id': 'p1',
        'provider_confirmed_at': '2026-11-06T13:00:00Z',
        'auto_release_at': '2026-11-09T13:00:00Z',
        'job_location': {
          'type': 'Point',
          'coordinates': [85.324, 27.7172],
        },
        'photo_ids': ['ph1'],
        'reschedule_count': 3,
      }),
    );

    expect(job.status, JobStatus.inProgress);
    expect(job.escrowAmountPaisa, 50000);
    expect(job.isAssignedProvider('p1'), isTrue);
    expect(job.seekerMustRespond, isTrue);
    expect(job.jobLocation!.lat, 27.7172);
    expect(job.jobLocation!.lng, 85.324);
    expect(job.photoIds, ['ph1']);
    expect(job.canReschedule, isFalse);
  });

  test('every backend status has a value', () {
    final statuses = {
      'BROADCASTING': JobStatus.broadcasting,
      'ESCALATING': JobStatus.escalating,
      'MANUAL_FALLBACK': JobStatus.manualFallback,
      'ACCEPTED': JobStatus.accepted,
      'IN_PROGRESS': JobStatus.inProgress,
      'COMPLETED': JobStatus.completed,
      'CANCELLED': JobStatus.cancelled,
      'DISPUTED': JobStatus.disputed,
      'EXPIRED': JobStatus.expired,
    };
    statuses.forEach((text, status) {
      expect(Job.fromJson(jobJson({'status': text})).status, status);
    });
  });

  test('a status added later does not crash older apps', () {
    expect(
      Job.fromJson(jobJson({'status': 'SOMETHING_NEW'})).status,
      JobStatus.unknown,
    );
  });

  test('no warning once the seeker has confirmed', () {
    final job = Job.fromJson(
      jobJson({
        'provider_confirmed_at': '2026-11-06T13:00:00Z',
        'seeker_confirmed_at': '2026-11-06T14:00:00Z',
      }),
    );

    expect(job.seekerMustRespond, isFalse);
  });
}
