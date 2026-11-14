import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../config/app_config.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/admin/presentation/jobs_pages.dart';
import '../../features/admin/presentation/money_pages.dart';
import '../../features/admin/presentation/operations_pages.dart';
import '../../features/admin/presentation/overview_page.dart';
import '../../features/admin/presentation/people_pages.dart';
import '../../features/admin/presentation/withdrawals_page.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/provider_setup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/catalog/presentation/landing_page.dart';
import '../../features/catalog/presentation/service_detail_page.dart';
import '../../features/catalog/presentation/services_page.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/info/presentation/info_pages.dart';
import '../../features/jobs/presentation/chat_screen.dart';
import '../../features/jobs/presentation/create_job_screen.dart';
import '../../features/jobs/presentation/favorites_screen.dart';
import '../../features/jobs/presentation/job_detail_screen.dart';
import '../../features/legal/legal_pages.dart';
import '../../features/provider/presentation/availability_screen.dart';
import '../../features/provider/presentation/earnings_screen.dart';
import '../../features/provider/presentation/gallery_screen.dart';
import '../../features/provider/presentation/verification_screen.dart';
import '../../features/support/presentation/support_screens.dart';

part 'app_router.g.dart';

/// Decides where a navigation should really go. Public pages need no account,
/// and anyone sent to log in returns to what they were doing.
String? resolveRedirect({
  required String path,
  required Uri uri,
  required bool loaded,
  required bool signedIn,
}) {
  final isPrivate =
      path == '/home' ||
      path == '/provider-setup' ||
      path.startsWith('/jobs') ||
      path.startsWith('/admin') ||
      path.startsWith('/provider/') ||
      path == '/help' ||
      path.startsWith('/help/');
  final isAuthPage = path == '/login' || path == '/otp';
  final from = uri.queryParameters['from'];
  // A leading // would point at another website, not a page in this app.
  final isInternal =
      from != null && from.startsWith('/') && !from.startsWith('//');
  final destination = isInternal ? from : '/home';

  if (path == '/splash') {
    if (!loaded) return null;
    if (signedIn) return destination;
    return from == null ? '/login' : _toLogin(from);
  }
  if (!loaded) {
    if (!isPrivate) return null;
    return Uri(
      path: '/splash',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  if (signedIn && (isAuthPage || path == '/')) return destination;
  if (!signedIn && isPrivate) return _toLogin(uri.toString());
  return null;
}

String _toLogin(String from) =>
    Uri(path: '/login', queryParameters: {'from': from}).toString();

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Re-runs the redirect on sign-in and sign-out without rebuilding the router.
  final authChanged = ValueNotifier(0);
  ref.onDispose(authChanged.dispose);
  ref.listen(authControllerProvider, (_, _) => authChanged.value++);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: authChanged,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return resolveRedirect(
        path: state.matchedLocation,
        uri: state.uri,
        loaded: auth.hasValue,
        signedIn: auth.value != null,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LandingPage()),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            PhoneScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) =>
            OtpScreen(phone: state.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(
        path: '/services',
        builder: (_, state) =>
            ServicesPage(query: state.uri.queryParameters['q']),
      ),
      GoRoute(
        path: '/services/:slug',
        builder: (_, state) => ServicesPage(slug: state.pathParameters['slug']),
      ),
      GoRoute(
        path: '/service/:id',
        builder: (_, state) =>
            ServiceDetailPage(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/guarantee', builder: (_, _) => const GuaranteePage()),
      GoRoute(
        path: '/terms',
        builder: (_, _) => const LegalPage(kind: LegalKind.terms),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, _) => const LegalPage(kind: LegalKind.privacy),
      ),
      GoRoute(
        path: '/refunds',
        builder: (_, _) => const LegalPage(kind: LegalKind.refunds),
      ),
      GoRoute(
        path: '/photo-credits',
        builder: (_, _) => const PhotoCreditsPage(),
      ),
      GoRoute(
        path: '/become-provider',
        builder: (_, _) => const BecomeProviderPage(),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/provider-setup',
        builder: (_, _) => const ProviderSetupScreen(),
      ),
      GoRoute(
        path: '/jobs/new',
        builder: (_, state) {
          final query = state.uri.queryParameters;
          return CreateJobScreen(
            initialCategory: int.tryParse(query['category'] ?? ''),
            serviceId: query['service'],
            date: query['date'],
            slot: query['slot'],
            repeatJobId: query['repeat'],
            providerId: query['provider'],
          );
        },
      ),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(
        path: '/jobs/:id',
        builder: (_, state) =>
            JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/jobs/:id/chat',
        builder: (_, state) => ChatScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/help',
        builder: (_, state) =>
            HelpScreen(jobId: state.uri.queryParameters['job']),
      ),
      GoRoute(
        path: '/help/:id',
        builder: (_, state) =>
            SupportThreadScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/provider/verify',
        builder: (_, _) => const VerificationScreen(),
      ),
      GoRoute(
        path: '/provider/earnings',
        builder: (_, _) => const EarningsScreen(),
      ),
      GoRoute(
        path: '/provider/availability',
        builder: (_, _) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: '/provider/gallery',
        builder: (_, _) => GalleryScreen(
          providerId: ref.read(authControllerProvider).value?.id ?? '',
        ),
      ),
      ..._adminRoutes,
    ],
  );
  _countViews(router);
  return router;
}

