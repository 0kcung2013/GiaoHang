import 'package:delivery_app/core/models/order_finance.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('COD advance order payment', () {
    test('receiver pays COD plus delivery while driver advances COD', () {
      const codAmount = 350000;
      const deliveryFee = 24000;

      const finance = OrderFinance.calculate(
        deliveryFeePayer: DeliveryFeePayer.recipient,
        goodsValue: 0,
        codCollectionAmount: codAmount,
        deliveryFee: deliveryFee,
      );

      expect(finance.senderVnpayAmount, 0);
      expect(finance.receiverCollectionAmount, codAmount + deliveryFee);
      expect(finance.driverAdvanceAmount, codAmount);
      expect(finance.requiredWalletBalance, codAmount);
      expect(finance.paymentMode, OrderPaymentMode.cod);
      expect(finance.totalPrice, codAmount + deliveryFee);
    });
  });

  test('OrderModel parses payer, payment status and COD fields', () {
    final order = OrderModel.fromJson({
      'id': 'order-1',
      'customer_id': 'customer-1',
      'status': 'pending',
      'pickup_address': 'A',
      'pickup_lat': 10,
      'pickup_lng': 106,
      'delivery_address': 'B',
      'delivery_lat': 11,
      'delivery_lng': 107,
      'created_at': '2026-08-15T00:00:00Z',
      'tracking_code': '1001',
      'delivery_fee': 25000,
      'service_type': 'standard',
      'payment_method': 'cash',
      'payment_mode': 'cod',
      'delivery_fee_payer': 'recipient',
      'payment_status': 'not_required',
      'goods_value': 0,
      'cod_collection_amount': 120000,
      'driver_net_earning': 25000,
      'driver_advance_amount': 120000,
      'receiver_collection_amount': 145000,
      'updated_at': '2026-08-15T00:01:00Z',
    });

    expect(order.deliveryFeePayer, DeliveryFeePayer.recipient);
    expect(order.paymentStatus, OrderPaymentStatus.notRequired);
    expect(order.codCollectionAmount, 120000);
    expect(order.receiverCollectionAmount, 145000);
  });
}
