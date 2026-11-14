import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subidha360/core/extensions/phone_extensions.dart';
import 'package:subidha360/core/l10n/tr.dart';
import 'package:subidha360/core/network/api_exception.dart';
import 'package:subidha360/core/providers/core_providers.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/features/auth/data/auth_repository.dart';
import 'package:subidha360/features/auth/domain/user.dart';
import 'package:subidha360/features/auth/presentation/otp_screen.dart';
import 'package:subidha360/features/auth/providers/auth_controller.dart';
import 'package:subidha360/features/catalog/data/catalog_repository.dart';
import 'package:subidha360/features/catalog/domain/catalog.dart';
import 'package:subidha360/features/catalog/presentation/service_detail_page.dart';
import 'package:subidha360/features/jobs/data/job_repository.dart';
import 'package:subidha360/features/jobs/domain/bid.dart';
import 'package:subidha360/features/jobs/domain/job.dart';
import 'package:subidha360/features/jobs/domain/provider_profile.dart';
import 'package:subidha360/features/jobs/presentation/create_job_screen.dart';
import 'package:subidha360/features/jobs/presentation/job_detail_screen.dart';
import 'package:subidha360/features/jobs/presentation/job_map.dart';
import 'package:subidha360/features/jobs/presentation/my_jobs_tab.dart';
import 'package:subidha360/features/jobs/providers/job_providers.dart';

import 'support/memory_token_storage.dart';

class MockJobs extends Mock implements JobRepository {}

class MockAuthRepo extends Mock implements AuthRepository {}

class FakeAuth extends AuthController {
  FakeAuth({this.user, this.failWith});

  final User? user;
  final ApiException? failWith;
  final codes = <String>[];

  @override
  Future<User?> build() async => user;

  @override
  Future<void> verifyOtp(String phone, String code) async {
    codes.add(code);
    if (failWith != null) throw failWith!;
  }
}

const me = User(
  id: 'me',
  phoneNumber: '+9779812345678',
  hasProviderProfile: false,
);

Job openJob() => Job(
  id: 'j',
  seekerId: 'me',
  categoryId: 1,
  status: JobStatus.broadcasting,
  description: 'Leaking tap',
  address: 'Baneshwor',
  bidCount: 1,
  escrowAmountPaisa: 0,
  createdAt: DateTime.now(),
);

Job startedJob() => openJob().copyWith(
  status: JobStatus.inProgress,
  providerId: 'p',
  escrowAmountPaisa: 150000,
);

