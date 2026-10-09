import 'dart:async';

import 'package:delivery_app/core/models/order_finance.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/services/customer_order_payment_service.dart';
import 'package:delivery_app/features/customer/screens/create_order/controllers/order_confirmation_payment_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'opening payment never marks an order paid; backend confirmation does',
    () async {
      var paid = false;
      var finishes = 0;
      var opens = 0;
      final controller = OrderConfirmationPaymentController(
        service: CustomerOrderPaymentService(
          functionInvoker: (_, payload) async {
            expect(payload['delivery_fee_payer'], 'sender');
            expect(payload['cod_collection_amount'], 0);
            return _session();
          },
          rpcInvoker: (_, _) async =>
              _session(status: paid ? 'paid' : 'pending'),
        ),
        openPayment: (_) async {
          opens++;
          return true;
        },
        onPaid: (session, order) async {
          finishes++;
          expect(session.orderId, 'order-1');
          expect(order.receiverCollectionAmount, 0);
        },
      );
      addTearDown(controller.dispose);

      await controller.submit(_order());
      expect(opens, 1);
      expect(finishes, 0);
      await controller.refresh();
      expect(finishes, 0);
      paid = true;
      await controller.refresh();
      await controller.refresh();
      expect(finishes, 1);
    },
  );

  test(
    'reopening pending payment reuses the original order and session',
    () async {
      var creates = 0;
      var opens = 0;
      final original = _order();
      final controller = OrderConfirmationPaymentController(
        service: CustomerOrderPaymentService(
          functionInvoker: (_, _) async {
            creates++;
            return _session();
          },
          rpcInvoker: (_, _) async => {..._session(), 'payment_url': null},
        ),
        openPayment: (_) async {
          opens++;
          return true;
        },
        onPaid: (_, _) async => fail('Payment is not confirmed'),
      );
      addTearDown(controller.dispose);

      await controller.submit(original);
      await controller.submit(original.copyWith(deliveryFee: 99999));
      expect(creates, 1);
      expect(opens, 2);
      expect(controller.orderSnapshot, same(original));
    },
  );

  test(
    'failed URL launch allows retry without a second payment session',
    () async {
      var creates = 0;
      var canOpen = false;
      final controller = OrderConfirmationPaymentController(
        service: CustomerOrderPaymentService(
          functionInvoker: (_, _) async {
            creates++;
            return _session();
          },
          rpcInvoker: (_, _) async => _session(),
        ),
        openPayment: (_) async => canOpen,
        onPaid: (_, _) async => fail('Payment is not confirmed'),
      );
      addTearDown(controller.dispose);

      await controller.submit(_order());
      expect(controller.error, isNotNull);
      canOpen = true;
      await controller.submit(_order());
      expect(creates, 1);
      expect(controller.error, isNull);
    },
  );

  test(
    'an expired session can be replaced after server verification',
    () async {
      var creates = 0;
      final controller = OrderConfirmationPaymentController(
        service: CustomerOrderPaymentService(
          functionInvoker: (_, _) async {
            creates++;
            return _session(id: 'session-$creates');
          },
          rpcInvoker: (_, _) async => _session(status: 'expired'),
        ),
        openPayment: (_) async => true,
        onPaid: (_, _) async => fail('Payment is not confirmed'),
      );
      addTearDown(controller.dispose);

      await controller.submit(_order());
      await controller.submit(_order());
      expect(creates, 2);
      expect(controller.session!.sessionId, 'session-2');
      expect(controller.error, isNull);
    },
  );

  test(
    'paid without an order ID never creates another payment session',
    () async {
      var creates = 0;
      final controller = OrderConfirmationPaymentController(
        service: CustomerOrderPaymentService(
          functionInvoker: (_, _) async {
            creates++;
            return _session();
          },
          rpcInvoker: (_, _) async => {
            ..._session(status: 'paid'),
            'order_id': null,
          },
        ),
        openPayment: (_) async => true,
        onPaid: (_, _) async => fail('Missing backend order confirmation'),
      );
      addTearDown(controller.dispose);

      await controller.submit(_order());
      await controller.submit(_order());
      expect(creates, 1);
      expect(controller.error, isNotNull);
    },
  );

  test('overlapping submits create only one payment session', () async {
    final response = Completer<Map<String, dynamic>>();
    var creates = 0;
    final controller = OrderConfirmationPaymentController(
      service: CustomerOrderPaymentService(
        functionInvoker: (_, _) {
          creates++;
          return response.future;
        },
        rpcInvoker: (_, _) async => _session(),
      ),
      openPayment: (_) async => true,
      onPaid: (_, _) async => fail('Payment is not confirmed'),
    );
    addTearDown(controller.dispose);

    final first = controller.submit(_order());
    await controller.submit(_order());
    response.complete(_session());
    await first;
    expect(creates, 1);
  });

  test(
    'disposing during session creation does not open a payment page',
    () async {
      final response = Completer<Map<String, dynamic>>();
      var opens = 0;
      final controller = OrderConfirmationPaymentController(
        service: CustomerOrderPaymentService(
          functionInvoker: (_, _) => response.future,
          rpcInvoker: (_, _) async => _session(),
        ),
        openPayment: (_) async {
          opens++;
          return true;
        },
        onPaid: (_, _) async => fail('Disposed controller'),
      );

      final pending = controller.submit(_order());
      controller.dispose();
      response.complete(_session());
      await pending;
      expect(opens, 0);
    },
  );
}

Map<String, dynamic> _session({
  String id = 'session-1',
  String status = 'pending',
}) => {
  'session_id': id,
  'txn_ref': 'O-demo',
  'amount': 25000,
  'status': status,
  'expires_at': DateTime.now()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
  'payment_url': 'https://payment.example.test/pay',
  if (status == 'paid') 'order_id': 'order-1',
  if (status == 'paid') 'tracking_code': 'GH-10001',
};

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
  createdAt: DateTime(2026, 10, 8),
  trackingCode: '',
  deliveryFee: 25000,
  paymentMethod: 'vnpay',
  serviceType: 'standard',
  deliveryFeePayer: DeliveryFeePayer.sender,
  paymentMode: OrderPaymentMode.prepaid,
  paymentStatus: OrderPaymentStatus.pending,
  codCollectionAmount: 0,
  receiverCollectionAmount: 0,
  driverNetEarning: 25000,
  updatedAt: DateTime(2026, 10, 8),
);
