import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/admin_models.dart';

final adminApiProvider = Provider<AdminApi>(
  (ref) => AdminApi(ref.watch(dioProvider)),
);

/// The back office. Every call needs an admin account; the server checks.
class AdminApi {
  const AdminApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, Object?> query = const {},
  ]) => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {
        for (final e in query.entries)
          if (e.value != null && e.value != '') e.key: e.value,
      },
    );
    return response.data!;
  });

  Future<Overview> overview() async =>
      Overview.fromJson(await _get('/v1/admin/overview'));

  Future<PageOf<UserRow>> users({
    String q = '',
    String filter = '',
    int page = 1,
  }) async => PageOf.fromJson(
    await _get('/v1/admin/users', {'q': q, 'filter': filter, 'page': page}),
    UserRow.fromJson,
  );

  Future<UserDetail> user(String id) async =>
      UserDetail.fromJson(await _get('/v1/admin/users/$id'));

  Future<void> suspend(String id, String reason) => apiCall(() async {
    await _dio.post<void>(
      '/v1/admin/users/$id/suspend',
      data: {'reason': reason},
    );
  });

  Future<void> unsuspend(String id, String note) => apiCall(() async {
    await _dio.post<void>(
      '/v1/admin/users/$id/unsuspend',
      data: {'reason': note},
    );
  });

  Future<void> setVerified(String id, bool verified, String note) =>
      apiCall(() async {
        await _dio.put<void>(
          '/v1/admin/providers/$id/verified',
          data: {'verified': verified, 'note': note},
        );
      });

  Future<PageOf<JobRow>> jobs({
    String q = '',
    String status = '',
    int page = 1,
  }) async => PageOf.fromJson(
    await _get('/v1/admin/jobs', {'q': q, 'status': status, 'page': page}),
    JobRow.fromJson,
  );

  Future<JobDetail> job(String id) async =>
      JobDetail.fromJson(await _get('/v1/admin/jobs/$id'));

  Future<void> resolveEscrow(String id, int providerPercent, String note) =>
      apiCall(() async {
        await _dio.post<void>(
          '/v1/admin/jobs/$id/resolve-escrow',
          data: {'provider_percent': providerPercent, 'note': note},
        );
      });

  Future<void> closeClaim(String id, String note) => apiCall(() async {
    await _dio.post<void>(
      '/v1/admin/jobs/$id/warranty-claim/close',
      data: {'note': note},
    );
  });

  Future<PageOf<EntryRow>> payments({
    String type = '',
    String q = '',
    int page = 1,
  }) async => PageOf.fromJson(
    await _get('/v1/admin/payments', {'type': type, 'q': q, 'page': page}),
    EntryRow.fromJson,
  );

  Future<Money> money() async => Money.fromJson(await _get('/v1/admin/money'));

  Future<Report> report(String from, String to) async => Report.fromJson(
    await _get('/v1/admin/reports', {'from': from, 'to': to}),
  );

  Future<String> reportCsv(String from, String to) => apiCall(() async {
    final response = await _dio.get<String>(
      '/v1/admin/reports.csv',
      queryParameters: {'from': from, 'to': to},
      options: Options(responseType: ResponseType.plain),
    );
    return response.data!;
  });

  Future<void> decideCheck(
    String userId, {
    required bool approve,
    String reason = '',
  }) => apiCall(() async {
    await _dio.post<void>(
      '/v1/admin/users/$userId/verification',
      data: {'approve': approve, 'reason': reason},
    );
  });

  Future<Uint8List> document(String id) => apiCall(() async {
    final response = await _dio.get<List<int>>(
      '/v1/admin/documents/$id',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  });

  Future<PageOf<WithdrawalRow>> withdrawals({
    String status = '',
    int page = 1,
  }) async => PageOf.fromJson(
    await _get('/v1/admin/withdrawals', {'status': status, 'page': page}),
    WithdrawalRow.fromJson,
  );

  /// Paid needs the transfer reference; refused needs a reason.
  Future<void> decideWithdrawal(
    String id, {
    required bool paid,
    required String note,
  }) => apiCall(() async {
    await _dio.post<void>(
      '/v1/admin/withdrawals/$id/${paid ? 'pay' : 'refuse'}',
      data: {'note': note},
    );
  });

  Future<PageOf<AdminAction>> actions({
    String target = '',
    int page = 1,
  }) async => PageOf.fromJson(
    await _get('/v1/admin/actions', {'target': target, 'page': page}),
    AdminAction.fromJson,
  );
}