final bid = Bid(
  id: 'b',
  jobId: 'j',
  providerId: 'p',
  amountPaisa: 150000,
  status: 'PENDING',
  createdAt: DateTime.now(),
);

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  required List overrides,
}) async {
  tester.view.physicalSize = const Size(412, 880) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'language': appLanguage.code});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        ...overrides.cast(),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
  // Let the async providers resolve and their widgets rebuild.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => mapTilesEnabled = false);

  testWidgets('catalogue text from the API appears in Nepali', (tester) async {
    appLanguage = AppLanguage.nepali;
    addTearDown(() => appLanguage = AppLanguage.english);
    await pumpApp(
      tester,
      const ServiceDetailPage(serviceId: 'tap-leak'),
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuth()),
        catalogProvider.overrideWith(
          (_) async => const [
            CatalogCategory(
              id: 1,
              slug: 'plumbing',
              name: 'Plumbing',
              tagline: 'Leaks, taps, tanks and pumps',
              services: [
                CatalogService(
                  id: 'tap-leak',
                  name: 'Leaking tap repair',
                  summary:
                      'Stop a dripping or loose tap, mixer or shower head.',
                  categoryId: 1,
                  guideFromPaisa: 40000,
                  guideToPaisa: 120000,
                  symptoms: ['tap dripping'],
                  includes: ['Finding the cause'],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    expect(find.text('चुहिएको धारा मर्मत'), findsOneWidget);
    expect(find.text('Leaking tap repair'), findsNothing);
    expect(find.text('धारा चुहिएको'), findsOneWidget);
    expect(find.text('कारण पत्ता लगाउने'), findsOneWidget);
  });

  group('changing a job', () {
    late MockJobs jobs;
    setUp(() => jobs = MockJobs());

    Future<void> pumpDetail(WidgetTester tester, Job job, String as) async {
      when(() => jobs.tracking(any())).thenAnswer((_) async => null);
      when(() => jobs.favorites()).thenAnswer((_) async => const []);
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: [
          authControllerProvider.overrideWith(
            () => FakeAuth(user: me.copyWith(id: as)),
          ),
          jobRepositoryProvider.overrideWithValue(jobs),
          jobDetailProvider('j').overrideWith((_) async => job),
          jobBidsProvider('j').overrideWith((_) async => const <Bid>[]),
          providerDetailProvider('p').overrideWith(
            (_) async =>
                (const PublicProfile(id: 'p', name: 'Ram'), const <Review>[]),
          ),
        ],
      );
    }

    testWidgets('the customer can move the time before work starts', (
      tester,
    ) async {
      await pumpDetail(tester, openJob(), 'me');
      expect(find.text('Change time'), findsOneWidget);
    });

    testWidgets('the time is fixed once work has started', (tester) async {
      await pumpDetail(tester, startedJob(), 'me');
      expect(find.text('Change time'), findsNothing);
    });

    testWidgets('the time cannot be moved past the limit', (tester) async {
      await pumpDetail(tester, openJob().copyWith(rescheduleCount: 3), 'me');
      expect(find.text('Change time'), findsNothing);
    });

    testWidgets('providers cannot move the time', (tester) async {
      await pumpDetail(tester, openJob(), 'p');
      expect(find.text('Change time'), findsNothing);
    });

    testWidgets('finished jobs offer booking the same provider again', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        startedJob().copyWith(status: JobStatus.completed, reviewed: true),
        'me',
      );
      await tester.scrollUntilVisible(find.text('Book again'), 200);
      expect(find.text('Ask the same provider'), findsOneWidget);
    });

    testWidgets('cancelled jobs can be rebooked, but not with that provider', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        startedJob().copyWith(status: JobStatus.cancelled),
        'me',
      );
      await tester.scrollUntilVisible(find.text('Book again'), 200);
      expect(find.text('Ask the same provider'), findsNothing);
    });

    testWidgets('offered providers are told the location is approximate', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        openJob().copyWith(
          jobLocation: const GeoPoint(coordinates: [85.32, 27.7]),
        ),
        'p',
      );
      expect(find.textContaining('Approximate area'), findsOneWidget);
      expect(find.text('Get directions'), findsNothing);
    });

    testWidgets('customers see whether their provider is sharing', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        startedJob().copyWith(
          jobLocation: const GeoPoint(coordinates: [85.32, 27.7]),
        ),
        'me',
      );
      expect(find.text('Share my live location'), findsNothing);
      expect(find.textContaining('not sharing'), findsOneWidget);
    });

    testWidgets('the assigned provider can share their location', (
      tester,
    ) async {
      final job = startedJob().copyWith(
        jobLocation: const GeoPoint(coordinates: [85.32, 27.7]),
      );
      await pumpDetail(tester, job, 'p');
      expect(find.text('Share my live location'), findsOneWidget);
    });
  });

  group('OTP screen', () {
    testWidgets('submits by itself once six digits are entered', (
      tester,
    ) async {
      final auth = FakeAuth();
      await pumpApp(
        tester,
        const OtpScreen(phone: '+9779812345678'),
        overrides: [authControllerProvider.overrideWith(() => auth)],
      );

      await tester.enterText(find.byKey(const Key('otp-field')), '12345');
      await tester.pump();
      expect(auth.codes, isEmpty);

      await tester.enterText(find.byKey(const Key('otp-field')), '123456');
      await tester.pump();
      expect(auth.codes, ['123456']);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a wrong code shows why and clears the boxes', (tester) async {
      final auth = FakeAuth(
        failWith: const ApiException(message: 'code is incorrect or expired'),
      );
      await pumpApp(
        tester,
        const OtpScreen(phone: '+9779812345678'),
        overrides: [authControllerProvider.overrideWith(() => auth)],
      );

      await tester.enterText(find.byKey(const Key('otp-field')), '000000');
      await tester.pump();
      await tester.pump();

      expect(find.text('code is incorrect or expired'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('otp-field')),
      );
      expect(field.controller!.text, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('resend appears only after the wait', (tester) async {
      final repo = MockAuthRepo();
      when(() => repo.requestOtp(any())).thenAnswer((_) async {});
      await pumpApp(
        tester,
        const OtpScreen(phone: '+9779812345678'),
        overrides: [
          authControllerProvider.overrideWith(FakeAuth.new),
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      expect(find.text('Resend code'), findsNothing);

      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Resend code'), findsOneWidget);

      await tester.tap(find.text('Resend code'));
      await tester.pump();
      await tester.pump();

      verify(() => repo.requestOtp('+9779812345678')).called(1);
      expect(find.text('Resend code'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('job money actions', () {
    late MockJobs jobs;

    setUp(() => jobs = MockJobs());

    List detailOverrides(Job job, List<Bid> bids) => [
      authControllerProvider.overrideWith(() => FakeAuth(user: me)),
      jobRepositoryProvider.overrideWithValue(jobs),
      jobDetailProvider('j').overrideWith((_) async => job),
      jobBidsProvider('j').overrideWith((_) async => bids),
    ];

    testWidgets('accepting a bid asks first, and "not now" does nothing', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detailOverrides(openJob(), [bid]),
      );

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(find.text('Accept this bid?'), findsOneWidget);
      expect(find.textContaining('stays on hold'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      verifyNever(() => jobs.acceptBid(any(), any()));
    });

    testWidgets('confirming the sheet accepts the bid', (tester) async {
      when(() => jobs.acceptBid('j', 'b')).thenAnswer((_) async {});
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detailOverrides(openJob(), [bid]),
      );

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept and pay Rs 1,500.00'));
      await tester.pumpAndSettle();

      verify(() => jobs.acceptBid('j', 'b')).called(1);
    });

    testWidgets('a low balance points to the wallet', (tester) async {
      when(() => jobs.acceptBid('j', 'b')).thenThrow(
        const ApiException(message: 'too low', code: 'insufficient_funds'),
      );
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detailOverrides(openJob(), [bid]),
      );

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept and pay Rs 1,500.00'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Add money in the Wallet tab'),
        findsOneWidget,
      );
    });

    testWidgets('confirming completion asks first', (tester) async {
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detailOverrides(startedJob(), []),
      );

      await tester.tap(find.text('Confirm job is finished'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      verifyNever(() => jobs.confirm(any()));
    });

    testWidgets('a dispute cannot be sent without a reason', (tester) async {
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detailOverrides(startedJob(), []),
      );

      await tester.tap(find.text('Raise a dispute'));
      await tester.pumpAndSettle();

      final send = find.widgetWithText(FilledButton, 'Raise dispute');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Still leaking');
      await tester.pump();
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
    });

    testWidgets('nobody is offered cancel once completion is confirmed', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detailOverrides(
          startedJob().copyWith(providerConfirmedAt: DateTime.now()),
          [],
        ),
      );

      expect(find.text('Cancel job'), findsNothing);
      expect(find.text('Raise a dispute'), findsOneWidget);
    });
  });

  group('after the job', () {
    late MockJobs jobs;

    setUp(() => jobs = MockJobs());

    Job finished({bool reviewed = false, DateTime? warrantyEnds}) =>
        startedJob().copyWith(
          status: JobStatus.completed,
          reviewed: reviewed,
          warrantyEndsAt:
              warrantyEnds ?? DateTime.now().add(const Duration(days: 20)),
        );

    List detail(Job job) => [
      authControllerProvider.overrideWith(() => FakeAuth(user: me)),
      jobRepositoryProvider.overrideWithValue(jobs),
      jobDetailProvider('j').overrideWith((_) async => job),
      jobBidsProvider('j').overrideWith((_) async => []),
      providerDetailProvider('p').overrideWith(
        (_) async => (const PublicProfile(id: 'p', name: 'Ram'), <Review>[]),
      ),
    ];

    testWidgets('a review needs a star rating', (tester) async {
      when(
        () => jobs.review(
          'j',
          rating: 4,
          tags: any(named: 'tags'),
          comment: any(named: 'comment'),
        ),
      ).thenAnswer((_) async {});
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detail(finished()),
      );

      await tester.tap(find.text('Rate your provider'));
      await tester.pumpAndSettle();
      final post = find.widgetWithText(FilledButton, 'Post review');
      expect(tester.widget<FilledButton>(post).onPressed, isNull);

      await tester.tap(find.byTooltip('4 out of 5'));
      await tester.pump();
      await tester.tap(find.text('On time'));
      await tester.pump();
      await tester.tap(post);
      await tester.pumpAndSettle();

      final call = verify(
        () => jobs.review(
          'j',
          rating: 4,
          tags: captureAny(named: 'tags'),
          comment: any(named: 'comment'),
        ),
      );
      expect(call.captured.single, ['On time']);
    });

    testWidgets('nobody is asked to rate twice', (tester) async {
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detail(finished(reviewed: true)),
      );
      expect(find.text('Rate your provider'), findsNothing);
    });

    testWidgets('a problem can be reported inside the guarantee', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detail(finished()),
      );
      expect(find.text('Report a problem'), findsOneWidget);
    });

    testWidgets('the guarantee option goes when it expires', (tester) async {
      await pumpApp(
        tester,
        const JobDetailScreen(jobId: 'j'),
        overrides: detail(
          finished(
            warrantyEnds: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ),
      );
      expect(find.text('Report a problem'), findsNothing);
    });
  });

  testWidgets('bids show who is bidding and whether parts are included', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const JobDetailScreen(jobId: 'j'),
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuth(user: me)),
        jobDetailProvider('j').overrideWith((_) async => openJob()),
        jobBidsProvider('j').overrideWith(
          (_) async => [
            bid.copyWith(
              partsIncluded: true,
              note: 'Washer included',
              provider: const PublicProfile(
                id: 'p',
                name: 'Ram Shrestha',
                rating: 4.8,
                reviewCount: 12,
                jobsCompleted: 31,
              ),
            ),
          ],
        ),
      ],
    );

    expect(find.text('Ram Shrestha'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Parts included'), findsOneWidget);
    expect(find.text('Washer included'), findsOneWidget);
  });

  testWidgets('a provider with no reviews is shown as new, not as zero', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const JobDetailScreen(jobId: 'j'),
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuth(user: me)),
        jobDetailProvider('j').overrideWith((_) async => openJob()),
        jobBidsProvider('j').overrideWith(
          (_) async => [
            bid.copyWith(
              provider: const PublicProfile(id: 'p', name: 'Ram'),
            ),
          ],
        ),
      ],
    );

    expect(find.text('New on Subidha360'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
  });

  testWidgets('providers can find the jobs they won', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: JobFeedTab()),
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuth(user: me)),
        jobFeedProvider.overrideWith((_) async => []),
        assignedJobsProvider.overrideWith(
          (_) async => [startedJob().copyWith(description: 'Won job')],
        ),
      ],
    );

    expect(find.text('Won job'), findsNothing);
    await tester.tap(find.text('My work'));
    await tester.pumpAndSettle();
    expect(find.text('Won job'), findsOneWidget);
  });

  testWidgets('posting a job explains what is missing', (tester) async {
    await pumpApp(
      tester,
      const CreateJobScreen(),
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuth(user: me)),
      ],
    );

    await tester.tap(find.text('Post job and get bids'));
    await tester.pump();

    expect(find.text('Choose a service'), findsOneWidget);
    expect(find.text('Choose an area'), findsOneWidget);
    expect(find.text('Add the address'), findsOneWidget);
  });

  testWidgets('fields off screen on a tiny phone are still validated', (
    tester,
  ) async {
    final jobs = MockJobs();
    await pumpApp(
      tester,
      const CreateJobScreen(initialCategory: 1),
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuth(user: me)),
        jobRepositoryProvider.overrideWithValue(jobs),
      ],
    );
    // Small enough that the address field is past a ListView's build range.
    tester.view.physicalSize = const Size(320, 200) * 2;
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'Leaking tap');
    await tester.tap(find.text('Post job and get bids'));
    await tester.pump();

    verifyNever(
      () => jobs.create(
        categoryId: any(named: 'categoryId'),
        description: any(named: 'description'),
        address: any(named: 'address'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
      ),
    );
  });

  test('phone numbers are formatted for reading', () {
    expect('+9779812345678'.asDisplayPhone, '+977 981-234-5678');
    expect('12345'.asDisplayPhone, '12345');
  });
}
