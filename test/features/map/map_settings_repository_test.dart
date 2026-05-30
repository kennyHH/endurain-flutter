import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:endurain/features/map/map_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('MapSettingsRepository', () {
    test('uses the default tile server when none is stored', () async {
      final repository = MapSettingsRepository(storage: SecureStorageService());

      expect(
        await repository.getTileServerUrl(),
        MapConstants.defaultTileServerUrl,
      );
    });

    test('saves and loads the configured tile server', () async {
      final repository = MapSettingsRepository(storage: SecureStorageService());

      await repository.saveTileServerUrl(
        'https://tiles.example.test/{z}/{x}/{y}.png',
      );

      expect(
        await repository.getTileServerUrl(),
        'https://tiles.example.test/{z}/{x}/{y}.png',
      );
    });
  });
}
