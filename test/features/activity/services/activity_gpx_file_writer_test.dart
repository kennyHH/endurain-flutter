import 'dart:io';

import 'package:endurain/features/activity/services/activity_gpx_file_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityGpxFileWriter', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'endurain_activity_test_',
      );
    });

    tearDown(() async {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    test('writes GPX to a temporary file with deterministic prefix', () async {
      final writer = ActivityGpxFileWriter(
        temporaryDirectoryProvider: () async => tempDirectory,
        uniqueSuffixProvider: () => 'abc123',
      );

      final file = await writer.writeGpx('<gpx></gpx>');

      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), '<gpx></gpx>');
      expect(
        file.uri.pathSegments.last,
        '${ActivityGpxFileWriter.filePrefix}abc123'
        '${ActivityGpxFileWriter.fileExtension}',
      );
    });

    test('deletes temporary GPX files idempotently', () async {
      final writer = ActivityGpxFileWriter(
        temporaryDirectoryProvider: () async => tempDirectory,
        uniqueSuffixProvider: () => 'delete-me',
      );
      final file = await writer.writeGpx('<gpx></gpx>');

      await writer.delete(file.path);
      await writer.delete(file.path);

      expect(file.existsSync(), isFalse);
    });

    test('generates unique suffixes by default', () async {
      final writer = ActivityGpxFileWriter(
        temporaryDirectoryProvider: () async => tempDirectory,
      );

      final first = await writer.writeGpx('<gpx>1</gpx>');
      final second = await writer.writeGpx('<gpx>2</gpx>');

      expect(first.path, isNot(second.path));
      for (final file in [first, second]) {
        final name = file.uri.pathSegments.last;
        expect(name, startsWith(ActivityGpxFileWriter.filePrefix));
        expect(name, endsWith(ActivityGpxFileWriter.fileExtension));
      }
    });
  });
}