typedef UserQuery = ({String q, String filter, int page});
typedef JobQuery = ({String q, String status, int page});
typedef PaymentQuery = ({String type, String q, int page});
typedef ReportRange = ({String from, String to});

final overviewProvider = FutureProvider.autoDispose<Overview>(
  (ref) => ref.watch(adminApiProvider).overview(),
);

final adminUsersProvider = FutureProvider.autoDispose
    .family<PageOf<UserRow>, UserQuery>(
      (ref, q) => ref
          .watch(adminApiProvider)
          .users(q: q.q, filter: q.filter, page: q.page),
    );

final adminUserProvider = FutureProvider.autoDispose.family<UserDetail, String>(
  (ref, id) => ref.watch(adminApiProvider).user(id),
);

final adminJobsProvider = FutureProvider.autoDispose
    .family<PageOf<JobRow>, JobQuery>(
      (ref, q) => ref
          .watch(adminApiProvider)
          .jobs(q: q.q, status: q.status, page: q.page),
    );

final adminJobProvider = FutureProvider.autoDispose.family<JobDetail, String>(
  (ref, id) => ref.watch(adminApiProvider).job(id),
);

final adminPaymentsProvider = FutureProvider.autoDispose
    .family<PageOf<EntryRow>, PaymentQuery>(
      (ref, q) => ref
          .watch(adminApiProvider)
          .payments(type: q.type, q: q.q, page: q.page),
    );

final adminMoneyProvider = FutureProvider.autoDispose<Money>(
  (ref) => ref.watch(adminApiProvider).money(),
);

final adminReportProvider = FutureProvider.autoDispose
    .family<Report, ReportRange>(
      (ref, r) => ref.watch(adminApiProvider).report(r.from, r.to),
    );

final adminActionsProvider = FutureProvider.autoDispose
    .family<PageOf<AdminAction>, int>(
      (ref, page) => ref.watch(adminApiProvider).actions(page: page),
    );

typedef WithdrawalQuery = ({String status, int page});

final adminWithdrawalsProvider = FutureProvider.autoDispose
    .family<PageOf<WithdrawalRow>, WithdrawalQuery>(
      (ref, q) => ref
          .watch(adminApiProvider)
          .withdrawals(status: q.status, page: q.page),
    );

final adminDocumentProvider = FutureProvider.autoDispose
    .family<Uint8List, String>(
      (ref, id) => ref.watch(adminApiProvider).document(id),
    );

/// Page views over a period, counted without tracking anyone.
class Traffic {
  const Traffic({
    required this.total,
    required this.days,
    required this.pages,
    required this.funnel,
  });

  factory Traffic.fromJson(Map<String, dynamic> j) {
    List<(String, int)> pairs(Object? rows, String key) => [
      for (final r in (rows as List?) ?? const [])
        (
          (r as Map<String, dynamic>)[key] as String,
          (r['views'] as num).toInt(),
        ),
    ];
    return Traffic(
      total: (j['total_views'] as num?)?.toInt() ?? 0,
      days: pairs(j['days'], 'date'),
      pages: pairs(j['top_pages'], 'route'),
      funnel: pairs(j['funnel'], 'route'),
    );
  }

  final int total;
  final List<(String, int)> days;
  final List<(String, int)> pages;
  final List<(String, int)> funnel;
}

final adminTrafficProvider = FutureProvider.autoDispose
    .family<Traffic, ReportRange>((ref, r) async {
      final response = await ref
          .watch(dioProvider)
          .get<Map<String, dynamic>>(
            '/v1/admin/traffic',
            queryParameters: {
              if (r.from.isNotEmpty) 'from': r.from,
              if (r.to.isNotEmpty) 'to': r.to,
            },
          );
      return Traffic.fromJson(response.data!);
    });
