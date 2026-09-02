import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/free_pick/utils/free_pick_radius.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('radius changes by 500 meters and stays between 2 and 4 km', () {
    expect(increaseFreePickRadius(2000), 2500);
    expect(increaseFreePickRadius(3750), 4000);
    expect(increaseFreePickRadius(4000), 4000);
    expect(decreaseFreePickRadius(4000), 3500);
    expect(decreaseFreePickRadius(2250), 2000);
    expect(decreaseFreePickRadius(2000), 2000);
  });

  test('shows only manual orders outside 2 km and inside selected radius', () {
    final result = ordersSearchableInFreePick(
      [
        _order('automatic', 0.009),
        _order('manual-near', 0.022),
        _order('manual-far', 0.036),
        _order('too-far', 0.045),
      ],
      driverLat: 0,
      driverLng: 0,
      radiusMeters: 4000,
    );

    expect(result.map((order) => order.id), ['manual-near', 'manual-far']);
  });

  test('default 2 km radius has no manual FreePick ring', () {
    final result = ordersSearchableInFreePick(
      [_order('automatic', 0.009), _order('manual', 0.022)],
      driverLat: 0,
      driverLng: 0,
      radiusMeters: freePickDefaultRadiusMeters,
    );

    expect(result, isEmpty);
  });
}

OrderModel _order(String id, double latitude) {
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
  );
}
