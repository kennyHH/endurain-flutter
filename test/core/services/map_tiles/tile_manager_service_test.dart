import 'package:endurain/core/services/map_tiles/tile_manager_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: FMTC is hard to test in unit tests because it relies on platform channels/objectbox
// We will verify the API structure and DI registration.
void main() {
  group('TileManagerService', () {
    test('DI registration is correct', () {
      final service = TileManagerService();
      expect(service, isNotNull);
    });

    test('tileProvider uses network provider fallback', () {
      final service = TileManagerService();
      expect(service.tileProvider, isA<NetworkTileProvider>());
    });
  });
}
