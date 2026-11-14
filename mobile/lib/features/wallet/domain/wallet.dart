import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

@freezed
abstract class WalletTransaction with _$WalletTransaction {
  const factory WalletTransaction({
    required String transactionId,
    required int amountPaisa,
    required String transactionType,
    required DateTime createdAt,
    String? referenceJobId,
  }) = _WalletTransaction;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      _$WalletTransactionFromJson(json);
}

@freezed
abstract class Wallet with _$Wallet {
  const factory Wallet({
    required int balancePaisa,
    required List<WalletTransaction> transactions,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) => _$WalletFromJson(json);
}

const transactionLabels = {
  'TOP_UP': 'Money added',
  'ESCROW_HOLD': 'Payment on hold for a job',
  'ESCROW_REFUND': 'Refund',
  'PAYOUT': 'Job earnings',
  'WITHDRAWAL': 'Withdrawal requested',
  'WITHDRAWAL_RETURNED': 'Withdrawal returned',
};
