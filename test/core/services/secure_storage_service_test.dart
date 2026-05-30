import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('SecureStorageService', () {
    test('detects tokens expiring inside the threshold', () async {
      final storage = SecureStorageService();
      await storage.setAccessTokenExpiresAt(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );

      expect(await storage.isAccessTokenExpiringSoon(), isTrue);
    });

    test('does not treat later token expiry as expiring soon', () async {
      final storage = SecureStorageService();
      await storage.setAccessTokenExpiresAt(
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      expect(await storage.isAccessTokenExpiringSoon(), isFalse);
    });

    test('clears only auth tokens', () async {
      final storage = SecureStorageService();
      await storage.setServerUrl('https://example.test');
      await storage.setAccessToken('access-1');
      await storage.setRefreshToken('refresh-1');
      await storage.setSessionId('session-1');
      await storage.setAccessTokenExpiresAt(DateTime.now().toUtc());

      await storage.clearAuthTokens();

      expect(await storage.getServerUrl(), 'https://example.test');
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getSessionId(), isNull);
      expect(await storage.getAccessTokenExpiresAt(), isNull);
    });
  });
}
