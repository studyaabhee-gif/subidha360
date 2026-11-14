import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_profile.freezed.dart';
part 'provider_profile.g.dart';

/// What the public may see about a provider. The API never sends a phone number.
@freezed
abstract class PublicProfile with _$PublicProfile {
  const PublicProfile._();

  const factory PublicProfile({
    required String id,
    required String name,
    @Default('') String bio,
    @Default(0) int yearsExperience,
    @Default(false) bool verified,
    @Default(0) double rating,
    @Default(0) int reviewCount,
    @Default(0) int jobsCompleted,
    @Default(<int>[]) List<int> categoryIds,

    /// When they take booked jobs; null means any time. Read it with
    /// Availability.fromJson.
    Map<String, dynamic>? availability,
  }) = _PublicProfile;

  factory PublicProfile.fromJson(Map<String, dynamic> json) =>
      _$PublicProfileFromJson(json);

  bool get hasRating => reviewCount > 0;
}

@freezed
abstract class Review with _$Review {
  const factory Review({
    required int rating,
    required DateTime createdAt,
    @Default(<String>[]) List<String> tags,
    @Default('') String comment,
  }) = _Review;

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
}

const reviewTags = [
  'On time',
  'Fair price',
  'Quality work',
  'Polite',
  'Clean finish',
];
