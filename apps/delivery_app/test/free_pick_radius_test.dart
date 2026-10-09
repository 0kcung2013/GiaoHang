import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/free_pick/utils/free_pick_radius.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('road limit changes by 500 meters and stays between 2 and 3 km', () {
    expect(increaseFreePickRadius(2000), 2500);
    expect(increaseFreePickRadius(2500), 3000);
    expect(increaseFreePickRadius(3000), 3000);
    expect(decreaseFreePickRadius(3000), 2500);
    expect(decreaseFreePickRadius(2250), 2000);
    expect(decreaseFreePickRadius(2000), 2000);
  });

  test('shows only manual orders outside 2 km and inside selected radius', () {
    final result = ordersSearchableInFreePick(
      [
        _order('automatic', 1500),
        _order('manual-near', 2400),
        _order('manual-far', 3000),
        _order('too-far', 3000.1),
      ],
      driverLat: 0,
      driverLng: 0,
      radiusMeters: 4000,
    );

    expect(result.map((order) => order.id), ['manual-near', 'manual-far']);
  });

  test('default 2 km radius has no manual FreePick ring', () {
    final result = ordersSearchableInFreePick(
      [_order('automatic', 1500), _order('manual', 2400)],
      driverLat: 0,
      driverLng: 0,
      radiusMeters: freePickDefaultRadiusMeters,
    );

    expect(result, isEmpty);
  });

  test('nearby GPS point can belong to the manual road-distance ring', () {
    final order = _order('across-river', 3000).copyWith(pickupLat: 0.001);
    expect(
      ordersSearchableInFreePick(
        [order],
        driverLat: 0,
        driverLng: 0,
        radiusMeters: 3000,
      ),
      [order],
    );
    expect(order.toJson().containsKey('pickup_road_distance_meters'), isFalse);
  });

  test(
    'missing, stale or moved route quotes never fall back to GPS distance',
    () {
      final now = DateTime.now();
      final unquoted = OrderModel.fromJson(_order('missing', 3000).toJson());
      final stale = _order(
        'stale',
        3000,
      ).copyWith(pickupRoadQuotedAt: now.subtract(const Duration(seconds: 31)));
      final moved = _order('moved', 3000).copyWith(pickupRoadOriginLat: 0.001);
      expect(
        ordersSearchableInFreePick(
          [unquoted, stale, moved],
          driverLat: 0,
          driverLng: 0,
          radiusMeters: 4000,
          now: now,
        ),
        isEmpty,
      );
    },
  );

  test(
    'a pickup inside the GPS circle with a 2.6 km route needs the 3 km limit',
    () {
      final order = _order('road-2600', 2600).copyWith(pickupLat: 0.01);
      expect(
        ordersSearchableInFreePick(
          [order],
          driverLat: 0,
          driverLng: 0,
          radiusMeters: 2500,
        ),
        isEmpty,
      );
      expect(
        ordersSearchableInFreePick(
          [order],
          driverLat: 0,
          driverLng: 0,
          radiusMeters: 3000,
        ),
        [order],
      );
    },
  );
}

OrderModel _order(String id, double roadDistance) {
  const latitude = 0.022;
  final now = DateTime(2099);
  return OrderModel(
    id: id,
    customerId: 'customer',
    status: 'confirmed',
    pickupAddress: 'Điểm lấy $id',
    pickupLat: latitude,
    pickupLng: 0,
    deliveryAddress: 'Điểm giao $id',
    deliveryLat: latitude + 0.005,
    deliveryLng: 0.005,
    createdAt: now,
    trackingCode: 'GH-DEMO-$id',
    deliveryFee: 18000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    codCollectionAmount: 50000,
    driverNetEarning: 18000,
    driverAdvanceAmount: 50000,
    receiverCollectionAmount: 68000,
    assignmentExpiresAt: now,
    updatedAt: now,
    pickupRoadDistanceMeters: roadDistance,
    pickupRoadQuotedAt: DateTime.now(),
    pickupRoadOriginLat: 0,
    pickupRoadOriginLng: 0,
  );
}
