import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subidha360/core/providers/core_providers.dart';
import 'package:subidha360/core/providers/role_provider.dart';
import 'package:subidha360/core/l10n/tr.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/core/widgets/photo.dart';
import 'package:subidha360/core/widgets/sheets.dart';
import 'package:subidha360/features/auth/domain/user.dart';
import 'package:subidha360/features/auth/presentation/otp_screen.dart';
import 'package:subidha360/features/auth/presentation/phone_screen.dart';
import 'package:subidha360/features/auth/presentation/provider_setup_screen.dart';
import 'package:subidha360/features/auth/providers/auth_controller.dart';
import 'package:subidha360/features/catalog/data/catalog_repository.dart';
import 'package:subidha360/features/catalog/domain/catalog.dart';
import 'package:subidha360/features/catalog/presentation/landing_page.dart';
import 'package:subidha360/features/catalog/presentation/service_detail_page.dart';
import 'package:subidha360/features/catalog/presentation/services_page.dart';
import 'package:subidha360/features/home/presentation/home_screen.dart';
import 'package:subidha360/features/info/presentation/info_pages.dart';
import 'package:subidha360/features/jobs/domain/bid.dart';
import 'package:subidha360/features/jobs/domain/chat_message.dart';
import 'package:subidha360/features/jobs/domain/job.dart';
import 'package:subidha360/features/jobs/domain/provider_profile.dart';
import 'package:subidha360/features/jobs/presentation/bid_sheet.dart';
import 'package:subidha360/features/jobs/presentation/chat_screen.dart';
import 'package:subidha360/features/jobs/presentation/create_job_screen.dart';
import 'package:subidha360/features/jobs/presentation/job_detail_screen.dart';
import 'package:subidha360/features/jobs/presentation/job_map.dart';
import 'package:subidha360/features/jobs/presentation/review_sheet.dart';
import 'package:subidha360/features/jobs/providers/job_providers.dart';
import 'package:subidha360/features/notifications/data/notification_repository.dart';
import 'package:subidha360/features/provider/data/provider_api.dart';
import 'package:subidha360/features/notifications/domain/app_notification.dart';
import 'package:subidha360/features/wallet/data/wallet_repository.dart';
import 'package:subidha360/features/wallet/domain/wallet.dart';

import '../support/memory_token_storage.dart';
import 'provider_preview_test.dart' show FakeProviderApi;

