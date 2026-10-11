import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/core/models/order_finance.dart';
import 'package:delivery_app/core/models/order_submission_payload.dart';
import 'package:delivery_app/core/services/customer_order_command_service.dart';
import 'package:delivery_app/features/customer/screens/create_order/utils/order_form_validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test('accepts kg with Vietnamese decimals and rejects invalid weights', () {
    for (final input in ['0,5', '2.75', ',5', '0.001', '12']) {
      expect(validateOrderWeight(input), isNull, reason: input);
    }
    expect(validateOrderWeight(''), OrderFormValidationText.weightRequired);
    for (final input in [
      '0',
      '-1',
      'NaN',
      'Infinity',
      'abc',
      '2 kg',
      '1,2345',
      '1e2',
      '1,2.3',
    ]) {
      expect(
        validateOrderWeight(input),
        OrderFormValidationText.weightInvalid,
        reason: input,
      );
    }
    expect(formatCargoWeightKg(parseCargoWeightKg('2.750')), '2,75 kg');
    expect(formatCargoWeightKg(10), '10 kg');
    expect(formatCargoWeightKg(null), 'Chưa khai báo');
  });

  test(
    'declared weight survives model updates and both payment payloads',
    () async {
      final order = OrderModel.fromJson({
        'id': 'order',
        'customer_id': 'customer',
        'status': 'pending',
        'item_weight_kg': '2.750',
        'delivery_fee': 30000,
      });
      final updated = order.copyWith(status: 'picking_up');
      expect(updated.itemWeightKg, 2.75);
      expect(OrderModel.fromJson(updated.toJson()).itemWeightKg, 2.75);
      expect(buildOrderSubmissionPayload(updated)['item_weight_kg'], 2.75);
      expect(
        buildOrderSubmissionPayload(
          updated.copyWith(deliveryFeePayer: DeliveryFeePayer.sender),
        )['item_weight_kg'],
        2.75,
      );

      Map<String, dynamic>? sent;
      final service = CustomerOrderCommandService(
        rpcInvoker: (_, params) async {
          sent = params['p_order_payload'] as Map<String, dynamic>;
          return [
            {'order_id': 'order', 'tracking_code': 'GH-WEIGHT'},
          ];
        },
      );
      await service.createOrder(order);
      expect(sent?['item_weight_kg'], 2.75);
      final legacy = OrderModel.fromJson({
        'id': 'legacy',
        'status': 'delivering',
      });
      expect(legacy.itemWeightKg, isNull);
      expect(
        buildOrderSubmissionPayload(legacy),
        isNot(contains('item_weight_kg')),
      );
    },
  );
}
