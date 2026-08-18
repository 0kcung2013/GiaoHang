import 'package:delivery_app/core/models/order_finance.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/services/customer_order_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates VNPAY session from an immutable order snapshot', () async {
    final calls = <({String name, Map<String, dynamic> body})>[];
    final service = CustomerOrderPaymentService(
      functionInvoker: (name, body) async {
        calls.add((name: name, body: body));
        return {
          'session_id': 'session-1',
          'txn_ref': 'O-demo',
          'amount': 25000,
          'status': 'pending',
          'expires_at': '2026-08-15T00:15:00Z',
          'payment_url': 'https://sandbox.vnpayment.vn/payment',
        };
      },
      rpcInvoker: (_, _) async => const <String, dynamic>{},
    );

    final session = await service.createPaymentSession(_order());

    expect(calls.single.name, 'vnpay-create-order-payment');
    expect(calls.single.body['delivery_fee'], 25000.0);
    expect(calls.single.body['delivery_fee_payer'], 'sender');
    expect(calls.single.body['cod_collection_amount'], 120000);
    expect(session.amount, 25000);
    expect(session.paymentUrl!.host, 'sandbox.vnpayment.vn');
  });

  test('reads IPN-confirmed session status through RPC', () async {
    final service = CustomerOrderPaymentService(
      functionInvoker: (_, _) async => const <String, dynamic>{},
      rpcInvoker: (name, params) async {
        expect(name, 'get_customer_order_payment_session');
        expect(params, {'p_session_id': 'session-1'});
        return [
          {
            'session_id': 'session-1',
            'txn_ref': 'O-demo',
            'amount': 25000,
            'status': 'paid',
            'order_id': 'order-1',
            'tracking_code': 'GH-10001',
            'expires_at': '2026-08-15T00:15:00Z',
          },
        ];
      },
    );

    final session = await service.getPaymentSession('session-1');

    expect(session.status, OrderPaymentStatus.paid);
    expect(session.orderId, 'order-1');
    expect(session.trackingCode, 'GH-10001');
  });
}

OrderModel _order() => OrderModel(
  id: '',
  customerId: 'customer-1',
  status: 'pending',
  pickupAddress: 'Điểm lấy',
  pickupLat: 10.1,
  pickupLng: 106.1,
  deliveryAddress: 'Điểm giao',
  deliveryLat: 10.2,
  deliveryLng: 106.2,
  totalPrice: 145000,
  createdAt: DateTime.utc(2026, 8, 15),
  trackingCode: '',
  recipientName: 'Nguyễn Văn A',
  recipientPhone: '0900000000',
  itemName: 'Hồ sơ',
  itemCategory: 'document',
  deliveryFee: 25000,
  serviceType: 'standard',
  paymentMethod: 'vnpay',
  paymentMode: OrderPaymentMode.prepaid,
  deliveryFeePayer: DeliveryFeePayer.sender,
  paymentStatus: OrderPaymentStatus.pending,
  goodsValue: 800000,
  codCollectionAmount: 120000,
  driverNetEarning: 25000,
  driverAdvanceAmount: 120000,
  receiverCollectionAmount: 120000,
  updatedAt: DateTime.utc(2026, 8, 15),
);