/// Renders every screen to test/previews/out for visual review, and fails if any
/// screen overflows on a small phone with large text. It needs real fonts, so
/// run it with: $env:PREVIEW='1'; flutter test test/previews --update-goldens
class FakeAuth extends AuthController {
  FakeAuth(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

const seekerUser = User(
  id: 'me',
  phoneNumber: '+9779812345678',
  hasProviderProfile: false,
  displayName: 'Sita Gurung',
);
const bothUser = User(
  id: 'me',
  phoneNumber: '+9779812345678',
  hasProviderProfile: true,
  displayName: 'Sita Gurung',
);

final now = DateTime.now();
DateTime ago(Duration d) => now.subtract(d);

CatalogService svc(
  String id,
  int category,
  String name,
  int from,
  int to, {
  bool popular = true,
}) => CatalogService(
  id: id,
  name: name,
  summary: 'Stop a dripping or loose tap, mixer or shower head at home.',
  categoryId: category,
  guideFromPaisa: from,
  guideToPaisa: to,
  symptoms: const ['tap dripping', 'mixer loose', 'water not stopping'],
  includes: const ['Finding the cause', 'Replacing seals', 'Testing for leaks'],
  popular: popular,
);

final catalog = [
  CatalogCategory(
    id: 1,
    slug: 'plumbing',
    name: 'Plumbing',
    tagline: 'Leaks, taps, tanks and pumps',
    services: [
      svc('tap-leak', 1, 'Leaking tap repair', 40000, 120000),
      svc('blocked-drain', 1, 'Blocked drain clearing', 60000, 250000),
      svc('water-pump', 1, 'Water pump repair', 80000, 350000, popular: false),
    ],
  ),
  CatalogCategory(
    id: 2,
    slug: 'electrical',
    name: 'Electrical',
    tagline: 'Wiring, lights and power faults',
    services: [
      svc('power-trip', 2, 'Power fault finding', 50000, 250000),
      svc('fan-light', 2, 'Fan and light fitting', 30000, 150000),
    ],
  ),
  CatalogCategory(
    id: 3,
    slug: 'cleaning',
    name: 'Cleaning',
    tagline: 'Homes, offices and move-ins',
    services: [svc('deep-clean', 3, 'Full home deep clean', 250000, 900000)],
  ),
];

Job job(
  String id, {
  JobStatus status = JobStatus.broadcasting,
  String seekerId = 'me',
  String? providerId,
  int category = 1,
  String description = 'Kitchen tap is leaking under the sink',
  String address = 'Baneshwor Height, Kathmandu',
  int bids = 0,
  int escrow = 0,
  Duration age = const Duration(hours: 2),
  DateTime? providerConfirmed,
  DateTime? autoRelease,
  DateTime? selection,
  DateTime? warrantyEnds,
  bool reviewed = false,
  String? date,
  String? slot,
}) => Job(
  id: id,
  seekerId: seekerId,
  categoryId: category,
  status: status,
  description: description,
  address: address,
  bidCount: bids,
  escrowAmountPaisa: escrow,
  jobLocation: const GeoPoint(coordinates: [85.324, 27.7172]),
  createdAt: ago(age),
  providerId: providerId,
  providerConfirmedAt: providerConfirmed,
  autoReleaseAt: autoRelease,
  selectionDeadline: selection,
  warrantyEndsAt: warrantyEnds,
  reviewed: reviewed,
  preferredDate: date,
  preferredSlot: slot,
);

final myJobs = [
  job('a', bids: 3, selection: now.add(const Duration(hours: 20))),
  job(
    'b',
    status: JobStatus.inProgress,
    category: 2,
    description: 'Replace the distribution board in a two-storey house',
    escrow: 450000,
    providerId: 'p',
    age: const Duration(hours: 26),
  ),
  job(
    'c',
    status: JobStatus.completed,
    category: 3,
    description: 'Deep clean after moving in',
    escrow: 280000,
    age: const Duration(days: 6),
  ),
];

final feed = [
  job(
    'f1',
    seekerId: 'other',
    bids: 2,
    description: 'Water pump not starting',
    address: 'Lazimpat, Kathmandu',
    age: const Duration(minutes: 12),
  ),
  job(
    'f2',
    seekerId: 'other',
    category: 4,
    description: 'Fix two loose wardrobe doors',
    address: 'Jawalakhel, Lalitpur',
    age: const Duration(hours: 3),
    date: '2026-11-09',
    slot: '10-12',
  ),
];

const ramProfile = PublicProfile(
  id: 'p1',
  name: 'Ram Shrestha',
  bio: 'Plumbing and water pumps for homes across the valley.',
  yearsExperience: 8,
  verified: true,
  rating: 4.8,
  reviewCount: 12,
  jobsCompleted: 31,
);

const newProfile = PublicProfile(id: 'p2', name: 'Bishal Tamang');

Bid bid(
  String id,
  int amount, {
  String status = 'PENDING',
  bool parts = false,
  String note = '',
  PublicProfile? provider,
}) => Bid(
  id: id,
  jobId: 'a',
  providerId: id,
  amountPaisa: amount,
  status: status,
  partsIncluded: parts,
  note: note,
  provider: provider,
  createdAt: ago(const Duration(minutes: 40)),
);

final wallet = Wallet(
  balancePaisa: 1245000,
  transactions: [
    WalletTransaction(
      transactionId: '1',
      amountPaisa: -450000,
      transactionType: 'ESCROW_HOLD',
      createdAt: ago(const Duration(hours: 5)),
    ),
    WalletTransaction(
      transactionId: '2',
      amountPaisa: 252000,
      transactionType: 'PAYOUT',
      createdAt: ago(const Duration(days: 1)),
    ),
  ],
);

AppNotification note(String type, String title, String body, Duration age) =>
    AppNotification(
      id: type,
      type: type,
      title: title,
      body: body,
      createdAt: ago(age),
      jobId: 'a',
    );

final inbox = [
  note(
    'completion.confirm_needed',
    'Confirm your job',
    'The provider marked your job as finished. Payment releases '
        'automatically in 72 hours unless you raise a dispute.',
    const Duration(minutes: 9),
  ),
  note(
    'bid.received',
    'New bid',
    'A provider sent a bid on your job.',
    const Duration(hours: 1),
  ),
];

final messages = [
  ChatMessage(
    id: '1',
    senderId: 'me',
    body: 'The gate code is 4412.',
    createdAt: ago(const Duration(minutes: 30)),
  ),
  ChatMessage(
    id: '2',
    senderId: 'p',
    body: 'Thanks, I will be there by 10.',
    createdAt: ago(const Duration(minutes: 28)),
  ),
];

class Scene {
  const Scene(
    this.name,
    this.child, {
    this.user = seekerUser,
    this.role = UiRole.seeker,
    this.jobs,
    this.bids = const [],
    this.detail,
    this.tall = false,
  });

  final String name;
  final Widget child;
  final User? user;
  final UiRole role;
  final List<Job>? jobs;
  final List<Bid> bids;
  final Job? detail;

  /// Long public pages render at full height.
  final bool tall;
}

Widget sheet(Widget child) => Scaffold(
  backgroundColor: Colors.black54,
  body: Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Builder(
        builder: (context) => Material(
          color: Theme.of(context).colorScheme.surface,
          shape: Theme.of(context).bottomSheetTheme.shape,
          child: Padding(padding: const EdgeInsets.only(top: 32), child: child),
        ),
      ),
    ),
  ),
);

