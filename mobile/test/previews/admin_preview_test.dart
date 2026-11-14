import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subidha360/core/providers/core_providers.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/features/admin/data/admin_api.dart';
import 'package:subidha360/features/admin/domain/admin_models.dart';
import 'package:subidha360/features/admin/presentation/jobs_pages.dart';
import 'package:subidha360/features/admin/presentation/money_pages.dart';
import 'package:subidha360/features/admin/presentation/overview_page.dart';
import 'package:subidha360/features/admin/presentation/people_pages.dart';
import 'package:subidha360/features/admin/presentation/withdrawals_page.dart';
import 'package:subidha360/features/auth/domain/user.dart';
import 'package:subidha360/features/auth/providers/auth_controller.dart';

import '../support/memory_token_storage.dart';
import 'screens_preview_test.dart' show FakeAuth, loadFonts;

/// Admin screens, fed with JSON shaped exactly like the Go API sends, so these
/// also check the models read real responses.
/// Run with: $env:PREVIEW='1'; flutter test test/previews --update-goldens
const adminUser = User(
  id: 'admin',
  phoneNumber: '+9779800000001',
  hasProviderProfile: false,
  displayName: 'Asha Admin',
  isAdmin: true,
);

final _now = DateTime.now().toUtc();
String _ago(Duration d) => _now.subtract(d).toIso8601String();
String _day(int back) {
  final d = _now
      .add(const Duration(hours: 5, minutes: 45))
      .subtract(Duration(days: back));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> _dayJson(int back, int i) => {
  'date': _day(back),
  'jobs_posted': [3, 5, 2, 7, 4, 6, 9, 5, 8, 4, 6, 11, 7, 9][i % 14],
  'jobs_completed': [1, 3, 2, 4, 2, 5, 6, 3, 5, 3, 4, 7, 5, 6][i % 14],
  'jobs_cancelled': i % 4 == 0 ? 1 : 0,
  'new_users': [4, 2, 6, 3, 5, 8, 4, 2, 7, 5, 3, 9, 6, 4][i % 14],
  'gmv_paisa': [
    120000,
    340000,
    95000,
    410000,
    220000,
    515000,
    640000,
    300000,
    480000,
    260000,
    390000,
    720000,
    455000,
    610000,
  ][i % 14],
  'commission_paisa': [
    12000,
    34000,
    9500,
    41000,
    22000,
    51500,
    64000,
    30000,
    48000,
    26000,
    39000,
    72000,
    45500,
    61000,
  ][i % 14],
  'payouts_paisa': [
    108000,
    306000,
    85500,
    369000,
    198000,
    463500,
    576000,
    270000,
    432000,
    234000,
    351000,
    648000,
    409500,
    549000,
  ][i % 14],
  'refunds_paisa': i % 5 == 0 ? 50000 : 0,
  'top_ups_paisa': 500000,
};

final _money = {
  'commission_paisa': 1284500,
  'escrow_held_paisa': 465000,
  'wallets_paisa': 3820000,
  'withdrawals_waiting_paisa': 1700000,
  'topped_up_paisa': 5569500,
  'books_balance_paisa': 0,
  'mismatched_accounts': <String>[],
  'unbalanced_postings': <String>[],
  'healthy': true,
};

final overviewJson = {
  'users': {
    'total': 412,
    'providers': 58,
    'verified_providers': 31,
    'suspended': 2,
    'new_this_week': 37,
  },
  'jobs_by_status': {
    'BROADCASTING': 6,
    'ESCALATING': 2,
    'ACCEPTED': 9,
    'IN_PROGRESS': 4,
    'DISPUTED': 1,
    'COMPLETED': 233,
    'CANCELLED': 18,
  },
  'attention': {
    'disputes': 1,
    'cancellation_reviews': 1,
    'guarantee_claims': 2,
    'unmatched_jobs': 1,
    'unverified_providers': 27,
    'identity_checks': 3,
    'withdrawals': 2,
  },
  'money': _money,
  'last_30_days': {
    ..._dayJson(0, 6),
    'date': '',
    'jobs_posted': 164,
    'jobs_completed': 101,
    'gmv_paisa': 9845000,
    'commission_paisa': 984500,
  },
  'days': [for (var i = 0; i < 14; i++) _dayJson(13 - i, i)],
};

Map<String, dynamic> _userJson(
  String id,
  String name,
  String phone, {
  bool provider = false,
  bool verified = false,
  bool admin = false,
  bool suspended = false,
  int jobs = 0,
  double rating = 0,
  int reviews = 0,
}) => {
  'id': id,
  'phone': phone,
  'name': name,
  'is_provider': provider,
  'is_verified': verified,
  'is_admin': admin,
  if (suspended)
    'suspension': {
      'reason': 'Asked customers to pay cash outside the app',
      'by': 'admin',
      'at': _ago(const Duration(days: 2)),
    },
  'online': provider,
  'rating': rating,
  'review_count': reviews,
  'jobs_completed': jobs,
  'created_at': _ago(Duration(days: jobs + 3)),
};

final usersJson = {
  'items': [
    _userJson(
      'u1',
      'Ram Bahadur Thapa',
      '+9779841234567',
      provider: true,
      verified: true,
      jobs: 48,
      rating: 4.8,
      reviews: 41,
    ),
    _userJson('u2', 'Sita Gurung', '+9779812345678'),
    _userJson(
      'u3',
      'Hari Prasad Shrestha',
      '+9779803456789',
      provider: true,
      jobs: 3,
      rating: 4.0,
      reviews: 2,
    ),
    _userJson('u4', '', '+9779865432109'),
    _userJson(
      'u5',
      'Bikash Rai',
      '+9779851112233',
      provider: true,
      suspended: true,
      jobs: 12,
      rating: 3.1,
      reviews: 9,
    ),
    _userJson('admin', 'Asha Admin', '+9779800000001', admin: true),
  ],
  'page': 1,
  'has_more': true,
};

Map<String, dynamic> _person(String id, String name, String phone) => {
  'id': id,
  'name': name,
  'phone': phone,
};

Map<String, dynamic> _jobRow(
  String id,
  String status,
  String category,
  String desc, {
  bool disputed = false,
  bool review = false,
  bool claim = false,
  int price = 0,
  bool provider = true,
}) => {
  'id': id,
  'status': status,
  'category_id': 1,
  'category': category,
  'description': desc,
  'address': 'Baneshwor, Kathmandu',
  'seeker': _person('u2', 'Sita Gurung', '+9779812345678'),
  if (provider)
    'provider': _person('u1', 'Ram Bahadur Thapa', '+9779841234567'),
  'escrow_amount_paisa': price,
  'bid_count': 3,
  'disputed': disputed,
  'needs_review': review,
  'claim_open': claim,
  'created_at': _ago(const Duration(hours: 30)),
  'updated_at': _ago(const Duration(hours: 2)),
};

final jobsJson = {
  'items': [
    _jobRow(
      'j1-disputed-0001',
      'DISPUTED',
      'Plumbing',
      'Kitchen tap still leaking after repair, water on the floor',
      disputed: true,
      price: 120000,
    ),
    _jobRow(
      'j2',
      'CANCELLED',
      'Electrical',
      'MCB keeps tripping when the geyser is on',
      review: true,
      price: 80000,
    ),
    _jobRow(
      'j3',
      'COMPLETED',
      'Cleaning',
      'Full home deep clean before Tihar',
      claim: true,
      price: 650000,
    ),
    _jobRow(
      'j4',
      'MANUAL_FALLBACK',
      'Pest Control',
      'Termites in the wooden window frames',
      provider: false,
    ),
  ],
  'page': 1,
  'has_more': false,
};

Map<String, dynamic> _entry(
  String type,
  String account,
  int amount, {
  String user = '',
  String userName = '',
  String job = 'j1-disputed-0001',
  int hoursAgo = 30,
}) => {
  'id': '$type$account$amount',
  'group': 'g',
  'account': account,
  if (user.isNotEmpty) 'user_id': user,
  if (userName.isNotEmpty) 'user_name': userName,
  'amount_paisa': amount,
  'type': type,
  if (job.isNotEmpty) 'job_id': job,
  'created_at': _ago(Duration(hours: hoursAgo)),
};

final jobDetailJson = {
  'job': {
    'id': 'j1-disputed-0001',
    'seeker_id': 'u2',
    'category_id': 1,
    'status': 'DISPUTED',
    'description': 'Kitchen tap still leaking after repair, water on the floor',
    'address': 'House 14, Shantinagar Marg, Baneshwor, Kathmandu',
    'job_location': {
      'type': 'Point',
      'coordinates': [85.3410, 27.6915],
    },
    'bid_count': 3,
    'provider_id': 'u1',
    'escrow_amount_paisa': 120000,
    'provider_confirmed_at': _ago(const Duration(hours: 20)),
    'preferred_date': _day(1),
    'preferred_slot': '10-12',
    'photo_ids': ['p1', 'p2'],
    'dispute': {
      'raised_by': 'u2',
      'reason': 'The tap leaks again the same evening. Provider is not answering calls.',
      'at': _ago(const Duration(hours: 6)),
    },
    'reviewed': false,
    'escrow_review_required': false,
    'created_at': _ago(const Duration(hours: 30)),
    'updated_at': _ago(const Duration(hours: 6)),
  },
  'summary': _jobRow(
    'j1-disputed-0001',
    'DISPUTED',
    'Plumbing',
    'Kitchen tap still leaking after repair, water on the floor',
    disputed: true,
    price: 120000,
  ),
  'bids': [
    {
      'id': 'b1',
      'provider_id': 'u1',
      'provider': _person('u1', 'Ram Bahadur Thapa', '+9779841234567'),
      'amount_paisa': 120000,
      'status': 'ACCEPTED',
      'parts_included': true,
      'note': 'Will replace the cartridge and washer.',
      'created_at': _ago(const Duration(hours: 29)),
    },
    {
      'id': 'b2',
      'provider_id': 'u3',
      'provider': _person('u3', 'Hari Prasad Shrestha', '+9779803456789'),
      'amount_paisa': 90000,
      'status': 'REJECTED',
      'parts_included': false,
      'created_at': _ago(const Duration(hours: 28)),
    },
  ],
  'messages': [
    {
      'id': 'm1',
      'sender_id': 'u2',
      'body': 'Please bring a spare cartridge, it is a Jaquar mixer.',
      'created_at': _ago(const Duration(hours: 25)),
    },
    {
      'id': 'm2',
      'sender_id': 'u1',
      'body': 'OK didi, I will come at 10.',
      'created_at': _ago(const Duration(hours: 24)),
    },
    {
      'id': 'm3',
      'sender_id': 'u2',
      'body': 'It is leaking again. Can you come back today?',
      'created_at': _ago(const Duration(hours: 7)),
    },
  ],
  'ledger': [
    _entry(
      'ESCROW_HOLD',
      'user:u2',
      -120000,
      user: 'u2',
      userName: 'Sita Gurung',
    ),
    _entry('ESCROW_HOLD', 'escrow:j1-disputed-0001', 120000),
  ],
  'actions': <Map<String, dynamic>>[],
};

final personJson = {
  'user': _userJson(
    'u5',
    'Bikash Rai',
    '+9779851112233',
    provider: true,
    suspended: true,
    jobs: 12,
    rating: 3.1,
    reviews: 9,
  ),
  'provider_profile': {
    'service_area': {'type': 'Polygon', 'coordinates': []},
    'category_ids': [1, 2],
    'is_online': false,
    'bio': 'Plumber and electrician in Lalitpur for 8 years.',
    'years_experience': 8,
  },
  'balance_paisa': 1845000,
  'active_jobs': 1,
  'jobs': jobsJson['items'],
  'transactions': [
    _entry(
      'PAYOUT',
      'user:u5',
      108000,
      user: 'u5',
      userName: 'Bikash Rai',
      hoursAgo: 50,
    ),
    _entry(
      'PAYOUT',
      'user:u5',
      58500,
      user: 'u5',
      userName: 'Bikash Rai',
      job: 'j3',
      hoursAgo: 120,
    ),
  ],
  'reviews_received': [
    {
      '_id': 'j3',
      'job_id': 'j3',
      'seeker_id': 'u2',
      'rating': 2,
      'tags': ['Late'],
      'comment': 'Came two hours late and asked for cash.',
      'created_at': _ago(const Duration(days: 3)),
    },
  ],
  'actions': [
    {
      'id': 'a1',
      'admin_id': 'admin',
      'admin_name': 'Asha Admin',
      'action': 'user.suspend',
      'target_type': 'user',
      'target_id': 'u5',
      'detail': 'Asked customers to pay cash outside the app',
      'at': _ago(const Duration(days: 2)),
    },
  ],
};

final paymentsJson = {
  'items': [
    _entry('COMMISSION', 'system:commission', 6500, job: 'j3', hoursAgo: 1),
    _entry(
      'PAYOUT',
      'user:u1',
      58500,
      user: 'u1',
      userName: 'Ram Bahadur Thapa',
      job: 'j3',
      hoursAgo: 1,
    ),
    _entry('PAYOUT', 'escrow:j3', -65000, job: 'j3', hoursAgo: 1),
    _entry(
      'TOP_UP',
      'user:u2',
      500000,
      user: 'u2',
      userName: 'Sita Gurung',
      job: '',
      hoursAgo: 3,
    ),
    _entry('TOP_UP', 'external:gateway', -500000, job: '', hoursAgo: 3),
    _entry(
      'ESCROW_REFUND',
      'user:u2',
      80000,
      user: 'u2',
      userName: 'Sita Gurung',
      job: 'j2',
      hoursAgo: 8,
    ),
  ],
  'page': 1,
  'has_more': true,
};

final reportJson = {
  'from': _day(13),
  'to': _day(0),
  'totals': {
    ..._dayJson(0, 0),
    'jobs_posted': 86,
    'jobs_completed': 56,
    'jobs_cancelled': 4,
    'new_users': 72,
    'gmv_paisa': 5655000,
    'commission_paisa': 565500,
    'payouts_paisa': 5089500,
    'refunds_paisa': 150000,
    'top_ups_paisa': 7000000,
  },
  'days': [for (var i = 0; i < 14; i++) _dayJson(13 - i, i)],
  'categories': [
    {
      'category_id': 1,
      'name': 'Plumbing',
      'jobs_posted': 31,
      'jobs_completed': 22,
      'jobs_cancelled': 1,
      'completed_value_paisa': 1980000,
    },
    {
      'category_id': 3,
      'name': 'Cleaning',
      'jobs_posted': 19,
      'jobs_completed': 14,
      'jobs_cancelled': 2,
      'completed_value_paisa': 2240000,
    },
    {
      'category_id': 2,
      'name': 'Electrical',
      'jobs_posted': 17,
      'jobs_completed': 11,
      'jobs_cancelled': 0,
      'completed_value_paisa': 860000,
    },
    {
      'category_id': 8,
      'name': 'Pest Control',
      'jobs_posted': 0,
      'jobs_completed': 0,
      'jobs_cancelled': 0,
      'completed_value_paisa': 0,
    },
  ],
  'top_providers': [
    {
      'id': 'u1',
      'name': 'Ram Bahadur Thapa',
      'phone': '+9779841234567',
      'jobs_completed': 14,
      'completed_value_paisa': 1320000,
      'rating': 4.8,
      'verified': true,
    },
    {
      'id': 'u3',
      'name': 'Hari Prasad Shrestha',
      'phone': '+9779803456789',
      'jobs_completed': 6,
      'completed_value_paisa': 410000,
      'rating': 4.0,
      'verified': false,
    },
  ],
};

final actionsJson = {
  'items': [
    {
      'id': 'a1',
      'admin_id': 'admin',
      'admin_name': 'Asha Admin',
      'action': 'user.suspend',
      'target_type': 'user',
      'target_id': 'u5',
      'detail': 'Asked customers to pay cash outside the app',
      'at': _ago(const Duration(days: 2)),
    },
    {
      'id': 'a2',
      'admin_id': 'admin',
      'admin_name': 'Asha Admin',
      'action': 'provider.verify',
      'target_type': 'user',
      'target_id': 'u1',
      'detail': 'Citizenship card seen on video call',
      'at': _ago(const Duration(days: 4)),
    },
    {
      'id': 'a3',
      'admin_id': 'admin2',
      'admin_name': '',
      'action': 'job.resolve_escrow',
      'target_type': 'job',
      'target_id': 'j9',
      'detail': '60% to the provider: Most of the wiring was done',
      'at': _ago(const Duration(days: 6)),
    },
  ],
  'page': 1,
  'has_more': false,
};

final _withdrawalJson = {
  'id': 'w1',
  'user_id': 'u1',
  'person': _person('u1', 'Ram Bahadur Thapa', '+9779841234567'),
  'verified': true,
  'amount_paisa': 1250000,
  'destination': {
    'method': 'esewa',
    'wallet_id': '9841234567',
    'account_name': 'Ram Bahadur Thapa',
  },
  'status': 'PENDING',
  'created_at': _ago(const Duration(hours: 5)),
};

final checkPersonJson = {
  ...personJson,
  'user': {
    ..._userJson(
      'u1',
      'Ram Bahadur Thapa',
      '+9779841234567',
      provider: true,
      jobs: 48,
      rating: 4.8,
      reviews: 41,
    ),
    'check': 'PENDING',
  },
  'verification': {
    'status': 'PENDING',
    'submitted_at': _ago(const Duration(hours: 3)),
  },
  'documents': [
    {
      'id': 'd1',
      'kind': 'citizenship_front',
      'type': 'image/jpeg',
      'created_at': _ago(const Duration(hours: 4)),
    },
    {
      'id': 'd2',
      'kind': 'citizenship_back',
      'type': 'image/jpeg',
      'created_at': _ago(const Duration(hours: 4)),
    },
    {
      'id': 'd3',
      'kind': 'certificate',
      'label': 'CTEVT plumbing level 1',
      'type': 'application/pdf',
      'created_at': _ago(const Duration(hours: 4)),
    },
  ],
  'withdrawals': [_withdrawalJson],
  'availability': {
    'weekly': {
      'sun': ['08-10', '10-12'],
      'mon': ['08-10'],
    },
    'days_off': <String>[],
  },
};

/// A real photo, so document thumbnails render something.
final _sampleImage = File('assets/photos/cat_plumbing.jpg').readAsBytesSync();

class FakeAdminApi implements AdminApi {
  @override
  Future<Uint8List> document(String id) async => _sampleImage;
  @override
  Future<PageOf<WithdrawalRow>> withdrawals({
    String status = '',
    int page = 1,
  }) async => PageOf.fromJson({
    'items': [
      _withdrawalJson,
      {
        ..._withdrawalJson,
        'id': 'w2',
        'status': 'PAID',
        'reference': 'ESW-77812',
        'amount_paisa': 450000,
      },
    ],
    'page': 1,
    'has_more': false,
  }, WithdrawalRow.fromJson);
  @override
  Future<Overview> overview() async => Overview.fromJson(overviewJson);
  @override
  Future<PageOf<UserRow>> users({
    String q = '',
    String filter = '',
    int page = 1,
  }) async => PageOf.fromJson(usersJson, UserRow.fromJson);
  @override
  Future<UserDetail> user(String id) async =>
      UserDetail.fromJson(id == 'u1' ? checkPersonJson : personJson);
  @override
  Future<PageOf<JobRow>> jobs({
    String q = '',
    String status = '',
    int page = 1,
  }) async => PageOf.fromJson(jobsJson, JobRow.fromJson);
  @override
  Future<JobDetail> job(String id) async => JobDetail.fromJson(jobDetailJson);
  @override
  Future<PageOf<EntryRow>> payments({
    String type = '',
    String q = '',
    int page = 1,
  }) async => PageOf.fromJson(paymentsJson, EntryRow.fromJson);
  @override
  Future<Money> money() async => Money.fromJson(_money);
  @override
  Future<Report> report(String from, String to) async =>
      Report.fromJson(reportJson);
  @override
  Future<PageOf<AdminAction>> actions({
    String target = '',
    int page = 1,
  }) async => PageOf.fromJson(actionsJson, AdminAction.fromJson);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

typedef AdminScene = ({
  String name,
  Widget child,
  User user,
  double tallDesktop,
  double tallPhone,
});

final scenes = <AdminScene>[
  (
    name: 'person-check',
    child: const AdminPersonPage(id: 'u1'),
    user: adminUser,
    tallDesktop: 2400,
    tallPhone: 3600,
  ),
  (
    name: 'withdrawals',
    child: const AdminWithdrawalsPage(),
    user: adminUser,
    tallDesktop: 820,
    tallPhone: 1100,
  ),
  (
    name: 'overview',
    child: const AdminOverviewPage(),
    user: adminUser,
    tallDesktop: 1500,
    tallPhone: 3400,
  ),
  (
    name: 'people',
    child: const AdminPeoplePage(),
    user: adminUser,
    tallDesktop: 820,
    tallPhone: 1100,
  ),
  (
    name: 'person',
    child: const AdminPersonPage(id: 'u5'),
    user: adminUser,
    tallDesktop: 2100,
    tallPhone: 3000,
  ),
  (
    name: 'jobs',
    child: const AdminJobsPage(status: 'attention'),
    user: adminUser,
    tallDesktop: 820,
    tallPhone: 1000,
  ),
  (
    name: 'job',
    child: const AdminJobPage(id: 'j1'),
    user: adminUser,
    tallDesktop: 1900,
    tallPhone: 3000,
  ),
  (
    name: 'payments',
    child: const AdminPaymentsPage(),
    user: adminUser,
    tallDesktop: 1100,
    tallPhone: 1700,
  ),
  (
    name: 'reports',
    child: const AdminReportsPage(),
    user: adminUser,
    tallDesktop: 2300,
    tallPhone: 3600,
  ),
  (
    name: 'audit',
    child: const AdminAuditPage(),
    user: adminUser,
    tallDesktop: 820,
    tallPhone: 880,
  ),
  (
    name: 'not-admin',
    child: const AdminOverviewPage(),
    user: const User(
      id: 'x',
      phoneNumber: '+9779812345678',
      hasProviderProfile: false,
    ),
    tallDesktop: 820,
    tallPhone: 880,
  ),
];

Future<void> pumpAdmin(
  WidgetTester tester,
  AdminScene scene,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({'language': 'en'});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        dioProvider.overrideWithValue(Dio()),
        authControllerProvider.overrideWith(() => FakeAuth(scene.user)),
        adminApiProvider.overrideWithValue(FakeAdminApi()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: scene.child,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, context);
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final skip = Platform.environment['PREVIEW'] != '1';
  setUpAll(() async {
    if (!skip) await loadFonts();
  });

  for (final scene in scenes) {
    testWidgets('admin desktop ${scene.name}', skip: skip, (tester) async {
      await pumpAdmin(tester, scene, Size(1280, scene.tallDesktop));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/admin/desktop-${scene.name}.png'),
      );
    });
    testWidgets('admin phone ${scene.name}', skip: skip, (tester) async {
      await pumpAdmin(tester, scene, Size(412, scene.tallPhone));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/admin/phone-${scene.name}.png'),
      );
    });
    testWidgets('admin small phone, large text ${scene.name}', skip: skip, (
      tester,
    ) async {
      await pumpAdmin(tester, scene, const Size(320, 568), textScale: 1.4);
    });
  }

  testWidgets('admin decide sheet', skip: skip, (tester) async {
    await pumpAdmin(
      tester,
      scenes.firstWhere((s) => s.name == 'job'),
      const Size(1280, 900),
    );
    await tester.tap(find.text('Decide the payment'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('75%'));
    await tester.pump();
    expect(find.text('Rs 810.00 (75% less commission)'), findsOneWidget);
    expect(find.text('Rs 300.00'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/admin/desktop-decide.png'),
    );
  });
}
