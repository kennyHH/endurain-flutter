import 'dart:io';
import 'dart:typed_data';

import 'package:endurain/core/services/route_thumbnail_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteThumbnailCacheService', () {
    test('persistiert Thumbnails auf Dateiebene und lädt sie wieder', () async {
      final temp = Directory.systemTemp.createTempSync(
        'endurain-thumb-cache-',
      );
      addTearDown(() async {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final serviceA = RouteThumbnailCacheService(directoryProvider: () async => temp);
      final first = await serviceA.getOrCreate(
        cacheKey: 'activity-a',
        widthPx: 640,
        heightPx: 220,
        isDarkMode: true,
        createBytes: () async => Uint8List.fromList(<int>[1, 2, 3, 4]),
      );
      expect(first, isNotEmpty);

      final serviceB = RouteThumbnailCacheService(directoryProvider: () async => temp);
      final second = await serviceB.getOrCreate(
        cacheKey: 'activity-a',
        widthPx: 640,
        heightPx: 220,
        isDarkMode: true,
        createBytes: () async => Uint8List.fromList(<int>[9, 9, 9, 9]),
      );
      expect(second, isNotEmpty);
      expect(second.length, equals(first.length));
    });

    test('dedupliziert gleichzeitige Render-Anfragen per Inflight-Guard', () async {
      final temp = Directory.systemTemp.createTempSync(
        'endurain-thumb-inflight-',
      );
      addTearDown(() async {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });

      final service = RouteThumbnailCacheService(directoryProvider: () async => temp);

      final first = service.getOrCreate(
        cacheKey: 'inflight-a',
        widthPx: 640,
        heightPx: 220,
        isDarkMode: false,
        createBytes: () async => Uint8List.fromList(<int>[7, 7, 7]),
      );
      final second = service.getOrCreate(
        cacheKey: 'inflight-a',
        widthPx: 640,
        heightPx: 220,
        isDarkMode: false,
        createBytes: () async => Uint8List.fromList(<int>[8, 8, 8]),
      );

      expect(identical(first, second), isTrue);
      final values = await Future.wait([first, second]);
      expect(values.first, isNotEmpty);
      expect(values.last.length, equals(values.first.length));
    });

    test('entfernt abgelaufene Cache-Dateien per TTL-Retention', () async {
      final temp = Directory.systemTemp.createTempSync('endurain-thumb-ttl-');
      addTearDown(() async {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });
      final staleFile = File('${temp.path}/stale.png')
        ..writeAsBytesSync(<int>[1, 2, 3], flush: false);
      final freshFile = File('${temp.path}/fresh.png')
        ..writeAsBytesSync(<int>[4, 5, 6], flush: false);
      final now = DateTime(2026, 3, 18, 12, 0, 0);
      staleFile.setLastModifiedSync(now.subtract(const Duration(days: 2)));
      freshFile.setLastModifiedSync(now.subtract(const Duration(hours: 1)));

      final service = RouteThumbnailCacheService(
        directoryProvider: () async => temp,
        ttl: const Duration(days: 1),
        nowProvider: () => now,
        retentionRunInterval: Duration.zero,
      );

      await service.getOrCreate(
        cacheKey: 'ttl-a',
        widthPx: 320,
        heightPx: 120,
        isDarkMode: false,
        createBytes: () async => Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(staleFile.existsSync(), isFalse);
      expect(freshFile.existsSync(), isTrue);
    });

    test('begrenzt Anzahl Cache-Dateien auf maxFiles', () async {
      final temp = Directory.systemTemp.createTempSync('endurain-thumb-max-');
      addTearDown(() async {
        if (temp.existsSync()) {
          temp.deleteSync(recursive: true);
        }
      });
      final now = DateTime(2026, 3, 18, 12, 0, 0);
      for (var i = 0; i < 6; i++) {
        final file = File('${temp.path}/old_$i.png')
          ..writeAsBytesSync(<int>[i], flush: false);
        file.setLastModifiedSync(now.subtract(Duration(minutes: i + 1)));
      }

      final service = RouteThumbnailCacheService(
        directoryProvider: () async => temp,
        maxFiles: 3,
        nowProvider: () => now,
        retentionRunInterval: Duration.zero,
      );

      await service.getOrCreate(
        cacheKey: 'max-a',
        widthPx: 320,
        heightPx: 120,
        isDarkMode: true,
        createBytes: () async => Uint8List.fromList(<int>[3, 2, 1]),
      );

      final pngFiles = temp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList();
      expect(pngFiles.length, lessThanOrEqualTo(3));
    });
  });
}
