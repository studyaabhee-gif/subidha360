import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/app_notification.dart';

part 'notification_repository.g.dart';

@riverpod
Future<List<AppNotification>> inbox(Ref ref) async {
  final dio = ref.watch(dioProvider);
  return fetchInbox(dio);
}

Future<List<AppNotification>> fetchInbox(Dio dio) => apiCall(() async {
  final response = await dio.get<List<dynamic>>('/v1/notifications');
  return response.data!
      .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
      .toList();
});
