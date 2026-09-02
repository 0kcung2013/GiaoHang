import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/utils/geo_utils.dart';
import 'package:delivery_app/features/driver/screens/home/utils/driver_order_distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds driver-to-pickup and pickup-to-delivery distances', () {
    final order = _order();
    final firstLeg = GeoUtils.distanceMeters(
      fromLat: 10.7790,
      fromLng: 106.6765,
      toLat: order.pickupLat,
      toLng: order.pickupLng,
    );
    final secondLeg = GeoUtils.distanceMeters(
      fromLat: order.pickupLat,
      fromLng: order.pickupLng,
      toLat: order.deliveryLat,
      toLng: order.deliveryLng,
    );

    expect(
      totalOrderDistanceMeters(
        order: order,
        driverLat: 10.7790,
        driverLng: 106.6765,
      ),
      closeTo(firstLeg + secondLeg, 0.001),
    );
  });

  test('formats the distance as the total of two legs', () {
    expect(totalOrderDistanceText(2750), 'Tổng 2 chặng · ~2.8 km');
  });

  test('formats prominent distance values in kilometers', () {
    expect(distanceKilometersText(850), '0.8 km');
    expect(distanceKilometersText(2750), '2.8 km');
    expect(distanceKilometersText(12750), '13 km');
    expect(distanceKilometersText(null), '—');
  });
}

OrderModel _order() {
  final now = DateTime(2026, 8, 19);
  return OrderModel(
    id: 'order-distance',
    customerId: 'customer-1',
    status: 'confirmed',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.773,
    pickupLng: 106.703,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.792,
    deliveryLng: 106.721,
    createdAt: now,
    trackingCode: 'GH-DISTANCE',
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: now,
  );
}
