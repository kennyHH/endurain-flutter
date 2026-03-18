import 'dart:convert';
import 'dart:math';

import 'package:endurain/core/services/secure_storage_service.dart';

class EncryptionService {
  EncryptionService({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;
  static const String _dbKeyKey = 'db_encryption_key';

  /// Retrieves the existing database encryption key or generates a new one.
  /// Returns the key as a Base64 encoded string (or appropriate format for the DB).
  Future<String> getDatabaseEncryptionKey() async {
    // 1. Try to read existing key
    String? key = await _storage.read(key: _dbKeyKey);

    // 2. If key exists, return it
    if (key != null && key.isNotEmpty) {
      return key;
    }

    // 3. If not, generate a new secure key
    key = _generateSecureKey();

    // 4. Save it to secure storage
    await _storage.write(key: _dbKeyKey, value: key);

    return key;
  }

  /// Generates a cryptographically secure 32-byte random key and returns it as Base64.
  String _generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
}