/// Sends the route of each page shown, such as /service/:id, so the admin
/// reports can show traffic. No IDs, cookies or personal details are sent.
/// Only release builds count, so testing never skews the numbers.
void _countViews(GoRouter router) {
  if (!kReleaseMode) return;
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
  String? last;
  router.routerDelegate.addListener(() {
    final route = router.routerDelegate.currentConfiguration.fullPath;
    if (route.isEmpty || route == last) return;
    last = route;
    dio
        .post<void>('/v1/views', data: {'route': route})
        .ignore(); // Counting must never get in the way.
  });
}

int _page(GoRouterState state) =>
    int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 1;

String _query(GoRouterState state, String key) =>
    state.uri.queryParameters[key] ?? '';

/// The back office. The pages show nothing to non-admins, and the server
/// refuses their requests anyway.
final _adminRoutes = [
  GoRoute(path: '/admin', builder: (_, _) => const AdminOverviewPage()),
  GoRoute(
    path: '/admin/people',
    builder: (_, state) => AdminPeoplePage(
      q: _query(state, 'q'),
      filter: _query(state, 'filter'),
      page: _page(state),
    ),
  ),
  GoRoute(
    path: '/admin/people/:id',
    builder: (_, state) => AdminPersonPage(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/admin/jobs',
    builder: (_, state) => AdminJobsPage(
      q: _query(state, 'q'),
      status: _query(state, 'status'),
      page: _page(state),
    ),
  ),
  GoRoute(
    path: '/admin/jobs/:id',
    builder: (_, state) => AdminJobPage(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/admin/payments',
    builder: (_, state) => AdminPaymentsPage(
      type: _query(state, 'type'),
      q: _query(state, 'q'),
      page: _page(state),
    ),
  ),
  GoRoute(
    path: '/admin/support',
    builder: (_, state) => AdminSupportPage(
      status: state.uri.queryParameters['status'] ?? 'OPEN',
      page: _page(state),
    ),
  ),
  GoRoute(
    path: '/admin/support/:id',
    builder: (_, state) => AdminThreadPage(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/admin/safety',
    builder: (_, state) => AdminSafetyPage(
      status: state.uri.queryParameters['status'] ?? 'OPEN',
      page: _page(state),
    ),
  ),
  GoRoute(
    path: '/admin/services',
    builder: (_, _) => const AdminServicesPage(),
  ),
  GoRoute(
    path: '/admin/withdrawals',
    builder: (_, state) => AdminWithdrawalsPage(
      status: state.uri.queryParameters['status'] ?? 'PENDING',
      page: _page(state),
    ),
  ),
  GoRoute(
    path: '/admin/reports',
    builder: (_, state) =>
        AdminReportsPage(from: _query(state, 'from'), to: _query(state, 'to')),
  ),
  GoRoute(
    path: '/admin/audit',
    builder: (_, state) => AdminAuditPage(page: _page(state)),
  ),
];
