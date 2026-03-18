import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:injectable/injectable.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

@singleton
class TileManagerService {
  static const String _storeName = 'endurain_map_store';

  Future<void> init() async {
    try {
      await FMTCObjectBoxBackend().initialise();
    } catch (e) {
      debugPrint('TileManagerService init backend failed: $e');
    }
    
    try {
      const store = FMTCStore(_storeName);
      await store.manage.create(); 
    } catch (e) {
      debugPrint('TileManagerService init store failed: $e');
    }
  }

  FMTCStore get store => const FMTCStore(_storeName);

  /// Get the tile provider for flutter_map
  TileProvider get tileProvider {
    return NetworkTileProvider();
  }

  /// Pre-download a region
  Future<void> downloadRegion({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
    required int minZoom,
    required int maxZoom,
    required String sourceUrl,
  }) async {
    final region = RectangleRegion(
      LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon)),
    );

    final downloadable = region.toDownloadable(
      minZoom: minZoom,
      maxZoom: maxZoom,
      options: TileLayer(urlTemplate: sourceUrl),
    );

    final download = const FMTCStore(_storeName).download.startForeground(
      region: downloadable,
      parallelThreads: 5,
      // maxBuffer removed in v10?
    );

    // In v10 startForeground returns a Record: ({Stream<DownloadProgress> downloadProgress, Stream<TileEvent> tileEvents})
    // We need to wait for the progress stream to complete.
    await download.downloadProgress.last;
  }
}
