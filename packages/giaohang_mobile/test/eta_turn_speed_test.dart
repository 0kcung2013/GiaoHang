import 'dart:convert';
import 'dart:io';
import 'package:giaohang_mobile/core/ml/eta_simulation/features.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/model.dart';
import 'package:giaohang_mobile/core/ml/eta_simulation/profile.dart';
import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/utils/driver_navigation_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final model = EtaCorrectionModel(
    jsonDecode(File('assets/ml/eta_simulation_model.json').readAsStringSync()),
  );
  final context = <String, dynamic>{
    ...jsonDecode(
      File('assets/ml/eta_simulation_context.json').readAsStringSync(),
    ),
    'speed_roads': null,
  };
  const noon = '2026-10-07T12:00:00+07:00';
  Map<String, dynamic> route(
    List<List<double>> points, {
    double rawSpeed = 50,
  }) {
    final lengths = [
      for (var i = 1; i < points.length; i++)
        etaDistance(points[i - 1], points[i]),
    ];
    final meters = lengths.fold(0.0, (s, v) => s + v);
    return {
      'distance': meters,
      'duration': meters * 3.6 / rawSpeed,
      'geometry': {'coordinates': points},
      'legs': [
        {
          'annotation': {
            'distance': lengths,
            'duration': [for (final v in lengths) v * 3.6 / rawSpeed],
          },
        },
      ],
    };
  }

  final r = route([
    [106.65, 10.8],
    [106.653, 10.8],
    [106.653, 10.803],
  ]);
  DeliveryEtaRouteProfile forecast(Map<String, dynamic> r, String at) =>
      DeliveryEtaRouteProfile.fromJson(buildEtaProfile(r, at, model, context))!;
  test('actual 90-degree route turn brakes, slows and recovers speed', () {
    final p = forecast(r, noon),
        apex = etaDistance([106.65, 10.8], [106.653, 10.8]);
    expect(p.speedAtDistance(20), greaterThan(40));
    expect(p.speedAtDistance(apex - 35), lessThan(p.speedAtDistance(20) - 5));
    expect(p.speedAtDistance(apex), inInclusiveRange(15, 23));
    expect(
      p.speedAtDistance(apex + 25),
      greaterThan(p.speedAtDistance(apex) + 3),
    );
    expect(p.speedAtDistance(p.distanceMeters - 20), greaterThan(40));
  });
  test('straight residential road exceeds 31 and slows in peak time', () {
    final straight = route([
      [106.65, 10.8],
      [106.655, 10.8],
    ], rawSpeed: 30);
    final off = forecast(straight, noon),
        peak = forecast(straight, '2026-10-07T17:30:00+07:00');
    expect(
      off.sections.every((s) => s.speedKmh > 31 && s.speedKmh <= 41),
      isTrue,
    );
    expect(
      peak.remainingMinutes(peak.points.first),
      greaterThan(off.remainingMinutes(off.points.first)),
    );
  });
  test('driver movement spends longer near the turn and agrees with ETA', () {
    final p = forecast(r, noon);
    final apex = etaDistance([106.65, 10.8], [106.653, 10.8]);
    const tick = Duration(milliseconds: 250);
    var point = p.points.first, index = 1, ticks = 0;
    var cruiseMeters = 0.0, cruiseTicks = 0, turnMeters = 0.0, turnTicks = 0;
    while (ticks < 2000) {
      final before = p.distanceAt(point),
          meters = p.metersForDuration(point, tick);
      final step = DriverNavigationMotion.advanceAlongRoute(
        route: p.points,
        current: point,
        nextRouteIndex: index,
        maxDistanceMeters: meters * p.geometryScale,
      );
      if (before > 20 && before < 100) {
        cruiseMeters += meters;
        cruiseTicks++;
      }
      if ((before - apex).abs() < 5) {
        turnMeters += meters;
        turnTicks++;
      }
      point = step.position;
      index = step.nextRouteIndex;
      ticks++;
      if (step.reachedEnd) break;
    }
    expect(ticks, lessThan(2000));
    expect(turnTicks, greaterThan(0));
    expect(turnMeters / turnTicks, lessThan(cruiseMeters / cruiseTicks * .6));
    expect(ticks * .25, closeTo(p.remainingMinutes(p.points.first) * 60, .26));
  });
}
