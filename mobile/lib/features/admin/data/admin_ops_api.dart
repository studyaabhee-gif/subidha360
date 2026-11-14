import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/admin_models.dart';

/// Support, safety and catalogue tools for admins.
final adminOpsApiProvider = Provider<AdminOpsApi>(
  (ref) => AdminOpsApi(ref.watch(dioProvider)),
);

class AdminThread {
  const AdminThread({
    required this.id,
    required this.person,
    required this.subject,
    required this.topic,
    required this.jobId,
    required this.status,
    required this.unreadByStaff,
    required this.lastMessageAt,
  });

  factory AdminThread.fromJson(Json j) => AdminThread(
    id: j['id'] as String,
    person: Person.fromJson(j['person'] as Json?),
    subject: j['subject'] as String,
    topic: j['topic'] as String,
    jobId: j['job_id'] as String? ?? '',
    status: j['status'] as String,
    unreadByStaff: j['unread_by_staff'] == true,
    lastMessageAt: DateTime.parse(j['last_message_at'] as String),
  );

  final String id;
  final Person person;
  final String subject;
  final String topic;
  final String jobId;
  final String status;
  final bool unreadByStaff;
  final DateTime lastMessageAt;
}

class AdminSupportMessage {
  const AdminSupportMessage({
    required this.fromStaff,
    required this.body,
    required this.createdAt,
  });

  factory AdminSupportMessage.fromJson(Json j) => AdminSupportMessage(
    fromStaff: j['from_staff'] == true,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final bool fromStaff;
  final String body;
  final DateTime createdAt;
}

typedef AdminThreadView = ({
  AdminThread thread,
  List<AdminSupportMessage> messages,
});

AdminThreadView _view(Json j) => (
  thread: AdminThread.fromJson(j['thread'] as Json),
  messages: [
    for (final m in j['messages'] as List)
      AdminSupportMessage.fromJson(m as Json),
  ],
);

class FlagRow {
  const FlagRow({
    required this.id,
    required this.reporter,
    required this.reported,
    required this.jobId,
    required this.reason,
    required this.details,
    required this.status,
    required this.outcome,
    required this.createdAt,
  });

