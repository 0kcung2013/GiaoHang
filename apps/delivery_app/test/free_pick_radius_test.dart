import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/free_pick/utils/free_pick_radius.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps searchable FreePick orders on both sides of 2 km', () {
    final result = ordersSearchableInFreePick([
      _order('near', 11.04),
      _order('far', 11.06),
    ]);

    expect(result.map((order) => order.id), ['near', 'far']);
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
    pickupLng: 106.6220,
    deliveryAddress: 'Điểm giao $id',
    deliveryLat: latitude + 0.005,
    deliveryLng: 106.6270,
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
