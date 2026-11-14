import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';

typedef Json = Map<String, dynamic>;

/// What a conversation is about, in the order people choose from.
const supportTopics = {
  'job': 'A job',
  'payment': 'Payments and wallet',
  'account': 'My account',
  'safety': 'Safety',
  'other': 'Something else',
};

/// Reasons someone can report the other person on a job.
const reportReasons = {
  'no_show': 'Did not turn up',
  'rude': 'Rude or threatening',
  'asked_cash': 'Asked to pay outside the app',
  'fake_profile': 'Not who they said they were',
  'unsafe': 'Made me feel unsafe',
  'other': 'Something else',
};

class SupportThread {
  const SupportThread({
    required this.id,
    required this.subject,
    required this.topic,
    required this.jobId,
    required this.status,
    required this.unreadByUser,
    required this.lastMessageAt,
  });

  factory SupportThread.fromJson(Json j) => SupportThread(
    id: j['id'] as String,
    subject: j['subject'] as String,
    topic: j['topic'] as String,
    jobId: j['job_id'] as String? ?? '',
    status: j['status'] as String,
    unreadByUser: j['unread_by_user'] == true,
    lastMessageAt: DateTime.parse(j['last_message_at'] as String),
  );

  final String id;
  final String subject;
  final String topic;
  final String jobId;
  final String status;
  final bool unreadByUser;
  final DateTime lastMessageAt;

  bool get isOpen => status == 'OPEN';
}

class SupportMessage {
  const SupportMessage({
    required this.fromStaff,
    required this.body,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Json j) => SupportMessage(
    fromStaff: j['from_staff'] == true,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final bool fromStaff;
  final String body;
  final DateTime createdAt;
}

typedef SupportView = ({SupportThread thread, List<SupportMessage> messages});

SupportView _view(Json j) => (
  thread: SupportThread.fromJson(j['thread'] as Json),
  messages: [
    for (final m in j['messages'] as List) SupportMessage.fromJson(m as Json),
  ],
);

class Helpline {
  const Helpline({required this.phone, required this.hours});

  factory Helpline.fromJson(Json j) => Helpline(
    phone: j['helpline_phone'] as String? ?? '',
    hours: j['helpline_hours'] as String? ?? '',
  );

  final String phone;
  final String hours;
}

final supportApiProvider = Provider<SupportApi>(
  (ref) => SupportApi(ref.watch(dioProvider)),
);

class SupportApi {
  const SupportApi(this._dio);

  final Dio _dio;

  Future<List<SupportThread>> threads() => apiCall(() async {
    final response = await _dio.get<List<dynamic>>('/v1/support/threads');
    return [
      for (final row in response.data!) SupportThread.fromJson(row as Json),
    ];
  });

  Future<SupportView> thread(String id) => apiCall(() async {
    final response = await _dio.get<Json>('/v1/support/threads/$id');
    return _view(response.data!);
  });

  Future<SupportView> open({
    required String topic,
    required String subject,
    required String body,
    String? jobId,
  }) => apiCall(() async {
    final response = await _dio.post<Json>(
      '/v1/support/threads',
      data: {
        'topic': topic,
        'subject': subject,
        'body': body,
        'job_id': ?jobId,
      },
    );
    return _view(response.data!);
  });

  Future<SupportView> reply(String id, String body) => apiCall(() async {
    final response = await _dio.post<Json>(
      '/v1/support/threads/$id/messages',
      data: {'body': body},
    );
    return _view(response.data!);
  });

  Future<void> report(String jobId, String reason, String details) =>
      apiCall(() async {
        await _dio.post<void>(
          '/v1/jobs/$jobId/report',
          data: {'reason': reason, 'details': details},
        );
      });

  Future<Helpline> helpline() => apiCall(() async {
    final response = await _dio.get<Json>('/v1/settings');
    return Helpline.fromJson(response.data!);
  });
}

final supportThreadsProvider = FutureProvider.autoDispose<List<SupportThread>>(
  (ref) => ref.watch(supportApiProvider).threads(),
);

final supportThreadProvider = FutureProvider.autoDispose
    .family<SupportView, String>(
      (ref, id) => ref.watch(supportApiProvider).thread(id),
    );

final helplineProvider = FutureProvider.autoDispose<Helpline>(
  (ref) => ref.watch(supportApiProvider).helpline(),
);
