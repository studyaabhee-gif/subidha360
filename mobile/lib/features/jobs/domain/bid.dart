import 'package:freezed_annotation/freezed_annotation.dart';

import 'provider_profile.dart';

part 'bid.freezed.dart';
part 'bid.g.dart';

@freezed
abstract class Bid with _$Bid {
  const factory Bid({
    required String id,
    required String jobId,
    required String providerId,
    required int amountPaisa,
    required String status,
    required DateTime createdAt,
    @Default(false) bool partsIncluded,
    @Default('') String note,
    PublicProfile? provider,
  }) = _Bid;

  factory Bid.fromJson(Map<String, dynamic> json) => _$BidFromJson(json);
}

class BidDraft {
  const BidDraft({
    required this.amountPaisa,
    required this.partsIncluded,
    required this.note,
  });

  final int amountPaisa;
  final bool partsIncluded;
  final String note;
}
