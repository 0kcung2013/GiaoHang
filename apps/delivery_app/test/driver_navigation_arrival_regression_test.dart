import 'dart:io';

import 'package:delivery_app/core/location/driver_location_producer_policy.dart';
import 'package:delivery_app/core/providers/driver_nav_session_provider.dart';
import 'package:delivery_app/features/driver/screens/navigation/models/driver_arrival_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('driver arrival regression', () {
    test('a target fallback can never prove that the driver arrived', () {
      final arrival = DriverArrivalPolicy.resolveArrival(
        status: 'picking_up',
        current: const LatLng(10.0, 106.0),
        target: const LatLng(10.0, 106.0),
        source: DriverPositionSource.targetFallback,
      );

      expect(arrival, isNull);
    });

    test('a fresh simulated position inside the radius can prove arrival', () {
      final target = const LatLng(10.0, 106.0);
      final arrival = DriverArrivalPolicy.resolveArrival(
        status: 'picking_up',
        current: const LatLng(10.0001, 106.0001),
        target: target,
        source: DriverPositionSource.simulation,
      );

      expect(arrival, target);
    });

    test('simulation and restored sessions use map coordinates as-is', () {
      expect(
        DriverPositionSource.simulation.ingestCoordinateSpace,
        LocationIngestCoordinateSpace.mapCoordinates,
      );
      expect(
        DriverPositionSource.restoredSession.ingestCoordinateSpace,
        LocationIngestCoordinateSpace.mapCoordinates,
      );
      expect(
        DriverPositionSource.deviceGps.ingestCoordinateSpace,
        LocationIngestCoordinateSpace.rawGps,
      );
    });

    test('active navigation sessions survive an app rerun', () {
      final now = DateTime.utc(2026, 7, 30, 10);
      final session = DriverNavSession(
        orderId: 'order-1',
        status: 'picking_up',
        lat: 10,
        lng: 106,
        arrivedAtTarget: true,
        pickupConfirmed: true,
        updatedAt: now.subtract(const Duration(minutes: 5)),
      );

      final restored = DriverNavSession.fromJson(session.toJson());

      expect(
        restored.canRestoreFor(
          activeOrderId: 'order-1',
          activeStatus: 'picking_up',
        ),
        isTrue,
      );
      expect(restored.arrivedAtTarget, isTrue);
      expect(restored.pickupConfirmed, isTrue);
      expect(restored.updatedAt, now.subtract(const Duration(minutes: 5)));
    });

    test('navigation no longer opens the automatic arrival sheet', () {
      final source = File(
        'lib/features/driver/screens/navigation/driver_navigation_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('showArrivalBottomSheet')));
      expect(source, isNot(contains('_driverPos ??= LatLng(order.pickupLat')));
    });

    test('hydrates the saved session before starting GPS or simulation', () {
      final source = File(
        'lib/features/driver/screens/navigation/driver_navigation_screen.dart',
      ).readAsStringSync();
      final hydrateIndex = source.indexOf('await _navSessionsNotifier.ready;');
      final movementIndex = source.indexOf('await _startMovement();');

      expect(hydrateIndex, greaterThanOrEqualTo(0));
      expect(movementIndex, greaterThan(hydrateIndex));
    });

    test('republishes the restored position before movement starts', () {
      final source = File(
        'lib/features/driver/screens/navigation/driver_navigation_screen.dart',
      ).readAsStringSync();
      final restoredSyncIndex = source.indexOf(
        'source: DriverPositionSource.restoredSession',
      );
      final movementIndex = source.indexOf('await _startMovement();');

      expect(restoredSyncIndex, greaterThanOrEqualTo(0));
      expect(restoredSyncIndex, lessThan(movementIndex));
      expect(source, contains('forceSync: true'));
    });
  });
}
