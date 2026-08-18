import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/models/order_finance.dart';
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
      expect(calls.single.functionName, 'create_customer_order_v2');
      expect(calls.single.params, {
        'p_order_payload': {
          'pickup_address': 'Điểm lấy',
          'pickup_lat': 10.1,
          'pickup_lng': 106.1,
          'delivery_address': 'Điểm giao',
          'delivery_lat': 10.2,
          'delivery_lng': 106.2,
          'note': 'Gọi trước',
          'estimated_pickup_at': '2026-07-30T09:00:00.000Z',
          'estimated_delivery_at': '2026-07-30T10:00:00.000Z',
          'recipient_name': 'Nguyễn Văn A',
          'recipient_phone': '0900000000',
          'delivery_fee': 18000.0,
          'service_type': 'express',
          'item_name': 'Hồ sơ',
          'item_category': 'document',
          'item_description': 'Không gấp',
          'item_image_url': 'https://example.com/item.jpg',
          'goods_value': 120000,
          'cod_collection_amount': 120000,
          'delivery_fee_payer': 'recipient',
        },
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
    paymentMode: OrderPaymentMode.cod,
    deliveryFeePayer: DeliveryFeePayer.recipient,
    paymentStatus: OrderPaymentStatus.notRequired,
    goodsValue: 120000,
    codCollectionAmount: 120000,
    platformFeeRateBps: 1500,
    platformFeeAmount: 2700,
    driverNetEarning: 15300,
    driverAdvanceAmount: 120000,
    receiverCollectionAmount: 138000,
    updatedAt: DateTime.utc(2026, 7, 30, 8),
  );
}
