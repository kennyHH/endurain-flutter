import 'package:endurain/features/history/widgets/activity_charts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivityChartDistanceFormatter', () {
    test('nutzt Meter bei kurzen Distanzen unter 1 km', () {
      final unit = ActivityChartDistanceFormatter.resolveUnitForMaxDistanceKm(
        0.74,
      );
      expect(unit, DistanceAxisUnit.meters);
      expect(
        ActivityChartDistanceFormatter.formatAxisLabelKm(0.07, unit),
        '70 m',
      );
      expect(
        ActivityChartDistanceFormatter.formatTooltipDistanceKm(0.078, unit),
        '78 m',
      );
    });

    test('nutzt Kilometer bei Distanzen ab 1 km', () {
      final unit = ActivityChartDistanceFormatter.resolveUnitForMaxDistanceKm(
        1.42,
      );
      expect(unit, DistanceAxisUnit.kilometers);
      expect(
        ActivityChartDistanceFormatter.formatAxisLabelKm(1.4, unit),
        '1.4 km',
      );
      expect(
        ActivityChartDistanceFormatter.formatTooltipDistanceKm(1.42, unit),
        '1.42 km',
      );
    });
  });
}
