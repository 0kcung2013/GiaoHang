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
  test('does not draw a 428m shortcut between sparse GPS samples', () {
    // Minimized from the observed archive: a stationary drop-off sample followed
    // 26.13 seconds later by a sample back at pickup. Average speed is only
    // 59 km/h, so a speed-only check incorrectly draws a straight shortcut.
    const drop = LatLng(11.033088, 106.615919);
    const pickup = LatLng(11.035441, 106.619023);
    final journey = RiskJourney([
      RiskJourneyPoint(drop, start, 'driver'),
      RiskJourneyPoint(drop, start.add(const Duration(seconds: 5)), 'driver'),
      RiskJourneyPoint(
        pickup,
        start.add(const Duration(milliseconds: 31130)),
        'driver',
      ),
      RiskJourneyPoint(
        const LatLng(11.0355, 106.61904),
        start.add(const Duration(milliseconds: 36130)),
        'driver',
      ),
    ]);
    expect(journey.points, hasLength(4));
    expect(journey.segments.map((segment) => segment.length), [2, 2]);
  });
  test('a long journey stays connected when intermediate GPS is recorded', () {
    final journey = RiskJourney([
      for (var i = 0; i < 12; i++)
        RiskJourneyPoint(
          LatLng(10 + i * .0006, 106),
          start.add(Duration(seconds: i * 5)),
          'driver',
        ),
    ]);
    expect(journey.segments.single, hasLength(12));
  });
}
