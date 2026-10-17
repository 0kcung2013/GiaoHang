import 'package:giaohang_mobile/core/models/delivery_eta_route_profile.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/models/order_submission_payload.dart';
import 'package:giaohang_mobile/core/providers/driver_nav_session_provider.dart';
import 'package:giaohang_mobile/core/utils/delivery_traffic_route_analyzer.dart';
import 'package:giaohang_mobile/features/driver/screens/navigation/utils/driver_navigation_motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> leg(double speed) => {
  'distance_meters': 1000,
  'forecast_at': '2024-04-03T00:05:00Z',
  'used_ai': true,
  'route_points': [
    [106.67, 10.78],
    [106.68, 10.78],
  ],
  'speed_profile': [
    for (var i = 0; i < 4; i++)
      <String, dynamic>{
        'start_meters': i * 250,
        'end_meters': (i + 1) * 250,
        'speed_kmh': speed,
      },
  ],
};
void main() {
  test(
    'mixed AI and fallback share ETA/GPS speeds with truthful map levels',
    () {
      final data = leg(50);
      final sections = data['speed_profile'] as List;
      sections[1]['speed_kmh'] = 25;
      sections[1]['used_ai'] = false;
      sections[2]['speed_kmh'] = 2;
      sections[2]['used_ai'] = true;
      final profile = DeliveryEtaRouteProfile.fromJson(data)!;
      expect(profile.speedAtDistance(0), 50);
      expect(profile.speedAtDistance(250), 25);
      expect(profile.speedAtDistance(500), 2);
      expect(profile.trafficSegments[0].level, DeliveryTrafficLevel.clear);
      expect(
        profile.trafficSegments[1].level,
        DeliveryTrafficLevel.unavailable,
      );
      expect(profile.trafficSegments[2].level, DeliveryTrafficLevel.congested);
      expect(
        profile.remainingMinutes(profile.points.first),
        closeTo(
          .25 * 60 / 50 + .25 * 60 / 25 + .25 * 60 / 2 + .25 * 60 / 50,
          1e-9,
        ),
      );
    },
  );
  test('legacy fallback and malformed per-section AI flags are handled', () {
    final fallback = DeliveryEtaRouteProfile.fromJson({
      ...leg(25),
      'used_ai': false,
    })!;
    expect(
      fallback.trafficSegments.every(
        (s) => s.level == DeliveryTrafficLevel.unavailable,
      ),
      isTrue,
    );
    final malformed = leg(50);
    (malformed['speed_profile'] as List)[0]['used_ai'] = 'yes';
    expect(DeliveryEtaRouteProfile.fromJson(malformed), isNull);
  });
  test(
    'stored AI speeds drive time, colors and movement at the same distance',
    () {
      final peak = DeliveryEtaRouteProfile.fromJson(leg(30))!;
      final off = DeliveryEtaRouteProfile.fromJson(leg(50))!;
      expect(peak.remainingMinutes(peak.points.first), closeTo(2, 1e-9));
      expect(off.remainingMinutes(off.points.first), closeTo(1.2, 1e-9));
      expect(
        peak.trafficSegments.every(
          (s) => s.level == DeliveryTrafficLevel.heavy,
        ),
        isTrue,
      );
      expect(
        off.trafficSegments.every((s) => s.level == DeliveryTrafficLevel.clear),
        isTrue,
      );
      for (final p in [peak, off]) {
        final step = DriverNavigationMotion.advanceAlongRoute(
          route: p.points,
          current: p.points.first,
          nextRouteIndex: 1,
          maxDistanceMeters: p.speedAt(p.points.first) / 3.6 * p.geometryScale,
        );
        expect(
          p.distanceAt(step.position),
          closeTo(p.speedAt(p.points.first) / 3.6, 0.01),
        );
      }
    },
  );
  test(
    'split colors stay attached to their route sections as GPS advances',
    () {
      final data = leg(30);
      (data['speed_profile'] as List)[2]['speed_kmh'] = 50;
      final p = DeliveryEtaRouteProfile.fromJson(data)!;
      final midpoint = LatLng(10.78, 106.675);
      expect(p.speedAt(midpoint), 50);
      final remaining = p.remainingSegments(midpoint);
      expect(remaining.length, 2);
      expect(remaining.first.level, DeliveryTrafficLevel.clear);
    },
  );
  test(
    'a paused session survives serialization and resume keeps its position',
    () {
      const session = DriverNavSession(
        orderId: 'order',
        status: 'delivering',
        lat: 10.78,
        lng: 106.675,
        movementRunning: false,
        simRouteIndex: 3,
      );
      final restored = DriverNavSession.fromJson(session.toJson());
      expect(restored.movementRunning, isFalse);
      expect(restored.lat, session.lat);
      expect(restored.simRouteIndex, 3);
      expect(restored.copyWith(movementRunning: true).lat, session.lat);
      expect(restored.copyWith(movementRunning: true).movementRunning, isTrue);
    },
  );
  test('legacy sessions start paused and malformed profiles are rejected', () {
    expect(
      DriverNavSession.fromJson({'orderId': 'old'}).movementRunning,
      isFalse,
    );
    final bad = leg(30);
    (bad['speed_profile'] as List)[1]['start_meters'] = 300;
    expect(DeliveryEtaRouteProfile.fromJson(bad), isNull);
    expect(DeliveryEtaRouteProfile.fromJson({'route_points': []}), isNull);
    expect(
      DeliveryEtaRouteProfile.fromJson({...leg(30), 'distance_meters': '1000'}),
      isNull,
    );
    final invalidSpeed = {
      ...leg(30),
      'speed_profile': [
        {'start_meters': 0, 'end_meters': 1000, 'speed_kmh': 'fast'},
      ],
    };
    expect(DeliveryEtaRouteProfile.fromJson(invalidSpeed), isNull);
  });
  test(
    'scenario is submitted while the server-owned forecast is never written',
    () {
      final order = OrderModel.fromJson({
        'id': 'o',
        'customer_id': 'c',
        'driver_id': 'd',
        'status': 'assigned',
        'pickup_lat': 10.78,
        'pickup_lng': 106.67,
        'delivery_lat': 10.78,
        'delivery_lng': 106.68,
        'traffic_demo_key': 'peak',
        'delivery_eta': {
          'driver_id': 'd',
          'calculation_mode': 'assignment_once_v1',
          'approach': leg(30),
          'delivery': leg(50),
        },
      });
      expect(buildOrderSubmissionPayload(order)['traffic_demo_key'], 'peak');
      expect(
        buildOrderSubmissionPayload(order).containsKey('delivery_eta'),
        isFalse,
      );
      expect(DeliveryEtaRouteProfile.forOrder(order)!.speedAtDistance(0), 30);
      expect(
        DeliveryEtaRouteProfile.forOrder(
          order.copyWith(status: 'delivering'),
        )!.speedAtDistance(0),
        50,
      );
      expect(
        DeliveryEtaRouteProfile.forOrder(order.copyWith(driverId: 'new')),
        isNull,
      );
    },
  );
}
