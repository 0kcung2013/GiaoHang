import 'package:delivery_app/core/models/order_finance.dart';
import 'package:delivery_app/core/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderFinance', () {
    test('COD customer pays only goods and delivery', () {
      const finance = OrderFinance.calculate(
        deliveryFeePayer: DeliveryFeePayer.recipient,
        goodsValue: 120000,
        codCollectionAmount: 120000,
        deliveryFee: 25000,
      );

      expect(finance.driverNetEarning, 25000);
      expect(finance.driverAdvanceAmount, 120000);
      expect(finance.receiverCollectionAmount, 145000);
      expect(finance.totalPrice, 145000);
      expect(finance.requiredWalletBalance, 120000);
    });

    test('prepaid requires no advance or receiver collection', () {
      const finance = OrderFinance.calculate(
        deliveryFeePayer: DeliveryFeePayer.sender,
        goodsValue: 120000,
        codCollectionAmount: 0,
        deliveryFee: 25000,
      );

      expect(finance.driverAdvanceAmount, 0);
      expect(finance.receiverCollectionAmount, 0);
      expect(finance.requiredWalletBalance, 0);
      expect(finance.driverNetEarning, 25000);
      expect(finance.totalPrice, 25000);
    });

    test('total price equals goods value plus delivery fee', () {
      const finance = OrderFinance.calculate(
        deliveryFeePayer: DeliveryFeePayer.recipient,
        goodsValue: 0,
        codCollectionAmount: 0,
        deliveryFee: 13003,
      );

      expect(finance.driverNetEarning, 13003);
      expect(finance.totalPrice, 13003);
    });
  });

  test('OrderModel parses finance fields and safe legacy defaults', () {
    final current = OrderModel.fromJson({
      'id': 'order-1',
      'customer_id': 'customer-1',
      'status': 'pending',
      'pickup_address': 'A',
      'pickup_lat': 10,
      'pickup_lng': 106,
      'delivery_address': 'B',
      'delivery_lat': 11,
      'delivery_lng': 107,
      'created_at': '2026-08-14T00:00:00Z',
      'tracking_code': '1001',
      'delivery_fee': 25000,
      'service_type': 'standard',
      'payment_method': 'cash',
      'payment_mode': 'prepaid',
      'goods_value': 120000,
      'platform_fee_rate_bps': 0,
      'platform_fee_amount': 0,
      'driver_net_earning': 25000,
      'driver_advance_amount': 0,
      'receiver_collection_amount': 0,
      'updated_at': '2026-08-14T00:00:00Z',
    });
    final legacy = OrderModel.fromJson({
      'id': 'old',
      'customer_id': 'customer-1',
      'status': 'pending',
      'pickup_address': 'A',
      'pickup_lat': 10,
      'pickup_lng': 106,
      'delivery_address': 'B',
      'delivery_lat': 11,
      'delivery_lng': 107,
      'created_at': '2026-08-14T00:00:00Z',
      'tracking_code': '1000',
      'delivery_fee': 18000,
      'service_type': 'standard',
      'payment_method': 'cash',
      'updated_at': '2026-08-14T00:00:00Z',
    });

    expect(current.paymentMode, OrderPaymentMode.prepaid);
    expect(current.goodsValue, 120000);
    expect(current.driverNetEarning, 25000);
    expect(legacy.paymentMode, OrderPaymentMode.cod);
    expect(legacy.goodsValue, 0);
  });
}
