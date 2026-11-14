import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/job_repository.dart';
import '../domain/bid.dart';
import '../domain/chat_message.dart';
import '../domain/job.dart';
import '../domain/provider_profile.dart';

part 'job_providers.g.dart';

@riverpod
Future<List<Job>> myJobs(Ref ref) => ref.watch(jobRepositoryProvider).myJobs();

@riverpod
Future<List<Job>> jobFeed(Ref ref) => ref.watch(jobRepositoryProvider).feed();

@riverpod
Future<List<Job>> assignedJobs(Ref ref) =>
    ref.watch(jobRepositoryProvider).assigned();

@riverpod
Future<Job> jobDetail(Ref ref, String id) =>
    ref.watch(jobRepositoryProvider).job(id);

@riverpod
Future<List<Bid>> jobBids(Ref ref, String jobId) =>
    ref.watch(jobRepositoryProvider).bids(jobId);

@riverpod
Future<List<ChatMessage>> jobMessages(Ref ref, String jobId) =>
    ref.watch(jobRepositoryProvider).messages(jobId);

@riverpod
Future<Uint8List> jobPhoto(Ref ref, String jobId, String photoId) =>
    ref.watch(jobRepositoryProvider).photo(jobId, photoId);

@riverpod
Future<List<PublicProfile>> favorites(Ref ref) =>
    ref.watch(jobRepositoryProvider).favorites();

@riverpod
Future<(PublicProfile, List<Review>)> providerDetail(Ref ref, String id) =>
    ref.watch(jobRepositoryProvider).provider(id);
