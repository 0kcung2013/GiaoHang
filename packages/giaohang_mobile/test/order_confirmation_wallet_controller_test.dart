import 'dart:async';

import 'package:giaohang_mobile/core/models/order_finance.dart';
import 'package:giaohang_mobile/core/models/order_model.dart';
import 'package:giaohang_mobile/core/services/customer_order_payment_service.dart';
import 'package:giaohang_mobile/features/customer/screens/create_order/controllers/order_confirmation_wallet_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('lost response retries the same request and immutable order', () async {
    final calls = <Map<String, dynamic>>[];
    var finishes = 0;
    final controller = _controller((name, params) async {
      expect(name, 'create_customer_order_with_wallet');
      calls.add(params);
      if (calls.length == 1) throw Exception('Lost response');
      return _createdJson();
    }, (_) async => finishes++);
    addTearDown(controller.dispose);
    await controller.submit(_order());
    expect(controller.canSwitchPayment, isFalse);
    await controller.submit(_order().copyWith(deliveryFee: 99999));
    await controller.submit(_order());
    expect(calls, hasLength(2));
    expect(calls[0], calls[1]);
    expect(calls[0]['p_request_id'], 'request-1');
    expect((calls[0]['p_order_payload'] as Map)['delivery_fee'], 18000);
    expect(finishes, 1);
  });

  test('completion retry does not debit again', () async {
    var debits = 0;
    var finishes = 0;
    final controller = _controller(
      (_, _) async {
        debits++;
        return _createdJson();
      },
      (_) async {
        finishes++;
        if (finishes == 1) throw Exception('Recent address failed');
      },
    );
    addTearDown(controller.dispose);
    await controller.submit(_order());
    expect(controller.canSwitchPayment, isFalse);
    await controller.submit(_order());
    expect(debits, 1);
    expect(finishes, 2);
  });

  test('double tap has only one debit in flight', () async {
    final pending = Completer<Map<String, dynamic>>();
    var debits = 0;
    final controller = _controller((_, _) {
      debits++;
      return pending.future;
    }, (_) async {});
    addTearDown(controller.dispose);
    final first = controller.submit(_order());
    await controller.submit(_order());
    expect(controller.isBusy, isTrue);
    expect(debits, 1);
    pending.complete(_createdJson());
    await first;
  });

  test(
    'only confirmed insufficient balance permits switching to VNPAY',
    () async {
      final controller = _controller((_, _) async {
        throw const PostgrestException(
          message: 'CUSTOMER_WALLET_INSUFFICIENT_BALANCE',
        );
      }, (_) async => fail('An unpaid order cannot complete'));
      addTearDown(controller.dispose);
      await controller.submit(_order());
      expect(controller.canSwitchPayment, isTrue);
      expect(controller.error, contains('Ví không đủ tiền'));
    },
  );

  test(
    'disposing during payment does not finish or notify a closed screen',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      final controller = _controller(
        (_, _) => pending.future,
        (_) async => fail('Disposed screen must not complete'),
      );
      final first = controller.submit(_order());
      controller.dispose();
      pending.complete(_createdJson());
      await first;
    },
  );

  test('COD orders cannot invoke the wallet debit RPC', () async {
    final service = CustomerOrderPaymentService(
      functionInvoker: (_, _) async => fail('Wallet must not open VNPAY'),
      rpcInvoker: (_, _) async => fail('COD must not debit wallet'),
    );
    await expectLater(
      service.createWalletOrder(
        _order().copyWith(codCollectionAmount: 50000),
        requestId: 'request-1',
      ),
      throwsA(isA<CustomerWalletOrderPaymentException>()),
    );
  });
}

OrderConfirmationWalletController _controller(
  CustomerOrderPaymentRpcInvoker invoke,
  Future<void> Function(OrderModel) complete,
) => OrderConfirmationWalletController(
  service: CustomerOrderPaymentService(
    rpcInvoker: invoke,
    functionInvoker: (_, _) async => fail('Wallet must not open VNPAY'),
  ),
  onCreated: complete,
  requestId: 'request-1',
);

Map<String, dynamic> _createdJson() => {
  ..._order().toJson(),
  'id': 'order-1',
  'tracking_code': 'GH-10001',
  'payment_status': 'paid',
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
  totalPrice: 18000,
  deliveryFee: 18000,
  createdAt: DateTime.utc(2026, 10, 12),
  trackingCode: '',
  paymentMethod: 'wallet',
  serviceType: 'standard',
  paymentMode: OrderPaymentMode.prepaid,
  paymentStatus: OrderPaymentStatus.pending,
  deliveryFeePayer: DeliveryFeePayer.sender,
  goodsValue: 50000,
  codCollectionAmount: 0,
  driverAdvanceAmount: 50000,
  driverNetEarning: 18000,
  receiverCollectionAmount: 0,
  updatedAt: DateTime.utc(2026, 10, 12),
);
