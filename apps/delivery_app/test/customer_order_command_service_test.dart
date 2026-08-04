import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/services/customer_order_command_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerOrderCommandService', () {
    test('creates an order through one atomic RPC command', () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final service = CustomerOrderCommandService(
        rpcInvoker: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return [
            {'order_id': 'order-1', 'tracking_code': '10001'},
          ];
        },
      );

      final result = await service.createOrder(_order());

      expect(result.orderId, 'order-1');
      expect(result.trackingCode, '10001');
      expect(calls, hasLength(1));
      expect(calls.single.functionName, 'create_customer_order');
      expect(calls.single.params, {
        'p_pickup_address': 'Điểm lấy',
        'p_pickup_lat': 10.1,
        'p_pickup_lng': 106.1,
        'p_delivery_address': 'Điểm giao',
        'p_delivery_lat': 10.2,
        'p_delivery_lng': 106.2,
        'p_total_price': 20000.0,
        'p_note': 'Gọi trước',
        'p_estimated_pickup_at': '2026-07-30T09:00:00.000Z',
        'p_estimated_delivery_at': '2026-07-30T10:00:00.000Z',
        'p_recipient_name': 'Nguyễn Văn A',
        'p_recipient_phone': '0900000000',
        'p_delivery_fee': 18000.0,
        'p_service_type': 'express',
        'p_payment_method': 'cash',
        'p_item_name': 'Hồ sơ',
        'p_item_category': 'document',
        'p_item_description': 'Không gấp',
        'p_item_image_url': 'https://example.com/item.jpg',
        'p_item_quantity': 1,
        'p_item_price': 18000.0,
      });
      expect(calls.single.params, isNot(contains('p_customer_id')));
    });

    test('cancels an order through one atomic RPC command', () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final service = CustomerOrderCommandService(
        rpcInvoker: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return [
            {
              'order_id': 'order-1',
              'driver_id': 'driver-1',
              'tracking_code': '10001',
              'new_status': 'cancelled',
            },
          ];
        },
      );

      final result = await service.cancelOrder(
        orderId: 'order-1',
        customerId: 'customer-1',
        statusNote: 'Đổi kế hoạch',
      );

      expect(result.orderId, 'order-1');
      expect(result.driverId, 'driver-1');
      expect(result.trackingCode, '10001');
      expect(result.status, 'cancelled');
      expect(calls, hasLength(1));
      expect(calls.single.functionName, 'cancel_customer_order');
      expect(calls.single.params, {
        'p_order_id': 'order-1',
        'p_customer_id': 'customer-1',
        'p_status_note': 'Đổi kế hoạch',
      });
    });

    test('rejects an empty RPC result instead of reporting success', () async {
      final service = CustomerOrderCommandService(
        rpcInvoker: (_, _) async => <dynamic>[],
      );

      await expectLater(
        service.createOrder(_order()),
        throwsA(isA<CustomerOrderCommandException>()),
      );
    });
  });
}

OrderModel _order() {
  return OrderModel(
    id: '',
    customerId: 'customer-1',
    status: 'pending',
    pickupAddress: 'Điểm lấy',
    pickupLat: 10.1,
    pickupLng: 106.1,
    deliveryAddress: 'Điểm giao',
    deliveryLat: 10.2,
    deliveryLng: 106.2,
    totalPrice: 20000,
    note: 'Gọi trước',
    createdAt: DateTime.utc(2026, 7, 30, 8),
    trackingCode: '',
    estimatedPickupAt: DateTime.utc(2026, 7, 30, 9),
    estimatedDeliveryAt: DateTime.utc(2026, 7, 30, 10),
    recipientName: 'Nguyễn Văn A',
    recipientPhone: '0900000000',
    itemName: 'Hồ sơ',
    itemCategory: 'document',
    itemDescription: 'Không gấp',
    itemImageUrl: 'https://example.com/item.jpg',
    deliveryFee: 18000,
    serviceType: 'express',
    paymentMethod: 'cash',
    updatedAt: DateTime.utc(2026, 7, 30, 8),
  );
}
