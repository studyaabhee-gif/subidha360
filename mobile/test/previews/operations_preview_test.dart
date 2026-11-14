import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subidha360/core/l10n/tr.dart';
import 'package:subidha360/core/providers/core_providers.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/features/admin/data/admin_api.dart';
import 'package:subidha360/features/admin/data/admin_ops_api.dart';
import 'package:subidha360/features/admin/domain/admin_models.dart';
import 'package:subidha360/features/admin/presentation/operations_pages.dart';
import 'package:subidha360/features/admin/presentation/people_pages.dart';
import 'package:subidha360/features/auth/domain/user.dart';
import 'package:subidha360/features/auth/providers/auth_controller.dart';
import 'package:subidha360/features/support/data/support_api.dart';
import 'package:subidha360/features/support/presentation/support_screens.dart';
import 'package:subidha360/features/legal/legal_pages.dart';
import 'package:subidha360/features/auth/presentation/phone_screen.dart';

import '../support/memory_token_storage.dart';
import 'admin_preview_test.dart' show FakeAdminApi, adminUser, personJson;
import 'screens_preview_test.dart' show FakeAuth, loadFonts;

/// Help, safety and catalogue screens, fed with JSON shaped like the Go API's.
/// Run with: $env:PREVIEW='1'; flutter test test/previews --update-goldens
final _now = DateTime.now().toUtc();
String _ago(Duration d) => _now.subtract(d).toIso8601String();

Map<String, dynamic> _person(String id, String name) => {
  'id': id,
  'name': name,
  'phone': '+9779841234567',
};

final _thread = {
  'id': 't1',
  'user_id': 'u2',
  'person': _person('u2', 'Sita Gurung'),
  'subject': 'Provider left before finishing',
  'topic': 'job',
  'job_id': 'j1',
  'status': 'OPEN',
  'unread_by_user': true,
  'unread_by_staff': false,
  'last_message_at': _ago(const Duration(minutes: 20)),
  'created_at': _ago(const Duration(hours: 2)),
};

final _messages = [
  {
    'from_staff': false,
    'body': 'The provider left after an hour and the tap still leaks. He is not answering my calls.',
    'created_at': _ago(const Duration(hours: 2)),
  },
  {
    'from_staff': true,
    'body': 'Sorry about this, Sita. Your payment is on hold. We are calling him now and will update you within the hour.',
    'created_at': _ago(const Duration(minutes: 20)),
  },
];

final _flags = [
  {
    'id': 'f1',
    'reporter': _person('system', 'Automatic check'),
    'reported': _person('u1', 'Ram Bahadur Thapa'),
    'job_id': 'j1',
    'reason': 'contact_shared',
    'details': 'Call me on 9841234567, you can pay cash',
    'status': 'OPEN',
    'created_at': _ago(const Duration(hours: 1)),
  },
  {
    'id': 'f2',
    'reporter': _person('u2', 'Sita Gurung'),
    'reported': _person('u1', 'Ram Bahadur Thapa'),
    'job_id': 'j1',
    'reason': 'asked_cash',
    'details': 'Asked me to cancel in the app and pay him directly.',
    'status': 'OPEN',
    'created_at': _ago(const Duration(minutes: 40)),
  },
  {
    'id': 'f3',
    'reporter': _person('u7', 'Bikash Rai'),
    'reported': _person('u9', 'Hari Shrestha'),
    'job_id': 'j7',
    'reason': 'no_show',
    'status': 'REVIEWED',
    'outcome': 'Called both. Provider was in hospital; no action.',
    'created_at': _ago(const Duration(days: 3)),
  },
];

class FakeSupportApi implements SupportApi {
  @override
  Future<List<SupportThread>> threads() async => [
    SupportThread.fromJson(_thread),
    SupportThread.fromJson({
      ..._thread,
      'id': 't2',
      'subject': 'Refund for a cancelled job',
      'topic': 'payment',
      'status': 'CLOSED',
      'unread_by_user': false,
      'last_message_at': _ago(const Duration(days: 4)),
    }),
  ];

  @override
  Future<SupportView> thread(String id) async => (
    thread: SupportThread.fromJson(_thread),
    messages: [for (final m in _messages) SupportMessage.fromJson(m)],
  );

