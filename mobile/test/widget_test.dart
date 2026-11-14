import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subidha360/app.dart';
import 'package:subidha360/core/providers/core_providers.dart';
import 'package:subidha360/core/providers/role_provider.dart';
import 'package:subidha360/core/router/app_router.dart';
import 'package:subidha360/core/theme/app_theme.dart';
import 'package:subidha360/features/auth/presentation/phone_screen.dart';
import 'package:subidha360/features/catalog/data/catalog_repository.dart';
import 'package:subidha360/features/catalog/domain/catalog.dart';

import 'support/memory_token_storage.dart';

Future<SharedPreferences> preferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

const catalog = [
  CatalogCategory(
    id: 1,
    slug: 'plumbing',
    name: 'Plumbing',
    tagline: 'Leaks and taps',
    services: [
      CatalogService(
        id: 'tap-leak',
        name: 'Leaking tap repair',
        summary: 'Stop a dripping tap.',
        categoryId: 1,
        guideFromPaisa: 40000,
        guideToPaisa: 120000,
        symptoms: ['tap dripping', 'water not stopping'],
      ),
      CatalogService(
        id: 'pump',
        name: 'Water pump repair',
        summary: 'Fix a pump.',
        categoryId: 1,
        guideFromPaisa: 80000,
        guideToPaisa: 350000,
        symptoms: ['no water pressure'],
      ),
    ],
  ),
  CatalogCategory(
    id: 2,
    slug: 'electrical',
    name: 'Electrical',
    tagline: 'Wiring',
    services: [
      CatalogService(
        id: 'power-trip',
        name: 'Power fault finding',
        summary: 'Trace a breaker fault.',
        categoryId: 2,
        guideFromPaisa: 50000,
        guideToPaisa: 250000,
        symptoms: ['power keeps tripping'],
      ),
    ],
  ),
];

void main() {
  testWidgets('visitors land on the public site, not a login wall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = await preferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
          catalogProvider.overrideWith((_) async => catalog),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fair quotes from local experts.'), findsOneWidget);
    expect(find.text('Send code'), findsNothing);
  });

  testWidgets('bad phone numbers are refused', (tester) async {
    final prefs = await preferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(theme: AppTheme.light(), home: const PhoneScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(
      find.text('Enter a 10-digit number starting with 9'),
      findsOneWidget,
    );
  });

  test('the active role survives a restart', () async {
    final prefs = await preferences();
    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(first.dispose);
    expect(first.read(activeRoleProvider), UiRole.seeker);
    await first.read(activeRoleProvider.notifier).set(UiRole.provider);

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);

    expect(second.read(activeRoleProvider), UiRole.provider);
  });

  group('problem search', () {
    List<String> ids(String query) =>
        catalog.search(query).map((service) => service.id).toList();

    test('finds services from the problem in plain words', () {
      expect(ids('tap dripping').first, 'tap-leak');
      expect(ids('power keeps tripping').first, 'power-trip');
      expect(ids('no water pressure').first, 'pump');
    });

    test('ignores case and short words', () {
      expect(ids('LEAKING TAP').first, 'tap-leak');
      expect(ids('a'), isEmpty);
      expect(ids('   '), isEmpty);
    });

    test('a name match outranks a symptom match', () {
      expect(ids('water').first, 'pump');
    });

    test('nothing matches nonsense', () {
      expect(ids('zzzzqq'), isEmpty);
    });
  });

  group('navigation rules', () {
    String? go(String url, {bool loaded = true, bool signedIn = false}) {
      final uri = Uri.parse(url);
      return resolveRedirect(
        path: uri.path,
        uri: uri,
        loaded: loaded,
        signedIn: signedIn,
      );
    }

    test('public pages need no account', () {
      for (final path in [
        '/',
        '/services',
        '/services/plumbing',
        '/service/tap-leak',
        '/guarantee',
        '/become-provider',
        '/login',
      ]) {
        expect(go(path), isNull, reason: path);
      }
    });

    test('a protocol-relative return address is refused', () {
      expect(go('/otp?from=//evil.example', signedIn: true), '/home');
    });

    test('public pages show immediately while the session loads', () {
      expect(go('/services', loaded: false), isNull);
    });

    test('private pages send visitors to log in and remember why', () {
      final target = go('/jobs/new?service=tap-leak&date=2026-11-09');
      final from = Uri.parse(target!).queryParameters['from'];
      expect(target, startsWith('/login'));
      expect(from, '/jobs/new?service=tap-leak&date=2026-11-09');
    });

    test('logging in returns to the booking', () {
      expect(
        go(
          '/otp?phone=x&from=%2Fjobs%2Fnew%3Fservice%3Dtap-leak',
          signedIn: true,
        ),
        '/jobs/new?service=tap-leak',
      );
    });

    test('logging in with nowhere to return goes to the account', () {
      expect(go('/login', signedIn: true), '/home');
    });

    test('a return address cannot point to another website', () {
      expect(go('/otp?from=https://evil.example', signedIn: true), '/home');
    });

    test('signed-in users skip the marketing page', () {
      expect(go('/', signedIn: true), '/home');
      expect(go('/services', signedIn: true), isNull);
    });

    test('a private page waits for the session instead of bouncing', () {
      final target = go('/home', loaded: false);
      expect(target, startsWith('/splash'));
    });
  });
}
