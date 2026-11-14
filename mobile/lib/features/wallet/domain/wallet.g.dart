// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WalletTransaction _$WalletTransactionFromJson(Map<String, dynamic> json) =>
    _WalletTransaction(
      transactionId: json['transaction_id'] as String,
      amountPaisa: (json['amount_paisa'] as num).toInt(),
      transactionType: json['transaction_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      referenceJobId: json['reference_job_id'] as String?,
    );

Map<String, dynamic> _$WalletTransactionToJson(_WalletTransaction instance) =>
    <String, dynamic>{
      'transaction_id': instance.transactionId,
      'amount_paisa': instance.amountPaisa,
      'transaction_type': instance.transactionType,
      'created_at': instance.createdAt.toIso8601String(),
      'reference_job_id': instance.referenceJobId,
    };

_Wallet _$WalletFromJson(Map<String, dynamic> json) => _Wallet(
  balancePaisa: (json['balance_paisa'] as num).toInt(),
  transactions: (json['transactions'] as List<dynamic>)
      .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$WalletToJson(_Wallet instance) => <String, dynamic>{
  'balance_paisa': instance.balancePaisa,
  'transactions': instance.transactions.map((e) => e.toJson()).toList(),
};
