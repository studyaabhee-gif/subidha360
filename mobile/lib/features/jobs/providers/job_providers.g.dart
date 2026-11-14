// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myJobs)
final myJobsProvider = MyJobsProvider._();

final class MyJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Job>>,
          List<Job>,
          FutureOr<List<Job>>
        >
    with $FutureModifier<List<Job>>, $FutureProvider<List<Job>> {
  MyJobsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myJobsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myJobsHash();

  @$internal
  @override
  $FutureProviderElement<List<Job>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Job>> create(Ref ref) {
    return myJobs(ref);
  }
}

String _$myJobsHash() => r'df79ec400cf985f53e52e35534d29a28bdf2c022';

@ProviderFor(jobFeed)
final jobFeedProvider = JobFeedProvider._();

final class JobFeedProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Job>>,
          List<Job>,
          FutureOr<List<Job>>
        >
    with $FutureModifier<List<Job>>, $FutureProvider<List<Job>> {
  JobFeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jobFeedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jobFeedHash();

  @$internal
  @override
  $FutureProviderElement<List<Job>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Job>> create(Ref ref) {
    return jobFeed(ref);
  }
}

String _$jobFeedHash() => r'92404b68294d96e1ad68ba9c075d6761a9d479ea';

@ProviderFor(assignedJobs)
final assignedJobsProvider = AssignedJobsProvider._();

final class AssignedJobsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Job>>,
          List<Job>,
          FutureOr<List<Job>>
        >
    with $FutureModifier<List<Job>>, $FutureProvider<List<Job>> {
  AssignedJobsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'assignedJobsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$assignedJobsHash();

  @$internal
  @override
  $FutureProviderElement<List<Job>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Job>> create(Ref ref) {
    return assignedJobs(ref);
  }
}

String _$assignedJobsHash() => r'b4de979759649156fad3b309939c11228f4617f4';

@ProviderFor(jobDetail)
final jobDetailProvider = JobDetailFamily._();

final class JobDetailProvider
    extends $FunctionalProvider<AsyncValue<Job>, Job, FutureOr<Job>>
    with $FutureModifier<Job>, $FutureProvider<Job> {
  JobDetailProvider._({
    required JobDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'jobDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$jobDetailHash();

  @override
  String toString() {
    return r'jobDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Job> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Job> create(Ref ref) {
    final argument = this.argument as String;
    return jobDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JobDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$jobDetailHash() => r'b6f2e7387b10f61eaa832ce8cf3863a93cb99633';

final class JobDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Job>, String> {
  JobDetailFamily._()
    : super(
        retry: null,
        name: r'jobDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JobDetailProvider call(String id) =>
      JobDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'jobDetailProvider';
}

@ProviderFor(jobBids)
final jobBidsProvider = JobBidsFamily._();

final class JobBidsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Bid>>,
          List<Bid>,
          FutureOr<List<Bid>>
        >
    with $FutureModifier<List<Bid>>, $FutureProvider<List<Bid>> {
  JobBidsProvider._({
    required JobBidsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'jobBidsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$jobBidsHash();

  @override
  String toString() {
    return r'jobBidsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Bid>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Bid>> create(Ref ref) {
    final argument = this.argument as String;
    return jobBids(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JobBidsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$jobBidsHash() => r'a56d9459cb7888599eed24ef14b1b36878614108';

final class JobBidsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Bid>>, String> {
  JobBidsFamily._()
    : super(
        retry: null,
        name: r'jobBidsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JobBidsProvider call(String jobId) =>
      JobBidsProvider._(argument: jobId, from: this);

  @override
  String toString() => r'jobBidsProvider';
}

@ProviderFor(jobMessages)
final jobMessagesProvider = JobMessagesFamily._();

final class JobMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatMessage>>,
          List<ChatMessage>,
          FutureOr<List<ChatMessage>>
        >
    with
        $FutureModifier<List<ChatMessage>>,
        $FutureProvider<List<ChatMessage>> {
  JobMessagesProvider._({
    required JobMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'jobMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$jobMessagesHash();

  @override
  String toString() {
    return r'jobMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ChatMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ChatMessage>> create(Ref ref) {
    final argument = this.argument as String;
    return jobMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is JobMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$jobMessagesHash() => r'e37228d44c5e4b56ecd6885fa55cb7d3f11fee9f';

final class JobMessagesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ChatMessage>>, String> {
  JobMessagesFamily._()
    : super(
        retry: null,
        name: r'jobMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JobMessagesProvider call(String jobId) =>
      JobMessagesProvider._(argument: jobId, from: this);

  @override
  String toString() => r'jobMessagesProvider';
}

@ProviderFor(jobPhoto)
final jobPhotoProvider = JobPhotoFamily._();

final class JobPhotoProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List>,
          Uint8List,
          FutureOr<Uint8List>
        >
    with $FutureModifier<Uint8List>, $FutureProvider<Uint8List> {
  JobPhotoProvider._({
    required JobPhotoFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'jobPhotoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$jobPhotoHash();

  @override
  String toString() {
    return r'jobPhotoProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List> create(Ref ref) {
    final argument = this.argument as (String, String);
    return jobPhoto(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is JobPhotoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$jobPhotoHash() => r'ce2364f198dd9b27b431a24ae0566f0ba324fa12';

final class JobPhotoFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List>, (String, String)> {
  JobPhotoFamily._()
    : super(
        retry: null,
        name: r'jobPhotoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  JobPhotoProvider call(String jobId, String photoId) =>
      JobPhotoProvider._(argument: (jobId, photoId), from: this);

  @override
  String toString() => r'jobPhotoProvider';
}

@ProviderFor(favorites)
final favoritesProvider = FavoritesProvider._();

final class FavoritesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PublicProfile>>,
          List<PublicProfile>,
          FutureOr<List<PublicProfile>>
        >
    with
        $FutureModifier<List<PublicProfile>>,
        $FutureProvider<List<PublicProfile>> {
  FavoritesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesHash();

  @$internal
  @override
  $FutureProviderElement<List<PublicProfile>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PublicProfile>> create(Ref ref) {
    return favorites(ref);
  }
}

String _$favoritesHash() => r'bd2f4e9b8f424c07a79277a4f08120c0452cf5a7';

@ProviderFor(providerDetail)
final providerDetailProvider = ProviderDetailFamily._();

final class ProviderDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<(PublicProfile, List<Review>)>,
          (PublicProfile, List<Review>),
          FutureOr<(PublicProfile, List<Review>)>
        >
    with
        $FutureModifier<(PublicProfile, List<Review>)>,
        $FutureProvider<(PublicProfile, List<Review>)> {
  ProviderDetailProvider._({
    required ProviderDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'providerDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$providerDetailHash();

  @override
  String toString() {
    return r'providerDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<(PublicProfile, List<Review>)> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<(PublicProfile, List<Review>)> create(Ref ref) {
    final argument = this.argument as String;
    return providerDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProviderDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$providerDetailHash() => r'14fb5c20ac8d1ecc3e13b0ffeba96c544379ed55';

final class ProviderDetailFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<(PublicProfile, List<Review>)>,
          String
        > {
  ProviderDetailFamily._()
    : super(
        retry: null,
        name: r'providerDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProviderDetailProvider call(String id) =>
      ProviderDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'providerDetailProvider';
}
