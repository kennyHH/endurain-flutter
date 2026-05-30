import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/core/services/auth_service.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/features/auth/auth_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('AuthSessionController', () {
    test('initializes from stored auth state', () async {
      final storage = SecureStorageService();
      await storage.setAccessToken('access-1');
      await storage.setRefreshToken('refresh-1');
      final controller = AuthSessionController(
        authService: AuthService(storage: storage),
      );

      await controller.initialize();

      expect(controller.isLoading, isFalse);
      expect(controller.isAuthenticated, isTrue);
      controller.dispose();
    });

    test('marks session authentication state explicitly', () {
      final controller = AuthSessionController(
        authService: AuthService(storage: SecureStorageService()),
      );

      controller.markAuthenticated();
      expect(controller.isAuthenticated, isTrue);
      expect(controller.isLoading, isFalse);

      controller.markUnauthenticated();
      expect(controller.isAuthenticated, isFalse);
      expect(controller.isLoading, isFalse);
      controller.dispose();
    });
  });
}
