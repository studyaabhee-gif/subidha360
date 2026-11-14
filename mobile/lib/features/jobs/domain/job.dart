import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/l10n/tr.dart';

part 'job.freezed.dart';
part 'job.g.dart';

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum JobStatus {
  broadcasting('Waiting for bids'),
  escalating('Searching further'),
  manualFallback('No bids yet'),
  accepted('Provider assigned'),
  inProgress('In progress'),
  completed('Completed'),
  cancelled('Cancelled'),
  disputed('In dispute'),
  expired('Expired'),
  unknown('Updating');

  const JobStatus(this._label);

  final String _label;

  String get label => tr(_label);

  bool get isOpen => this == broadcasting || this == escalating;

  /// A provider is on the job, so their position can be shared.
  bool get tracked => this == accepted || this == inProgress;

  /// Nobody has started work, so the customer can still change the request.
  bool get changeable => isOpen || this == manualFallback || this == accepted;

  /// The job is over, so the customer may want to book the same thing again.
  bool get finished =>
      this == completed || this == cancelled || this == expired;

  /// Chat is open while the two parties are working together.
  bool get chatOpen =>
      this == accepted || this == inProgress || this == disputed;
}

@freezed
abstract class WarrantyClaim with _$WarrantyClaim {
  const factory WarrantyClaim({
    required String reason,
    required String status,
    @Default('') String closedNote,
  }) = _WarrantyClaim;

  factory WarrantyClaim.fromJson(Map<String, dynamic> json) =>
      _$WarrantyClaimFromJson(json);
}

/// A GeoJSON point. Coordinates are [longitude, latitude].
@freezed
abstract class GeoPoint with _$GeoPoint {
  const GeoPoint._();

  const factory GeoPoint({required List<double> coordinates}) = _GeoPoint;

  factory GeoPoint.fromJson(Map<String, dynamic> json) =>
      _$GeoPointFromJson(json);

  double get lng => coordinates[0];
  double get lat => coordinates[1];
}

/// Where the assigned provider is right now.
class LiveLocation {
  const LiveLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Arrival windows, keyed by the value the API stores.
const timeSlots = {
  '08-10': '8 to 10 AM',
  '10-12': '10 AM to 12 PM',
  '12-14': '12 to 2 PM',
  '14-16': '2 to 4 PM',
  '16-18': '4 to 6 PM',
};

@freezed
abstract class Job with _$Job {
  const Job._();

  const factory Job({
    required String id,
    required String seekerId,
    required int categoryId,
    @JsonKey(unknownEnumValue: JobStatus.unknown) required JobStatus status,
    required String description,
    required String address,
    required int bidCount,
    required int escrowAmountPaisa,
    required DateTime createdAt,
    String? providerId,
    String? serviceId,
    String? preferredDate,
    String? preferredSlot,
    DateTime? seekerConfirmedAt,
    DateTime? providerConfirmedAt,
    DateTime? autoReleaseAt,
    DateTime? selectionDeadline,
    DateTime? completedAt,
    DateTime? warrantyEndsAt,
    WarrantyClaim? warrantyClaim,
    GeoPoint? jobLocation,
    @Default(<String>[]) List<String> photoIds,
    @Default(0) int rescheduleCount,
    @Default(false) bool reviewed,
    @Default(false) bool escrowReviewRequired,
  }) = _Job;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  bool isSeeker(String userId) => seekerId == userId;
  bool isAssignedProvider(String userId) => providerId == userId;

  /// The API's limit on moving a job.
  static const maxReschedules = 3;

  bool get canChange => status.changeable;
  bool get canReschedule => canChange && rescheduleCount < maxReschedules;

  /// The seeker must act before this or the payment releases automatically.
  bool get seekerMustRespond =>
      status == JobStatus.inProgress &&
      providerConfirmedAt != null &&
      seekerConfirmedAt == null;

  bool get anyoneConfirmed =>
      seekerConfirmedAt != null || providerConfirmedAt != null;

  bool canClaimWarranty(DateTime now) =>
      status == JobStatus.completed &&
      warrantyClaim == null &&
      warrantyEndsAt != null &&
      now.isBefore(warrantyEndsAt!);
}
