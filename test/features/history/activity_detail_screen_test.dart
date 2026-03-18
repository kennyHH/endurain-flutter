import 'package:endurain/core/models/activity.dart';
import 'package:endurain/features/history/activity_detail_screen.dart';
import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('pt')],
    home: child,
  );
}

Activity _activityWithoutHeartRateCadence() {
  final start = DateTime.parse('2026-03-09T10:00:00Z');
  return Activity(
    id: 'no-hr-cad',
    activityType: ActivityType.run,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 10)),
    distanceMeters: 1800,
    trackPoints: [
      TrackPoint(latitude: 38.72, longitude: -9.13, timestamp: start),
      TrackPoint(
        latitude: 38.721,
        longitude: -9.131,
        timestamp: start.add(const Duration(minutes: 1)),
      ),
    ],
  );
}

Activity _activityWithHeartRateCadence() {
  final start = DateTime.parse('2026-03-09T11:00:00Z');
  return Activity(
    id: 'with-hr-cad',
    activityType: ActivityType.run,
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 12)),
    distanceMeters: 2400,
    trackPoints: [
      TrackPoint(
        latitude: 38.72,
        longitude: -9.13,
        timestamp: start,
        heartRate: 151,
        cadence: 84,
      ),
      TrackPoint(
        latitude: 38.721,
        longitude: -9.131,
        timestamp: start.add(const Duration(minutes: 1)),
        heartRate: 154,
        cadence: 86,
      ),
    ],
  );
}

void main() {
  testWidgets('blendet Heart Rate Zones und Cadence ohne Daten aus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ActivityDetailScreen(activity: _activityWithoutHeartRateCadence())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heart Rate Zones'), findsNothing);
    expect(find.text('Cadence'), findsNothing);
  });

  testWidgets('zeigt Heart Rate Zones und Cadence bei vorhandenen Daten', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ActivityDetailScreen(activity: _activityWithHeartRateCadence())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heart Rate Zones'), findsWidgets);
    expect(find.text('Cadence'), findsOneWidget);
  });
}