  @override
  Future<Helpline> helpline() async => Helpline.fromJson({
    'helpline_phone': '01-5970000',
    'helpline_hours': '9 AM to 6 PM, Sunday to Friday',
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _service(
  String id,
  String name,
  int from,
  int to, {
  bool hidden = false,
  String ne = '',
  bool popular = false,
}) => {
  'id': id,
  'category_id': 1,
  'name': name,
  'summary': 'Stop a dripping or loose tap, mixer or shower head.',
  'symptoms': ['tap dripping', 'leaking tap'],
  'includes': ['Finding the cause', 'Testing for leaks'],
  'guide_from_paisa': from,
  'guide_to_paisa': to,
  'popular': popular,
  'name_ne': ne,
  'hidden': hidden,
};

class FakeOpsApi implements AdminOpsApi {
  @override
  Future<PageOf<AdminThread>> inbox({String status = '', int page = 1}) async =>
      PageOf.fromJson({
        'items': [
          {..._thread, 'unread_by_staff': true},
          {
            ..._thread,
            'id': 't3',
            'subject': 'How do I change my phone number?',
            'topic': 'account',
            'person': _person('u5', 'Bikash Rai'),
          },
        ],
        'page': 1,
        'has_more': false,
      }, AdminThread.fromJson);

  @override
  Future<AdminThreadView> thread(String id) async => (
    thread: AdminThread.fromJson(_thread),
    messages: [for (final m in _messages) AdminSupportMessage.fromJson(m)],
  );

  @override
  Future<PageOf<FlagRow>> flags({
    String status = '',
    String person = '',
    int page = 1,
  }) async => PageOf.fromJson({
    'items': _flags,
    'page': 1,
    'has_more': false,
  }, FlagRow.fromJson);

  @override
  Future<CatalogAdminView> catalog() async => (
    categories: [
      EditableCategory.fromJson({
        'id': 1,
        'name': 'Plumbing',
        'tagline': 'Leaks, taps, tanks and pumps',
        'services': [
          _service(
            'tap-leak',
            'Leaking tap repair',
            40000,
            120000,
            popular: true,
          ),
          _service(
            'gas-stove',
            'Gas stove repair',
            50000,
            150000,
            ne: 'ग्यास चुलो मर्मत',
          ),
          _service(
            'old-geyser',
            'Solar geyser fitting',
            300000,
            900000,
            hidden: true,
          ),
        ],
      }),
      EditableCategory.fromJson({
        'id': 2,
        'name': 'Electrical',
        'tagline': 'Wiring, lights and power faults',
        'services': [
          _service('fan-light', 'Fan and light fitting', 30000, 150000),
        ],
      }),
    ],
    helplinePhone: '01-5970000',
    helplineHours: '9 AM to 6 PM, Sunday to Friday',
    settings: const {
      'helpline_phone': '01-5970000',
      'helpline_hours': '9 AM to 6 PM, Sunday to Friday',
    },
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RiskyAdminApi extends FakeAdminApi {
  @override
  Future<UserDetail> user(String id) async => UserDetail.fromJson({
    ...personJson,
    'risk': {
      'flags_open': 2,
      'flags_total': 3,
      'disputes': 1,
      'cancellations': 2,
    },
    'flags': _flags.take(2).toList(),
  });
}

typedef OpsScene = ({String name, Widget child, User user, double tall});

const _seeker = User(
  id: 'u2',
  phoneNumber: '+9779812345678',
  hasProviderProfile: false,
  displayName: 'Sita Gurung',
);

final scenes = <OpsScene>[
  (
    name: 'terms',
    child: const LegalPage(kind: LegalKind.terms),
    user: _seeker,
    tall: 3400,
  ),
  (
    name: 'privacy',
    child: const LegalPage(kind: LegalKind.privacy),
    user: _seeker,
    tall: 3600,
  ),
  (
    name: 'refunds',
    child: const LegalPage(kind: LegalKind.refunds),
    user: _seeker,
    tall: 2200,
  ),
  (name: 'login', child: const PhoneScreen(), user: _seeker, tall: 900),
  (name: 'help', child: const HelpScreen(), user: _seeker, tall: 1100),
  (
    name: 'help-thread',
    child: const SupportThreadScreen(id: 't1'),
    user: _seeker,
    tall: 900,
  ),
  (
    name: 'admin-support',
    child: const AdminSupportPage(),
    user: adminUser,
    tall: 820,
  ),
  (
    name: 'admin-thread',
    child: const AdminThreadPage(id: 't1'),
    user: adminUser,
    tall: 1100,
  ),
  (
    name: 'admin-safety',
    child: const AdminSafetyPage(),
    user: adminUser,
    tall: 1300,
  ),
  (
    name: 'admin-services',
    child: const AdminServicesPage(),
    user: adminUser,
    tall: 1300,
  ),
  (
    name: 'admin-person-risk',
    child: const AdminPersonPage(id: 'u5'),
    user: adminUser,
    tall: 3200,
  ),
];

Future<void> pumpOps(
  WidgetTester tester,
  OpsScene scene,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  SharedPreferences.setMockInitialValues({'language': appLanguage.code});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
        dioProvider.overrideWithValue(Dio()),
        authControllerProvider.overrideWith(() => FakeAuth(scene.user)),
        adminApiProvider.overrideWithValue(_RiskyAdminApi()),
        adminOpsApiProvider.overrideWithValue(FakeOpsApi()),
        supportApiProvider.overrideWithValue(FakeSupportApi()),
        companyProvider.overrideWith(
          (_) async => const CompanyDetails(
            name: 'Subidha360 Pvt. Ltd.',
            registrationNo: '123456/080/081',
            pan: '609876543',
            address: 'Baneshwor, Kathmandu',
          ),
        ),
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
}

void main() {
  final skip = Platform.environment['PREVIEW'] != '1';
  setUpAll(() async {
    if (!skip) await loadFonts();
  });
  tearDown(() => appLanguage = AppLanguage.english);

  for (final scene in scenes) {
    testWidgets('ops phone ${scene.name}', skip: skip, (tester) async {
      await pumpOps(tester, scene, Size(412, scene.tall));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/ops/phone-${scene.name}.png'),
      );
    });
    testWidgets('ops desktop ${scene.name}', skip: skip, (tester) async {
      await pumpOps(tester, scene, Size(1280, scene.tall * 0.8));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/ops/desktop-${scene.name}.png'),
      );
    });
    testWidgets('ops small phone, large text ${scene.name}', skip: skip, (
      tester,
    ) async {
      await pumpOps(tester, scene, const Size(320, 568), textScale: 1.4);
    });
    if (scene.user != adminUser) {
      testWidgets('ops nepali ${scene.name}', skip: skip, (tester) async {
        appLanguage = AppLanguage.nepali;
        await pumpOps(tester, scene, Size(412, scene.tall));
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('out/ops/nepali-${scene.name}.png'),
        );
      });
    }
  }

  testWidgets('report sheet', skip: skip, (tester) async {
    await pumpOps(
      tester,
      scenes.firstWhere((s) => s.name == 'help'),
      const Size(412, 900),
    );
    showReportSheet(tester.element(find.byType(HelpScreen)), 'j1');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text(tr('Asked to pay outside the app')));
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/ops/phone-report-sheet.png'),
    );
  });
}
