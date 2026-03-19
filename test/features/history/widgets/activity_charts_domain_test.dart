import 'package:endurain/core/models/activity.dart';
import 'package:endurain/features/history/widgets/activity_charts.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('pt')],
    home: Scaffold(body: child),
  );
}

List<TrackPoint> _buildTrackPoints() {
  final start = DateTime.utc(2026, 3, 16, 10, 0, 0);
  return List<TrackPoint>.generate(12, (i) {
    return TrackPoint(
      latitude: 51.0 + (i * 0.000045),
      longitude: 13.7,
      timestamp: start.add(Duration(seconds: i * 5)),
      altitudeMeters: 170 + (i % 3).toDouble(),
    );
  });
}

List<TrackPoint> _buildLongTrackPoints() {
  final start = DateTime.utc(2026, 3, 16, 10, 0, 0);
  return List<TrackPoint>.generate(80, (i) {
    return TrackPoint(
      latitude: 51.0 + (i * 0.00009),
      longitude: 13.7,
      timestamp: start.add(Duration(seconds: i * 5)),
      altitudeMeters: 170 + (i % 5).toDouble(),
    );
  });
}

List<TrackPoint> _buildVeryShortTrackPoints() {
  final start = DateTime.utc(2026, 3, 19, 8, 53, 51);
  return <TrackPoint>[
    TrackPoint(
      latitude: 51.2836584,
      longitude: 12.7632926,
      timestamp: start,
      altitudeMeters: 172,
    ),
    TrackPoint(
      latitude: 51.2836666684,
      longitude: 12.7632255969,
      timestamp: start.add(const Duration(seconds: 10)),
      altitudeMeters: 172,
    ),
    TrackPoint(
      latitude: 51.2836886398,
      longitude: 12.7631631306,
      timestamp: start.add(const Duration(seconds: 13)),
      altitudeMeters: 172,
    ),
    TrackPoint(
      latitude: 51.2836734819,
      longitude: 12.7631024846,
      timestamp: start.add(const Duration(seconds: 17)),
      altitudeMeters: 172,
    ),
    TrackPoint(
      latitude: 51.2836734819,
      longitude: 12.7631024846,
      timestamp: start.add(const Duration(seconds: 20)),
      altitudeMeters: 172,
    ),
  ];
}

void main() {
  testWidgets(
    'pace and elevation charts use full activity distance as x-domain',
    (tester) async {
      final points = _buildTrackPoints();
      final activity = Activity(
        id: 'a1',
        activityType: ActivityType.run,
        startedAt: points.first.timestamp,
        endedAt: points.last.timestamp,
        distanceMeters: 80,
        trackPoints: points,
      );

      await tester.pumpWidget(
        _wrapWithL10n(ActivityCharts(activity: activity)),
      );
      await tester.pumpAndSettle();

      final charts = tester
          .widgetList<LineChart>(find.byType(LineChart))
          .toList();
      expect(charts.length, greaterThanOrEqualTo(2));

      final elevationChart = charts[0];
      final paceChart = charts[1];

      expect(elevationChart.data.minX, 0);
      expect(elevationChart.data.maxX, closeTo(0.08, 0.0001));
      expect(paceChart.data.minX, 0);
      expect(paceChart.data.maxX, closeTo(0.08, 0.0001));
    },
  );

  testWidgets(
    'phase B uses accepted track distance from quality metrics as x-domain',
    (tester) async {
      final points = _buildTrackPoints();
      final activity = Activity(
        id: 'a2',
        activityType: ActivityType.run,
        startedAt: points.first.timestamp,
        endedAt: points.last.timestamp,
        distanceMeters: 80,
        qualityMetrics: const <String, dynamic>{
          'accepted_track_distance_meters': 52.0,
        },
        trackPoints: points,
      );

      await tester.pumpWidget(
        _wrapWithL10n(
          ActivityCharts(
            activity: activity,
            enforcePhaseBDistanceConsistency: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final charts = tester
          .widgetList<LineChart>(find.byType(LineChart))
          .toList();
      expect(charts.length, greaterThanOrEqualTo(2));

      final elevationChart = charts[0];
      final paceChart = charts[1];

      expect(elevationChart.data.maxX, closeTo(0.052, 0.0001));
      expect(paceChart.data.maxX, closeTo(0.052, 0.0001));
    },
  );

  testWidgets(
    'pace starts earlier for short activities with adaptive window',
    (tester) async {
      final points = _buildTrackPoints();
      final activity = Activity(
        id: 'a3',
        activityType: ActivityType.run,
        startedAt: points.first.timestamp,
        endedAt: points.last.timestamp,
        distanceMeters: 80,
        trackPoints: points,
      );

      await tester.pumpWidget(
        _wrapWithL10n(ActivityCharts(activity: activity)),
      );
      await tester.pumpAndSettle();

      final charts = tester.widgetList<LineChart>(find.byType(LineChart)).toList();
      final paceChart = charts[1];
      final firstPaceX = paceChart.data.lineBarsData.first.spots.first.x;
      expect(firstPaceX, lessThanOrEqualTo(0.015));
    },
  );

  testWidgets(
    'pace keeps stable smoothing window for longer activities',
    (tester) async {
      final points = _buildLongTrackPoints();
      final activity = Activity(
        id: 'a4',
        activityType: ActivityType.run,
        startedAt: points.first.timestamp,
        endedAt: points.last.timestamp,
        distanceMeters: 790,
        trackPoints: points,
      );

      await tester.pumpWidget(
        _wrapWithL10n(ActivityCharts(activity: activity)),
      );
      await tester.pumpAndSettle();

      final charts = tester.widgetList<LineChart>(find.byType(LineChart)).toList();
      final paceChart = charts[1];
      final firstPaceX = paceChart.data.lineBarsData.first.spots.first.x;
      expect(firstPaceX, closeTo(0.05, 0.01));
    },
  );

  testWidgets(
    'pace zeigt bei sehr kurzen Aktivitäten früher als 10 Meter',
    (tester) async {
      final points = _buildVeryShortTrackPoints();
      final activity = Activity(
        id: 'a5',
        activityType: ActivityType.run,
        startedAt: points.first.timestamp,
        endedAt: points.last.timestamp,
        distanceMeters: 14.3,
        trackPoints: points,
      );

      await tester.pumpWidget(
        _wrapWithL10n(ActivityCharts(activity: activity)),
      );
      await tester.pumpAndSettle();

      final charts = tester.widgetList<LineChart>(find.byType(LineChart)).toList();
      final paceChart = charts[1];
      final firstPaceX = paceChart.data.lineBarsData.first.spots.first.x;
      expect(firstPaceX, lessThan(0.01));
    },
  );
}
