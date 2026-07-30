import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:customer_app/core/models/order_model.dart';
import 'package:customer_app/core/services/nearest_driver_service.dart';

void main() {
  test('distributes two pending orders to two different drivers', () async {
    final client = SupabaseClient('http://localhost:54321', 'test-anon-key');
    addTearDown(client.dispose);
    final service = NearestDriverService(
      client: client,
      assignableDriverLoader:
          ({required double nearLat, required double nearLng}) async {
            return const [
              AssignableDriverPoint(
                userId: 'driver-1',
                lat: 10.0,
                lng: 106.0,
                distanceMeters: 100,
              ),
              AssignableDriverPoint(
                userId: 'driver-2',
                lat: 10.01,
                lng: 106.01,
                distanceMeters: 200,
              ),
            ];
          },
    );
    final firstOrder = _order(
      id: 'order-1',
      createdAt: DateTime.utc(2026, 7, 29, 8),
    );
    final secondOrder = _order(
      id: 'order-2',
      createdAt: DateTime.utc(2026, 7, 29, 8, 1),
    );
    final newestFirst = [secondOrder, firstOrder];

    final driverOneOrders = await service.filterOrdersForNearestDriver(
      newestFirst,
      'driver-1',
    );
    final driverTwoOrders = await service.filterOrdersForNearestDriver(
      newestFirst,
      'driver-2',
    );

    expect(driverOneOrders.map((order) => order.id), ['order-1']);
    expect(driverTwoOrders.map((order) => order.id), ['order-2']);
  });
}

OrderModel _order({required String id, required DateTime createdAt}) {
  return OrderModel(
    id: id,
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.0,
    pickupLng: 106.0,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.02,
    deliveryLng: 106.02,
    createdAt: createdAt,
    trackingCode: id,
    deliveryFee: 30000,
    serviceType: 'standard',
    paymentMethod: 'cash',
    updatedAt: createdAt,
  );
}
