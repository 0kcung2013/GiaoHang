import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/providers/customer_providers.dart';
import 'package:delivery_app/core/services/osrm_service.dart';
import 'package:delivery_app/features/driver/screens/home/data/driver_order_route_distance_service.dart';
import 'package:delivery_app/features/driver/screens/home/providers/driver_order_route_distance_provider.dart';
import 'package:delivery_app/features/driver/screens/home/utils/driver_order_distance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'GH-10205 shows the sum of both OSRM legs, never straight distance',
    () async {
      final osrm = _OsrmFixture();
      final distance = await DriverOrderRouteDistanceService(
        osrm: osrm,
      ).estimate(key: _key, driverPosition: _origin);
      expect(distance.pickupMeters, 504.4);
      expect(distance.deliveryMeters, 4952.8);
      expect(distance.totalMeters, closeTo(5457.2, 0.001));
      expect(
        distance.totalMeters,
        greaterThanOrEqualTo(distance.deliveryMeters!),
      );
      expect(distanceKilometersText(distance.totalMeters), '5.5 km');
      expect(
        osrm.requests,
        contains((
          _origin.latitude,
          _origin.longitude,
          _key.pickupLat,
          _key.pickupLng,
        )),
      );
      expect(
        osrm.requests,
        contains((
          _key.pickupLat,
          _key.pickupLng,
          _key.deliveryLat,
          _key.deliveryLng,
        )),
      );
    },
  );

  test('missing GPS keeps the delivery leg without claiming a total', () async {
    final osrm = _OsrmFixture();
    final distance = await DriverOrderRouteDistanceService(
      osrm: osrm,
    ).estimate(key: _key);
    expect(distance.pickupMeters, isNull);
    expect(distance.deliveryMeters, 4952.8);
    expect(distance.totalMeters, isNull);
    expect(osrm.requests, hasLength(1));
  });

  for (final pickupFailure in [true, false]) {
    test(
      '${pickupFailure ? 'approach' : 'delivery'} OSRM failure has no straight-line fallback',
      () async {
        final osrm = _OsrmFixture(
          pickupMeters: pickupFailure ? null : 504.4,
          deliveryMeters: pickupFailure ? 4952.8 : null,
        );
        final distance = await DriverOrderRouteDistanceService(
          osrm: osrm,
        ).estimate(key: _key, driverPosition: _origin);
        expect(distance.totalMeters, isNull);
        expect(
          pickupFailure ? distance.pickupMeters : distance.deliveryMeters,
          isNull,
        );
      },
    );
  }

  test('failed routes can recover on retry', () async {
    final osrm = _OsrmFixture(deliveryMeters: null);
    final service = DriverOrderRouteDistanceService(osrm: osrm);
    expect(
      (await service.estimate(key: _key, driverPosition: _origin)).totalMeters,
      isNull,
    );
    osrm.deliveryMeters = 4952.8;
    expect(
      (await service.estimate(key: _key, driverPosition: _origin)).totalMeters,
      closeTo(5457.2, 0.001),
    );
    expect(osrm.requests, hasLength(4));
  });

  test('concurrent cards and GPS ticks reuse one quote', () async {
    final osrm = _OsrmFixture();
    final service = DriverOrderRouteDistanceService(osrm: osrm);
    final first = service.estimate(key: _key, driverPosition: _origin);
    final second = service.estimate(
      key: _key,
      driverPosition: const LatLng(11.03, 106.62),
    );
    expect(second, same(first));
    await first;
    await service.estimate(
      key: _key,
      driverPosition: const LatLng(11.0301, 106.6201),
    );
    expect(osrm.requests, hasLength(2));
  });

  test('a later GPS fixes a quote that had no approach origin', () async {
    final osrm = _OsrmFixture();
    final service = DriverOrderRouteDistanceService(osrm: osrm);
    await service.estimate(key: _key);
    final distance = await service.estimate(key: _key, driverPosition: _origin);
    expect(distance.totalMeters, closeTo(5457.2, 0.001));
    expect(osrm.requests, hasLength(2));
  });

  test(
    'new driver and quote expiry refresh approach but reuse delivery route',
    () async {
      final osrm = _OsrmFixture();
      var clock = DateTime(2026, 10, 10);
      final service = DriverOrderRouteDistanceService(
        osrm: osrm,
        now: () => clock,
      );
      await service.estimate(key: _key, driverPosition: _origin);
      final nextDriver = (
        orderId: _key.orderId,
        driverId: 'driver-2',
        offerExpiresAt: null,
        pickupLat: _key.pickupLat,
        pickupLng: _key.pickupLng,
        deliveryLat: _key.deliveryLat,
        deliveryLng: _key.deliveryLng,
      );
      await service.estimate(key: nextDriver, driverPosition: _origin);
      expect(osrm.requests, hasLength(3));
      clock = clock.add(const Duration(minutes: 3));
      await service.estimate(key: nextDriver, driverPosition: _origin);
      expect(osrm.requests, hasLength(4));
    },
  );

  test(
    'driver at pickup has a zero first leg and total equals delivery',
    () async {
      final osrm = _OsrmFixture();
      final distance = await DriverOrderRouteDistanceService(osrm: osrm)
          .estimate(
            key: _key,
            driverPosition: LatLng(_key.pickupLat, _key.pickupLng),
          );
      expect(distance.pickupMeters, 0);
      expect(distance.totalMeters, distance.deliveryMeters);
      expect(osrm.requests, hasLength(1));
    },
  );

  test(
    'existing pickup road quote is combined with an OSRM delivery leg',
    () async {
      final osrm = _OsrmFixture();
      final distance = await DriverOrderRouteDistanceService(
        osrm: osrm,
      ).estimate(key: _key, pickupRoadMeters: 700);
      expect(distance.totalMeters, closeTo(5652.8, 0.001));
      expect(osrm.requests, hasLength(1));
    },
  );

  test('invalid road distances cannot produce a misleading total', () async {
    for (final meters in [-1.0, double.nan, double.infinity]) {
      final distance = await DriverOrderRouteDistanceService(
        osrm: _OsrmFixture(pickupMeters: meters),
      ).estimate(key: _key, driverPosition: _origin);
      expect(distance.totalMeters, isNull);
    }
  });

  test(
    'model reads the fixed ETA for its driver and excludes it from writes',
    () {
      final order = _orderFromEta(_eta());
      expect(order.routeDistance?.totalMeters, closeTo(5457.2, 0.001));
      expect(order.toJson(), isNot(contains('delivery_eta')));
      expect(order.toJson(), isNot(contains('route_distance')));
      expect(
        order.copyWith(status: 'delivering').routeDistance,
        same(order.routeDistance),
      );
      expect(order.copyWith(driverId: 'driver-2').routeDistance, isNull);
      expect(order.copyWith(deliveryLat: 11.02).routeDistance, isNull);
    },
  );

  test('stale, other-driver or malformed ETA snapshots are not used', () {
    for (final eta in [
      {..._eta(), 'driver_id': 'driver-2'},
      {..._eta(), 'calculation_mode': 'phase_eta_v1'},
      {
        ..._eta(),
        'delivery': {'distance_meters': -1},
      },
      {
        ..._eta(),
        'delivery': {'distance_meters': '4952.8'},
      },
      {..._eta(), 'approach': null},
    ]) {
      expect(_orderFromEta(eta).routeDistance, isNull);
    }
  });

  test('fixed ETA distances bypass GPS and OSRM and remain stable', () async {
    final osrm = _OsrmFixture();
    final container = ProviderContainer(
      overrides: [
        driverOrderRouteDistanceServiceProvider.overrideWithValue(
          DriverOrderRouteDistanceService(osrm: osrm),
        ),
        driverByUserIdProvider.overrideWith(
          (ref, id) => throw StateError('GPS must not be queried'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final order = _orderFromEta(_eta());
    final request = driverOrderRouteRequest(order, driverPosition: _origin);
    expect(
      request,
      driverOrderRouteRequest(
        order,
        driverPosition: const LatLng(11.02, 106.64),
      ),
    );
    final subscription = container.listen(
      driverOrderRouteDistanceProvider(request),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final distance = await container.read(
      driverOrderRouteDistanceProvider(request).future,
    );
    expect(distance.totalMeters, closeTo(5457.2, 0.001));
    expect(osrm.requests, isEmpty);
  });
}

const _origin = LatLng(11.034123456789, 106.616123456789);
const DriverRouteQuoteKey _key = (
  orderId: 'GH-10205',
  driverId: 'driver-1',
  offerExpiresAt: null,
  pickupLat: 11.0313297901293,
  pickupLng: 106.618848428031,
  deliveryLat: 11.0104706299467,
  deliveryLng: 106.646787682038,
);

Map<String, dynamic> _eta() => {
  'driver_id': 'driver-1',
  'calculation_mode': 'assignment_once_v1',
  'approach': {'distance_meters': 504.4},
  'delivery': {'distance_meters': 4952.8},
};

OrderModel _orderFromEta(Map<String, dynamic> eta) => OrderModel.fromJson({
  'id': 'GH-10205',
  'driver_id': 'driver-1',
  'status': 'assigned',
  'pickup_lat': _key.pickupLat,
  'pickup_lng': _key.pickupLng,
  'delivery_lat': _key.deliveryLat,
  'delivery_lng': _key.deliveryLng,
  'delivery_eta': eta,
});

class _OsrmFixture extends OsrmService {
  _OsrmFixture({this.pickupMeters = 504.4, this.deliveryMeters = 4952.8});

  double? pickupMeters;
  double? deliveryMeters;
  final requests = <(double, double, double, double)>[];

  @override
  Future<OsrmRouteResult?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    requests.add((startLat, startLng, endLat, endLng));
    final meters = endLat == _key.pickupLat ? pickupMeters : deliveryMeters;
    if (meters == null) return null;
    return OsrmRouteResult(
      points: const [],
      distanceMeters: meters,
      durationSeconds: 100,
    );
  }
}
