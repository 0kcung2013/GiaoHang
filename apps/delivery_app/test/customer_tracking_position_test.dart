import 'dart:io';

import 'package:delivery_app/features/customer/screens/tracking/utils/tracking_driver_position.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('TrackingDriverPositionResolver', () {
    test('accepts a fresh polled position even after a large movement', () {
      final result = TrackingDriverPositionResolver.resolve(
        live: null,
        profile: const LatLng(11.02516, 106.62344),
        stable: const LatLng(11.05266, 106.63990),
      );

      expect(result, const LatLng(11.02516, 106.62344));
    });

    test('keeps the stable position only when no valid update exists', () {
      final stable = const LatLng(11.05266, 106.63990);
      final result = TrackingDriverPositionResolver.resolve(
        live: null,
        profile: null,
        stable: stable,
      );

      expect(result, stable);
    });

    test('uses the fixed TP.HCM point for a configured demo driver', () {
      final result = TrackingDriverPositionResolver.resolve(
        live: const LatLng(11.02516, 106.62344),
        profile: const LatLng(11.02516, 106.62344),
        stable: null,
        demoEmail: 'taixe@gmail.com',
      );

      expect(result, const LatLng(10.7790, 106.6765));
    });

    test('tracking map polls a fresh profile and uses the resolver', () {
      final source = File(
        'lib/features/customer/screens/tracking/widgets/tracking_map.dart',
      ).readAsStringSync();

      expect(source, contains('.getDriverForOrder(widget.order.id)'));
      expect(source, contains('TrackingDriverPositionResolver.resolve'));
      expect(source, isNot(contains('back <= 200')));
    });
  });
}
