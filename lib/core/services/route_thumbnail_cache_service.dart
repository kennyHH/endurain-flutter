import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef ThumbnailDirectoryProvider = Future<Directory> Function();

class RouteThumbnailCacheService {
  RouteThumbnailCacheService({
    ThumbnailDirectoryProvider? directoryProvider,
    DateTime Function()? nowProvider,
    Duration ttl = const Duration(days: 14),
    int maxFiles = 1200,
    Duration retentionRunInterval = const Duration(hours: 6),
  }) : _directoryProvider = directoryProvider ?? _defaultDirectoryProvider,
       _nowProvider = nowProvider ?? DateTime.now,
       _ttl = ttl,
       _maxFiles = maxFiles,
       _retentionRunInterval = retentionRunInterval;

  final ThumbnailDirectoryProvider _directoryProvider;
  final DateTime Function() _nowProvider;
  final Duration _ttl;
  final int _maxFiles;
  final Duration _retentionRunInterval;
  final Map<String, Future<Uint8List>> _inflight =
      <String, Future<Uint8List>>{};
  static const _cacheVersion = 'v1';
  DateTime? _lastRetentionRunAt;

  Future<Uint8List> getOrCreate({
    required String cacheKey,
    required int widthPx,
    required int heightPx,
    required bool isDarkMode,
    required Future<Uint8List> Function() createBytes,
  }) {
    final renderKey =
        '$_cacheVersion|$cacheKey|w$widthPx|h$heightPx|d${isDarkMode ? 1 : 0}';
    final running = _inflight[renderKey];
    if (running != null) return running;
    final future = _loadOrCreate(
      renderKey: renderKey,
      createBytes: createBytes,
    );
    _inflight[renderKey] = future;
    unawaited(future.whenComplete(() => _inflight.remove(renderKey)));
    return future;
  }

  Future<Uint8List> _loadOrCreate({
    required String renderKey,
    required Future<Uint8List> Function() createBytes,
  }) async {
    final dir = await _directoryProvider();
    final file = _fileForRenderKey(dir, renderKey);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      if (bytes.isNotEmpty) return bytes;
    }
    _runRetentionIfDue(dir, reserveSlots: 1);
    final bytes = await createBytes();
    if (bytes.isEmpty) return bytes;
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes, flush: false);
    return bytes;
  }

  File _fileForRenderKey(Directory dir, String renderKey) {
    final hash = sha1.convert(utf8.encode(renderKey)).toString();
    return File(p.join(dir.path, '$hash.png'));
  }

  static Future<Directory> _defaultDirectoryProvider() async {
    final base = await getTemporaryDirectory();
    return Directory(p.join(base.path, 'history_route_thumbnails'));
  }

  void _runRetentionIfDue(Directory dir, {int reserveSlots = 0}) {
    final now = _nowProvider();
    final lastRun = _lastRetentionRunAt;
    if (lastRun != null && now.difference(lastRun) < _retentionRunInterval) {
      return;
    }
    _lastRetentionRunAt = now;
    final files = dir.existsSync()
        ? dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.png'))
              .toList()
        : <File>[];
    if (files.isEmpty) return;

    final survivors = <File>[];
    for (final file in files) {
      final age = now.difference(file.lastModifiedSync());
      if (age > _ttl) {
        try {
          file.deleteSync();
        } catch (_) {}
      } else {
        survivors.add(file);
      }
    }

    final limit = (_maxFiles - reserveSlots).clamp(0, _maxFiles);
    if (survivors.length <= limit) return;
    survivors.sort((a, b) {
      final ta = a.lastModifiedSync().millisecondsSinceEpoch;
      final tb = b.lastModifiedSync().millisecondsSinceEpoch;
      return tb.compareTo(ta);
    });
    for (final file in survivors.skip(limit)) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }
}
