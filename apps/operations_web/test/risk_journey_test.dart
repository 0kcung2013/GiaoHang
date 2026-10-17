import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:operations_web/features/risk_reports/models/risk_journey.dart';

void main() {
  final start = DateTime.utc(2026, 10, 16);
  RiskJourneyPoint point(int seconds, {String driver = 'a', double lat = 10}) =>
      RiskJourneyPoint(
        LatLng(lat, 106),
        start.add(Duration(seconds: seconds)),
        driver,
      );
  test('sorts and deduplicates overlapping archive chunks', () {
    final journey = RiskJourney([point(10), point(0), point(10)]);
    expect(journey.points.length, 2);
    expect(journey.points.first.time, start);
    expect(journey.segments.single.length, 2);
  });
  test(
    'does not invent paths across missing GPS, changed drivers or jumps',
    () {
      final journey = RiskJourney([
        point(0),
        point(5),
        point(100),
        point(105, driver: 'b'),
        point(110, driver: 'b', lat: 11),
      ]);
      expect(journey.segments.map((s) => s.length), [2, 1, 1, 1]);
    },
  );
}
