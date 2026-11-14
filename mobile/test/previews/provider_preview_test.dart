import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subidha360/core/l10n/tr.dart';
import 'package:subidha360/core/providers/core_providers.dart';
import 'package:subidha360/core/providers/role_provider.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/features/auth/domain/user.dart';
import 'package:subidha360/features/auth/providers/auth_controller.dart';
import 'package:subidha360/features/home/presentation/profile_tab.dart';
import 'package:subidha360/features/provider/data/provider_api.dart';
import 'package:subidha360/features/provider/domain/provider_models.dart';
import 'package:subidha360/features/provider/presentation/availability_screen.dart';
import 'package:subidha360/features/provider/presentation/earnings_screen.dart';
import 'package:subidha360/features/provider/presentation/gallery_screen.dart';
import 'package:subidha360/features/provider/presentation/verification_screen.dart';

import '../support/memory_token_storage.dart';
import 'screens_preview_test.dart' show FakeAuth, loadFonts;

/// The provider's own tools, fed with JSON shaped like the Go API's.
/// Run with: $env:PREVIEW='1'; flutter test test/previews --update-goldens
const providerUser = User(
  id: 'p1',
  phoneNumber: '+9779841234567',
  hasProviderProfile: true,
  displayName: 'Ram Bahadur Thapa',
);