  factory FlagRow.fromJson(Json j) => FlagRow(
    id: j['id'] as String,
    reporter: Person.fromJson(j['reporter'] as Json?),
    reported: Person.fromJson(j['reported'] as Json?),
    jobId: j['job_id'] as String? ?? '',
    reason: j['reason'] as String,
    details: j['details'] as String? ?? '',
    status: j['status'] as String,
    outcome: j['outcome'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final Person reporter;
  final Person reported;
  final String jobId;
  final String reason;
  final String details;
  final String status;
  final String outcome;
  final DateTime createdAt;

  bool get automatic => reporter.id == 'system';

  String get reasonLabel => switch (reason) {
    'no_show' => 'Did not turn up',
    'rude' => 'Rude or threatening',
    'asked_cash' => 'Asked to pay outside the app',
    'fake_profile' => 'Not who they said they were',
    'unsafe' => 'Made them feel unsafe',
    'contact_shared' => 'Shared a phone number in chat',
    'off_platform' => 'Talked about paying outside the app',
    _ => 'Other',
  };
}

/// A service as admins edit it, including hidden ones.
class EditableService {
  EditableService({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.summary,
    required this.symptoms,
    required this.includes,
    required this.guideFromPaisa,
    required this.guideToPaisa,
    required this.popular,
    required this.nameNe,
    required this.summaryNe,
    required this.hidden,
  });

  factory EditableService.fromJson(Json j) => EditableService(
    id: j['id'] as String,
    categoryId: (j['category_id'] as num).toInt(),
    name: j['name'] as String,
    summary: j['summary'] as String,
    symptoms: ((j['symptoms'] as List?) ?? const []).cast<String>(),
    includes: ((j['includes'] as List?) ?? const []).cast<String>(),
    guideFromPaisa: (j['guide_from_paisa'] as num).toInt(),
    guideToPaisa: (j['guide_to_paisa'] as num).toInt(),
    popular: j['popular'] == true,
    nameNe: j['name_ne'] as String? ?? '',
    summaryNe: j['summary_ne'] as String? ?? '',
    hidden: j['hidden'] == true,
  );

  final String id;
  int categoryId;
  String name;
  String summary;
  List<String> symptoms;
  List<String> includes;
  int guideFromPaisa;
  int guideToPaisa;
  bool popular;
  String nameNe;
  String summaryNe;
  bool hidden;

  Json toJson() => {
    'category_id': categoryId,
    'name': name,
    'summary': summary,
    'symptoms': symptoms,
    'includes': includes,
    'guide_from_paisa': guideFromPaisa,
    'guide_to_paisa': guideToPaisa,
    'popular': popular,
    'name_ne': nameNe,
    'summary_ne': summaryNe,
    'hidden': hidden,
  };
}

class EditableCategory {
  const EditableCategory({
    required this.id,
    required this.name,
    required this.tagline,
    required this.nameNe,
    required this.taglineNe,
    required this.services,
  });

  factory EditableCategory.fromJson(Json j) => EditableCategory(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    tagline: j['tagline'] as String,
    nameNe: j['name_ne'] as String? ?? '',
    taglineNe: j['tagline_ne'] as String? ?? '',
    services: [
      for (final s in j['services'] as List)
        EditableService.fromJson(s as Json),
    ],
  );

  final int id;
  final String name;
  final String tagline;
  final String nameNe;
  final String taglineNe;
  final List<EditableService> services;
}

typedef CatalogAdminView = ({
  List<EditableCategory> categories,
  String helplinePhone,
  String helplineHours,

  /// Every site setting, as sent back when saving.
  Map<String, String> settings,
});

CatalogAdminView _catalog(Json j) {
  final s = (j['settings'] as Json?) ?? const {};
  return (
    categories: [
      for (final c in j['categories'] as List)
        EditableCategory.fromJson(c as Json),
    ],
    helplinePhone: s['helpline_phone'] as String? ?? '',
    helplineHours: s['helpline_hours'] as String? ?? '',
    settings: {
      for (final e in s.entries)
        if (e.value is String) e.key: e.value as String,
    },
  );
}

class AdminOpsApi {
  const AdminOpsApi(this._dio);

  final Dio _dio;

  Future<Json> _get(String path, Map<String, Object?> query) =>
      apiCall(() async {
        final response = await _dio.get<Json>(
          path,
          queryParameters: {
            for (final e in query.entries)
              if (e.value != null && e.value != '') e.key: e.value,
          },
        );
        return response.data!;
      });

  Future<PageOf<AdminThread>> inbox({String status = '', int page = 1}) async =>
      PageOf.fromJson(
        await _get('/v1/admin/support', {'status': status, 'page': page}),
        AdminThread.fromJson,
      );

  Future<AdminThreadView> thread(String id) async =>
      _view(await _get('/v1/admin/support/$id', const {}));

  Future<AdminThreadView> reply(String id, String body) => apiCall(() async {
    final response = await _dio.post<Json>(
      '/v1/admin/support/$id/messages',
      data: {'body': body},
    );
    return _view(response.data!);
  });

  Future<void> close(String id) => apiCall(() async {
    await _dio.post<void>('/v1/admin/support/$id/close');
  });

  Future<PageOf<FlagRow>> flags({
    String status = '',
    String person = '',
    int page = 1,
  }) async => PageOf.fromJson(
    await _get('/v1/admin/flags', {
      'status': status,
      'person': person,
      'page': page,
    }),
    FlagRow.fromJson,
  );

  Future<void> reviewFlag(String id, String outcome) => apiCall(() async {
    await _dio.post<void>(
      '/v1/admin/flags/$id/review',
      data: {'outcome': outcome},
    );
  });

  Future<CatalogAdminView> catalog() async =>
      _catalog(await _get('/v1/admin/catalog', const {}));

  Future<CatalogAdminView> saveService(EditableService s) => apiCall(() async {
    final response = await _dio.put<Json>(
      '/v1/admin/catalog/services/${s.id}',
      data: s.toJson(),
    );
    return _catalog(response.data!);
  });

  Future<CatalogAdminView> saveCategory(
    int id, {
    required String name,
    required String tagline,
    required String nameNe,
    required String taglineNe,
  }) => apiCall(() async {
    final response = await _dio.put<Json>(
      '/v1/admin/catalog/categories/$id',
      data: {
        'name': name,
        'tagline': tagline,
        'name_ne': nameNe,
        'tagline_ne': taglineNe,
      },
    );
    return _catalog(response.data!);
  });

  /// Saves every setting at once; leave none out, or it is cleared.
  Future<CatalogAdminView> saveSettings(Map<String, String> settings) =>
      apiCall(() async {
        final response = await _dio.put<Json>(
          '/v1/admin/settings',
          data: settings,
        );
        return _catalog(response.data!);
      });
}

typedef ThreadQuery = ({String status, int page});
typedef FlagQuery = ({String status, int page});

final adminInboxProvider = FutureProvider.autoDispose
    .family<PageOf<AdminThread>, ThreadQuery>(
      (ref, q) =>
          ref.watch(adminOpsApiProvider).inbox(status: q.status, page: q.page),
    );

final adminThreadProvider = FutureProvider.autoDispose
    .family<AdminThreadView, String>(
      (ref, id) => ref.watch(adminOpsApiProvider).thread(id),
    );

final adminFlagsProvider = FutureProvider.autoDispose
    .family<PageOf<FlagRow>, FlagQuery>(
      (ref, q) =>
          ref.watch(adminOpsApiProvider).flags(status: q.status, page: q.page),
    );

final adminCatalogProvider = FutureProvider.autoDispose<CatalogAdminView>(
  (ref) => ref.watch(adminOpsApiProvider).catalog(),
);