final scenes = [
  const Scene('01_landing', LandingPage(), user: null, tall: true),
  const Scene('02_services', ServicesPage(), user: null),
  const Scene('03_search', ServicesPage(query: 'tap dripping'), user: null),
  const Scene(
    '04_service_detail',
    ServiceDetailPage(serviceId: 'tap-leak'),
    user: null,
    tall: true,
  ),
  const Scene('05_guarantee', GuaranteePage(), user: null, tall: true),
  const Scene('06_become_provider', BecomeProviderPage(), user: null),
  const Scene('06b_credits', PhotoCreditsPage(), user: null),
  const Scene('07_phone', PhoneScreen(), user: null),
  const Scene('08_otp', OtpScreen(phone: '+9779812345678'), user: null),
  const Scene('09_jobs', HomeScreen()),
  Scene('10_jobs_empty', const HomeScreen(), jobs: const []),
  Scene(
    '11_provider_feed',
    const HomeScreen(),
    user: bothUser,
    role: UiRole.provider,
  ),
  const Scene('12_create_job', CreateJobScreen(initialCategory: 1), tall: true),
  const Scene(
    '13_create_from_service',
    CreateJobScreen(serviceId: 'tap-leak', date: '2026-11-09', slot: '10-12'),
  ),
  Scene(
    '14_job_bids',
    const JobDetailScreen(jobId: 'a'),
    detail: job('a', bids: 3, selection: now.add(const Duration(hours: 20))),
    bids: [
      bid(
        '1',
        180000,
        parts: true,
        note: 'New washer and seal included. I can come today.',
        provider: ramProfile,
      ),
      bid('2', 150000, provider: newProfile),
    ],
  ),
  Scene(
    '15_job_must_respond',
    const JobDetailScreen(jobId: 'a'),
    detail: job(
      'a',
      status: JobStatus.inProgress,
      escrow: 150000,
      providerId: 'p',
      providerConfirmed: ago(const Duration(hours: 5)),
      autoRelease: now.add(const Duration(hours: 67)),
      date: '2026-11-09',
      slot: '10-12',
    ),
  ),
  Scene(
    '16_job_provider_open',
    const JobDetailScreen(jobId: 'a'),
    user: bothUser,
    detail: job('a', seekerId: 'other', bids: 2),
  ),
  Scene(
    '17_job_completed',
    const JobDetailScreen(jobId: 'a'),
    detail: job(
      'a',
      status: JobStatus.completed,
      escrow: 150000,
      providerId: 'p',
      warrantyEnds: now.add(const Duration(days: 29)),
    ),
  ),
  const Scene('18_chat', ChatScreen(jobId: 'a')),
  const Scene('19_wallet', HomeScreen(initialTab: 2)),
  const Scene('20_inbox', HomeScreen(initialTab: 3)),
  const Scene('21_profile', HomeScreen(initialTab: 4)),
  const Scene('26_my_jobs', HomeScreen(initialTab: 1)),
  const Scene('27_home_full', HomeScreen(), tall: true),
  Scene(
    '28_provider_full',
    const HomeScreen(),
    user: bothUser,
    role: UiRole.provider,
    tall: true,
  ),
  const Scene('29_wallet_full', HomeScreen(initialTab: 2), tall: true),
  const Scene('22_provider_setup', ProviderSetupScreen(), tall: true),
  Scene('23_bid_sheet', sheet(const BidSheet())),
  Scene('24_review_sheet', sheet(const ReviewSheet())),
  Scene(
    '25_confirm_sheet',
    sheet(
      const ConfirmSheet(
        title: 'Accept this bid?',
        message:
            'Rs 1,500.00 moves from your wallet and stays on hold until the '
            'job is done. Other bids will be declined.',
        action: 'Accept and pay Rs 1,500.00',
      ),
    ),
  ),
];

Future<void> loadFonts() async {
  final family = FontLoader(AppTheme.fontFamily);
  for (final weight in [400, 500, 600, 700, 800]) {
    final bytes = File('assets/fonts/PlusJakartaSans-$weight.ttf')
        .readAsBytesSync();
    family.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await family.load();

  final nepali = FontLoader(AppTheme.fontFallback.first);
  for (final weight in ['Regular', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/NotoSansDevanagari-$weight.ttf')
        .readAsBytesSync();
    nepali.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await nepali.load();

  final root =
      Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\revah\develop\flutter';
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ).readAsBytesSync();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(icons)))).load();
}

