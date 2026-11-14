import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/wallet.dart';

part 'wallet_repository.g.dart';

@Riverpod(keepAlive: true)
WalletRepository walletRepository(Ref ref) =>
    WalletRepository(ref.watch(dioProvider));

@riverpod
Future<Wallet> wallet(Ref ref) => ref.watch(walletRepositoryProvider).wallet();

class WalletRepository {
  const WalletRepository(this._dio);

  final Dio _dio;

  Future<Wallet> wallet() => apiCall(() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/wallet');
    return Wallet.fromJson(response.data!);
  });

  /// Development only. The server rejects this outside development mode.
  Future<void> devTopUp(int amountPaisa) => apiCall(() async {
    await _dio.post<void>(
      '/v1/dev/wallet/top-up',
      data: {'amount_paisa': amountPaisa},
    );
  });
}
