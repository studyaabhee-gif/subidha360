import 'package:subidha360/core/storage/token_storage.dart';

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.tokens]);

  Tokens? tokens;

  @override
  Future<Tokens?> read() async => tokens;

  @override
  Future<void> save(Tokens value) async => tokens = value;

  @override
  Future<void> clear() async => tokens = null;
}