Future<void> pumpScene(
  WidgetTester tester,
  Scene scene, {
  required ThemeData theme,
  required Size size,
  double dpr = 2,
  double textScale = 1,
  bool decodeImages = false,
}) async {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  // MaterialApp reads text size from the platform, not a parent MediaQuery.
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  SharedPreferences.setMockInitialValues({
    'active_ui_state': scene.role.name,
    'language': appLanguage.code,
  });
  final prefs = await SharedPreferences.getInstance();
  final detail = scene.detail ?? myJobs.first;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        authControllerProvider.overrideWith(() => FakeAuth(scene.user)),
        catalogProvider.overrideWith((_) async => catalog),
        myJobsProvider.overrideWith((_) async => scene.jobs ?? myJobs),
        jobFeedProvider.overrideWith((_) async => feed),
        assignedJobsProvider.overrideWith((_) async => myJobs),
        jobDetailProvider('a').overrideWith((_) async => detail),
        jobBidsProvider('a').overrideWith((_) async => scene.bids),
        jobMessagesProvider('a').overrideWith((_) async => messages),
        providerDetailProvider('p')
            .overrideWith((_) async => (ramProfile, const <Review>[])),
        walletProvider.overrideWith((_) async => wallet),
        providerApiProvider.overrideWithValue(
          FakeProviderApi(status: 'APPROVED'),
        ),
        providerDetailProvider('me').overrideWith(
          (_) async => (
            ramProfile,
            [
              Review(
                rating: 5,
                createdAt: DateTime.now().subtract(const Duration(days: 2)),
                tags: const ['On time'],
                comment: 'Fixed the pump quickly and explained everything.',
              ),
              Review(
                rating: 4,
                createdAt: DateTime.now().subtract(const Duration(days: 9)),
                comment: 'Good work, came a little late.',
              ),
            ],
          ),
        ),
        inboxProvider.overrideWith((_) async => inbox),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: scene.child,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (decodeImages) {
    // Tests never decode images unless asked to, which would leave them blank.
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
      for (final asset in [Photos.hero, Photos.himalaya]) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> tearDownScene(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  final skip = Platform.environment['PREVIEW'] != '1';

  setUpAll(() async {
    mapTilesEnabled = false;
    if (!skip) await loadFonts();
  });

  for (final scene in scenes) {
    testWidgets('phone ${scene.name}', skip: skip, (tester) async {
      await pumpScene(
        tester,
        scene,
        theme: AppTheme.light(),
        size: Size(412, scene.tall ? 4300 : 880),
        decodeImages: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/phone/${scene.name}.png'),
      );
      await tearDownScene(tester);
    });

    testWidgets('desktop ${scene.name}', skip: skip, (tester) async {
      await pumpScene(
        tester,
        scene,
        theme: AppTheme.light(),
        size: Size(1280, scene.tall ? 4200 : 820),
        dpr: 1,
        decodeImages: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/desktop/${scene.name}.png'),
      );
      await tearDownScene(tester);
    });

    testWidgets('nepali ${scene.name}', skip: skip, (tester) async {
      appLanguage = AppLanguage.nepali;
      addTearDown(() => appLanguage = AppLanguage.english);
      await pumpScene(
        tester,
        scene,
        theme: AppTheme.light(),
        size: scene.tall ? const Size(412, 4300) : const Size(412, 880),
        dpr: 1,
        decodeImages: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/nepali/${scene.name}.png'),
      );
      await tearDownScene(tester);
    });

    testWidgets('nepali small phone ${scene.name}', skip: skip, (tester) async {
      appLanguage = AppLanguage.nepali;
      addTearDown(() => appLanguage = AppLanguage.english);
      await pumpScene(
        tester,
        scene,
        theme: AppTheme.light(),
        size: const Size(320, 568),
        textScale: 1.4,
        dpr: 1,
      );
      await tearDownScene(tester);
    });

    testWidgets('small phone, large text ${scene.name}', skip: skip, (
      tester,
    ) async {
      await pumpScene(
        tester,
        scene,
        theme: AppTheme.light(),
        size: const Size(320, 568),
        textScale: 1.4,
        dpr: 1,
      );
      await tearDownScene(tester);
    });

    testWidgets('tablet ${scene.name}', skip: skip, (tester) async {
      await pumpScene(
        tester,
        scene,
        theme: AppTheme.light(),
        size: const Size(900, 700),
        dpr: 1,
      );
      await tearDownScene(tester);
    });
  }
}