final _now = DateTime.now().toUtc();
String _ago(Duration d) => _now.subtract(d).toIso8601String();
String _month(int back) {
  final d = DateTime(_now.year, _now.month - back);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

final _photo = File('assets/photos/cat_plumbing.jpg').readAsBytesSync();

class FakeProviderApi implements ProviderApi {
  FakeProviderApi({this.status = 'PENDING', this.reason = ''});

  final String status;
  final String reason;

  @override
  Future<MyProviderState> state() async => MyProviderState.fromJson({
    'id': 'p1',
    'is_verified': status == 'APPROVED',
    if (status.isNotEmpty)
      'verification': {
        'status': status,
        'reason': reason,
        'submitted_at': _ago(const Duration(hours: 3)),
      },
    'availability': {
      'weekly': {
        'sun': ['08-10', '10-12', '12-14', '14-16'],
        'mon': ['08-10', '10-12', '12-14', '14-16', '16-18'],
        'tue': ['08-10', '10-12'],
        'wed': ['14-16', '16-18'],
        'thu': ['08-10', '10-12', '12-14'],
        'fri': ['08-10'],
      },
      'days_off': ['2026-11-21', '2026-12-25'],
    },
  });

  @override
  Future<List<ProviderDocument>> documents() async => [
    for (final (id, kind, label, type) in [
      ('d1', 'citizenship_front', '', 'image/jpeg'),
      ('d2', 'citizenship_back', '', 'image/jpeg'),
      ('d3', 'certificate', 'CTEVT plumbing level 1', 'image/jpeg'),
    ])
      ProviderDocument.fromJson({
        'id': id,
        'kind': kind,
        'label': label,
        'type': type,
        'created_at': _ago(const Duration(days: 1)),
      }),
  ];

  @override
  Future<Uint8List> document(String id) async => _photo;

  @override
  Future<Earnings> earnings() async => Earnings.fromJson({
    'available_paisa': 1845000,
    'on_hold_paisa': 120000,
    'withdrawing_paisa': 500000,
    'total_earned_paisa': 9632500,
    'this_month_paisa': 1210500,
    'commission_paid_paisa': 1070300,
    'jobs_paid': 48,
    'verified': status == 'APPROVED',
    'min_withdrawal_paisa': 10000,
    'months': [
      for (final (i, earned) in [
        (5, 980000),
        (4, 1420000),
        (3, 1650000),
        (2, 2240000),
        (1, 2131500),
        (0, 1210500),
      ])
        {'month': _month(i), 'earned_paisa': earned, 'jobs': 6},
    ],
    'payments': [
      for (final (cat, price) in [(1, 120000), (2, 80000), (1, 250000)])
        {
          'job_id': 'j$cat$price',
          'category_id': cat,
          'price_paisa': price,
          'earned_paisa': price * 9 ~/ 10,
          'commission_paisa': price ~/ 10,
          'at': _ago(Duration(days: cat * 3)),
        },
    ],
    'withdrawals': [
      {
        'id': 'w1',
        'user_id': 'p1',
        'amount_paisa': 500000,
        'destination': {
          'method': 'esewa',
          'wallet_id': '9841234567',
          'account_name': 'Ram Bahadur Thapa',
        },
        'status': 'PENDING',
        'created_at': _ago(const Duration(hours: 5)),
      },
      {
        'id': 'w0',
        'user_id': 'p1',
        'amount_paisa': 1200000,
        'destination': {
          'method': 'bank',
          'bank_name': 'NIC Asia Bank',
          'account_name': 'Ram Bahadur Thapa',
          'account_number': '01234567890123',
        },
        'status': 'PAID',
        'reference': 'NIC-558201',
        'created_at': _ago(const Duration(days: 12)),
      },
    ],
  });

  @override
  Future<List<GalleryPhoto>> gallery(String providerId) async => [
    GalleryPhoto.fromJson({
      'id': 'g1',
      'caption': 'Kitchen sink and mixer fitted',
    }),
    GalleryPhoto.fromJson({
      'id': 'g2',
      'caption': 'Rooftop tank cleaned and refilled',
    }),
    GalleryPhoto.fromJson({'id': 'g3', 'caption': 'Bathroom pipes replaced'}),
  ];

  @override
  Future<Uint8List> galleryPhoto(String providerId, String id) async => _photo;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

typedef ToolScene = ({
  String name,
  Widget child,
  FakeProviderApi api,
  double tall,
});

final scenes = <ToolScene>[
  (
    name: 'verify-pending',
    child: const VerificationScreen(),
    api: FakeProviderApi(),
    tall: 1500,
  ),
  (
    name: 'verify-rejected',
    child: const VerificationScreen(),
    api: FakeProviderApi(
      status: 'REJECTED',
      reason: 'The back of the card is cut off.',
    ),
    tall: 1500,
  ),
  (
    name: 'earnings',
    child: const EarningsScreen(),
    api: FakeProviderApi(status: 'APPROVED'),
    tall: 1900,
  ),
  (
    name: 'earnings-unverified',
    child: const EarningsScreen(),
    api: FakeProviderApi(status: ''),
    tall: 1100,
  ),
  (
    name: 'availability',
    child: const AvailabilityScreen(),
    api: FakeProviderApi(),
    tall: 1500,
  ),
  (
    name: 'gallery',
    child: const GalleryScreen(providerId: 'p1'),
    api: FakeProviderApi(),
    tall: 1100,
  ),
  (
    name: 'profile-tools',
    child: const Scaffold(body: ProfileTab()),
    api: FakeProviderApi(status: 'APPROVED'),
    tall: 1500,
  ),
];

Future<void> pumpTool(
  WidgetTester tester,
  ToolScene scene,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({
    'active_ui_state': UiRole.provider.name,
    'language': appLanguage.code,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        dioProvider.overrideWithValue(Dio()),
        authControllerProvider.overrideWith(() => FakeAuth(providerUser)),
        providerApiProvider.overrideWithValue(scene.api),
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
  tearDown(() => appLanguage = AppLanguage.english);

  for (final scene in scenes) {
    testWidgets('tools phone ${scene.name}', skip: skip, (tester) async {
      await pumpTool(tester, scene, Size(412, scene.tall));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/provider/phone-${scene.name}.png'),
      );
    });
    testWidgets('tools nepali ${scene.name}', skip: skip, (tester) async {
      appLanguage = AppLanguage.nepali;
      await pumpTool(tester, scene, Size(412, scene.tall));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/provider/nepali-${scene.name}.png'),
      );
    });
    testWidgets('tools desktop ${scene.name}', skip: skip, (tester) async {
      await pumpTool(tester, scene, Size(1280, scene.tall * 0.8));
    });
    testWidgets('tools small phone, large text ${scene.name}', skip: skip, (
      tester,
    ) async {
      await pumpTool(tester, scene, const Size(320, 568), textScale: 1.4);
    });
    testWidgets('tools nepali small phone ${scene.name}', skip: skip, (
      tester,
    ) async {
      appLanguage = AppLanguage.nepali;
      await pumpTool(tester, scene, const Size(320, 568), textScale: 1.4);
    });
  }

  testWidgets('withdraw sheet', skip: skip, (tester) async {
    await pumpTool(tester, scenes[2], const Size(412, 1000));
    // The scene has a waiting withdrawal, so open the sheet directly.
    final earnings = await scenes[2].api.earnings();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ProviderScope(child: WithdrawSheet(earnings: earnings)),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(tr('Withdraw earnings')), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/provider/phone-withdraw-sheet.png'),
    );
  });
}
