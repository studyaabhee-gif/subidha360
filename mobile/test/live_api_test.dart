import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subidha360/core/network/auth_interceptor.dart';
import 'package:subidha360/core/widgets/schedule_picker.dart';
import 'package:subidha360/features/auth/data/auth_repository.dart';
import 'package:subidha360/features/catalog/domain/catalog.dart';
import 'package:subidha360/features/jobs/data/job_repository.dart';
import 'package:subidha360/features/jobs/domain/bid.dart';
import 'package:subidha360/features/jobs/domain/job.dart';
import 'package:subidha360/features/notifications/data/notification_repository.dart';
import 'package:subidha360/features/wallet/data/wallet_repository.dart';

import 'support/memory_token_storage.dart';

/// Runs the app's real data layer against a running development server. Set
/// LIVE_API_URL, and LIVE_API_LOG to the server's log so OTP codes can be read.
void main() {
  final url = Platform.environment['LIVE_API_URL'];
  final logPath = Platform.environment['LIVE_API_LOG'];
  final skip = url == null ? 'set LIVE_API_URL to run' : false;

  test('the catalogue is public and searchable', () async {
    final response = await Dio(BaseOptions(baseUrl: url!))
        .get<List<dynamic>>('/v1/catalog');
    final catalog = response.data!
        .map((row) => CatalogCategory.fromJson(row as Map<String, dynamic>))
        .toList();

    expect(catalog.length, greaterThanOrEqualTo(6));
    expect(catalog.search('tap dripping').first.id, 'tap-leak');
    expect(catalog.search('ac not cooling').first.id, 'ac-service');
    expect(catalog.popular, isNotEmpty);
  }, skip: skip);

  test('a whole job from login to review and guarantee claim', () async {
    final seeker = await _Client.login(url!, logPath!);
    final provider = await _Client.login(url, logPath);

    await seeker.auth.updateName('Sita Gurung');
    await provider.auth.updateName('Ram Shrestha');
    await provider.auth.saveProviderProfile(
      categoryIds: [1],
      lat: 27.7172,
      lng: 85.3240,
      radiusMeters: 5000,
      bio: 'Plumbing across the valley',
      yearsExperience: 8,
    );
    await seeker.wallet.devTopUp(100000);

    final tomorrow = isoDate(DateTime.now().add(const Duration(days: 1)));
    final created = await seeker.jobs.create(
      categoryId: 1,
      serviceId: 'tap-leak',
      description: 'Leaking tap',
      address: 'Baneshwor',
      lat: 27.7172,
      lng: 85.3240,
      preferredDate: tomorrow,
      preferredSlot: '10-12',
    );
    expect(created.status, JobStatus.broadcasting);
    expect(created.preferredSlot, '10-12');
    expect((await seeker.jobs.myJobs()).map((j) => j.id), contains(created.id));
    expect((await provider.jobs.feed()).map((j) => j.id), contains(created.id));

    await provider.jobs.placeBid(
      created.id,
      const BidDraft(
        amountPaisa: 50000,
        partsIncluded: true,
        note: 'Washer included',
      ),
    );
    final bids = await seeker.jobs.bids(created.id);
    final bid = bids.single;
    expect(bid.partsIncluded, isTrue);
    expect(bid.note, 'Washer included');
    expect(bid.provider!.name, 'Ram Shrestha');
    expect(bid.provider!.yearsExperience, 8);
    expect(bid.provider!.hasRating, isFalse);

    await seeker.jobs.acceptBid(created.id, bid.id);
    expect((await seeker.wallet.wallet()).balancePaisa, 50000);
    expect(
      (await provider.jobs.assigned()).map((j) => j.id),
      contains(created.id),
    );

    await seeker.jobs.sendMessage(created.id, 'Gate code is 4412');
    await provider.jobs.sendMessage(created.id, 'On my way');
    final chat = await provider.jobs.messages(created.id);
    expect(chat.map((m) => m.body), ['Gate code is 4412', 'On my way']);

    expect(
      (await provider.jobs.start(created.id)).status,
      JobStatus.inProgress,
    );
    final confirmed = await provider.jobs.confirm(created.id);
    expect(confirmed.seekerMustRespond, isTrue);
    expect(confirmed.autoReleaseAt, isNotNull);

    final done = await seeker.jobs.confirm(created.id);
    expect(done.status, JobStatus.completed);

    final payout = await provider.wallet.wallet();
    expect(payout.balancePaisa, 45000);
    expect(payout.transactions.single.transactionType, 'PAYOUT');

    final finished = await seeker.jobs.job(created.id);
    expect(finished.canClaimWarranty(DateTime.now()), isTrue);
    expect(finished.reviewed, isFalse);

    await seeker.jobs.review(
      created.id,
      rating: 5,
      tags: ['On time', 'Fair price'],
      comment: 'Fixed it quickly',
    );
    final (profile, reviews) = await seeker.jobs.provider(bid.providerId);
    expect(profile.rating, 5);
    expect(profile.reviewCount, 1);
    expect(profile.jobsCompleted, 1);
    expect(reviews.single.comment, 'Fixed it quickly');
    expect((await seeker.jobs.job(created.id)).reviewed, isTrue);

    final claimed = await seeker.jobs.claimWarranty(
      created.id,
      'Tap leaking again',
    );
    expect(claimed.warrantyClaim!.status, 'OPEN');
    expect(claimed.canClaimWarranty(DateTime.now()), isFalse);

    final inbox = await fetchInbox(seeker.dio);
    expect(inbox.map((n) => n.type), contains('completion.confirm_needed'));
    final providerInbox = await fetchInbox(provider.dio);
    expect(providerInbox.map((n) => n.type), contains('warranty.claim'));
    expect(providerInbox.map((n) => n.type), contains('review.received'));
  }, skip: skip);

  test('photos, new times, live location and favourites', () async {
    final seeker = await _Client.login(url!, logPath!);
    final provider = await _Client.login(url, logPath);
    await provider.auth.updateName('Ram Shrestha');
    await provider.auth.saveProviderProfile(
      categoryIds: [1],
      lat: 27.7172,
      lng: 85.3240,
      radiusMeters: 5000,
      bio: 'Plumbing across the valley',
      yearsExperience: 8,
    );
    await seeker.wallet.devTopUp(100000);

    final created = await seeker.jobs.create(
      categoryId: 1,
      description: 'Leaking tap',
      address: 'Baneshwor',
      lat: 27.71234,
      lng: 85.32567,
    );

    // A real JPEG, sent and read back byte for byte.
    final photo = File('assets/photos/cat_plumbing.jpg').readAsBytesSync();
    await seeker.jobs.uploadPhoto(created.id, photo);
    final withPhoto = await seeker.jobs.job(created.id);
    expect(withPhoto.photoIds, hasLength(1));
    final offered = await provider.jobs.photo(
      created.id,
      withPhoto.photoIds[0],
    );
    expect(offered, photo);

    // Providers only see a rough location until they win the job.
    expect(withPhoto.jobLocation!.lat, 27.71234);
    expect((await provider.jobs.job(created.id)).jobLocation!.lat, 27.71);

    final tomorrow = isoDate(DateTime.now().add(const Duration(days: 1)));
    final moved = await seeker.jobs.reschedule(
      created.id,
      date: tomorrow,
      slot: '10-12',
    );
    expect(moved.preferredDate, tomorrow);
    expect(moved.rescheduleCount, 1);

    await provider.jobs.placeBid(
      created.id,
      const BidDraft(amountPaisa: 50000, partsIncluded: true, note: 'Today'),
    );
    final bids = await seeker.jobs.bids(created.id);
    await seeker.jobs.acceptBid(created.id, bids.first.id);
    final assigned = await provider.jobs.job(created.id);
    expect(assigned.jobLocation!.lat, 27.71234);

    expect(await seeker.jobs.tracking(created.id), isNull);
    await provider.jobs.shareLocation(created.id, 27.7, 85.33);
    final live = await seeker.jobs.tracking(created.id);
    expect(live!.lat, 27.7);
    await provider.jobs.stopSharing(created.id);
    expect(await seeker.jobs.tracking(created.id), isNull);

    await seeker.jobs.addFavorite(assigned.providerId!);
    expect((await seeker.jobs.favorites()).single.name, 'Ram Shrestha');
    final direct = await seeker.jobs.create(
      categoryId: 1,
      description: 'Another tap',
      address: 'Baneshwor',
      lat: 27.7,
      lng: 85.3,
      preferredProviderId: assigned.providerId,
    );
    expect((await provider.jobs.job(direct.id)).id, direct.id);
    await seeker.jobs.removeFavorite(assigned.providerId!);
    expect(await seeker.jobs.favorites(), isEmpty);
  }, skip: skip);
}

class _Client {
  _Client(this.dio, this.storage)
    : auth = AuthRepository(dio),
      jobs = JobRepository(dio),
      wallet = WalletRepository(dio);

  final Dio dio;
  final MemoryTokenStorage storage;
  final AuthRepository auth;
  final JobRepository jobs;
  final WalletRepository wallet;

  static final _random = Random();

  static Future<_Client> login(String url, String logPath) async {
    final storage = MemoryTokenStorage();
    final options = BaseOptions(baseUrl: url);
    final dio = Dio(options)
      ..interceptors.add(
        AuthInterceptor(
          storage: storage,
          plainDio: Dio(options),
          onSessionExpired: () {},
        ),
      );
    final client = _Client(dio, storage);

    final digits = _random.nextInt(900000000) + 100000000;
    final phone = '+9779$digits';
    await client.auth.requestOtp(phone);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final log = await File(logPath).readAsString();
    final code = RegExp(
      'to=${RegExp.escape(phone)} message="Your Subidha360 code is (\\d{6})"',
    ).firstMatch(log)![1]!;
    final (_, tokens) = await client.auth.verifyOtp(phone, code);
    await storage.save(tokens);
    return client;
  }
}
