import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/gpx_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GpxExporter', () {
    test('exportiert valides GPX mit trk/trkseg/trkpt fuer mehrere Punkte', () {
      final exporter = GpxExporter();
      final activity = Activity(
        id: 'activity-42',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:05:00Z'),
        distanceMeters: 1234.5,
        trackPoints: [
          TrackPoint(
            latitude: 38.7223,
            longitude: -9.1393,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
            altitudeMeters: 123.45,
          ),
          TrackPoint(
            latitude: 38.7233,
            longitude: -9.1383,
            timestamp: DateTime.parse('2026-03-09T10:01:00Z'),
            altitudeMeters: 126.10,
          ),
        ],
      );

      final gpx = exporter.export(activity);

      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx'));
      expect(gpx, contains('<trk>'));
      expect(gpx, contains('<trkseg>'));
      expect(RegExp(r'<trkpt ').allMatches(gpx).length, equals(3));
      expect(gpx, contains('<name>Run '));
      expect(gpx, contains('lat="38.7223"'));
      expect(gpx, contains('lon="-9.1393"'));
      expect(gpx, contains('<ele>123.45</ele>'));
      expect(gpx, contains('<time>2026-03-09T10:00:00.000Z</time>'));
      expect(gpx, contains('<time>2026-03-09T10:05:00.000Z</time>'));
    });

    test('0 Punkte wird defensiv als leeres trkseg exportiert', () {
      final exporter = GpxExporter();
      final activity = Activity(
        id: 'empty',
        activityType: ActivityType.walk,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:00:01Z'),
        distanceMeters: 0,
        trackPoints: const [],
      );

      final gpx = exporter.export(activity);

      expect(gpx, contains('<trkseg>'));
      expect(gpx, contains('</trkseg>'));
      expect(RegExp(r'<trkpt ').allMatches(gpx).length, equals(0));
    });

    test('1 Punkt wird sauber als einzelner trkpt exportiert', () {
      final exporter = GpxExporter();
      final activity = Activity(
        id: 'single',
        activityType: ActivityType.ride,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:00:10Z'),
        distanceMeters: 0,
        trackPoints: [
          TrackPoint(
            latitude: 38.7,
            longitude: -9.1,
            timestamp: DateTime.parse('2026-03-09T10:00:03Z'),
          ),
        ],
      );

      final gpx = exporter.export(activity);

      expect(RegExp(r'<trkpt ').allMatches(gpx).length, equals(3));
      expect(gpx, contains('<name>Ride '));
      expect(gpx, contains('<time>2026-03-09T10:00:00.000Z</time>'));
      expect(gpx, contains('<time>2026-03-09T10:00:03.000Z</time>'));
      expect(gpx, contains('<time>2026-03-09T10:00:10.000Z</time>'));
    });

    test('exportiert Herzfrequenz und Cadence als GPX-Extensions', () {
      final exporter = GpxExporter();
      final activity = Activity(
        id: 'sensor-export',
        activityType: ActivityType.ride,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:05:00Z'),
        distanceMeters: 2200,
        trackPoints: [
          TrackPoint(
            latitude: 38.7223,
            longitude: -9.1393,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
            heartRate: 147,
            cadence: 88,
          ),
        ],
      );

      final gpx = exporter.export(activity);

      expect(
        gpx,
        contains(
          'xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1"',
        ),
      );
      expect(gpx, contains('<gpxtpx:hr>147</gpxtpx:hr>'));
      expect(gpx, contains('<gpxtpx:cad>88</gpxtpx:cad>'));
    });

    test('ungueltige Punktdaten (NaN) werfen FormatException', () {
      final exporter = GpxExporter();
      final activity = Activity(
        id: 'bad',
        activityType: ActivityType.run,
        startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
        endedAt: DateTime.parse('2026-03-09T10:00:03Z'),
        distanceMeters: 0,
        trackPoints: [
          TrackPoint(
            latitude: double.nan,
            longitude: -9.1,
            timestamp: DateTime.parse('2026-03-09T10:00:00Z'),
          ),
        ],
      );

      expect(() => exporter.export(activity), throwsFormatException);
    });

    test(
      'buildExportFilename erzeugt lesbaren Fallback ohne Activity-Name',
      () {
        final exporter = GpxExporter();
        final activity = Activity(
          id: 'upload-1',
          activityType: ActivityType.run,
          startedAt: DateTime.parse('2026-03-09T10:00:00Z'),
          endedAt: DateTime.parse('2026-03-09T10:10:00Z'),
          distanceMeters: 1000,
          trackPoints: const <TrackPoint>[],
        );

        final filename = exporter.buildExportFilename(activity);

        expect(filename, matches(RegExp(r'^2026-03-09_\d{2}-\d{2}_Run\.gpx$')));
      },
    );

    test('buildExportFilename sanitizt Sonderzeichen und begrenzt Laenge', () {
      final exporter = GpxExporter();
      final activity = Activity(
        id: 'id-äöü-123456789',
        name: 'München Süd / Feierabend-Runde !!! Mit Sehr Langem Namen',
        activityType: ActivityType.ride,
        startedAt: DateTime.parse('2026-03-09T18:45:00Z'),
        endedAt: DateTime.parse('2026-03-09T19:10:00Z'),
        distanceMeters: 12000,
        trackPoints: const <TrackPoint>[],
      );

      final filename = exporter.buildExportFilename(
        activity,
        maxBaseLength: 40,
      );

      expect(filename.endsWith('.gpx'), isTrue);
      expect(filename, matches(RegExp(r'^2026-03-09_\d{2}-\d{2}_Ride_')));
      expect(filename, contains('Muenchen'));
      expect(filename.length, lessThanOrEqualTo(44));
      expect(filename, isNot(contains(' ')));
      expect(filename, isNot(contains('/')));
      expect(filename, isNot(contains('!')));
    });
  });
}
