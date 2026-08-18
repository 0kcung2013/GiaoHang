import 'package:delivery_app/core/services/free_pick_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads only the current map viewport', () async {
    String? functionName;
    Map<String, dynamic>? sentParams;
    final service = FreePickService.test(
      invokeRpc: (name, params) async {
        functionName = name;
        sentParams = params;
        return const [];
      },
    );

    final orders = await service.getOrdersInViewport(
      const FreePickViewport(south: 10, west: 106, north: 11, east: 107),
    );

    expect(orders, isEmpty);
    expect(functionName, 'get_free_pick_orders_in_view');
    expect(sentParams, {
      'p_south': 10.0,
      'p_west': 106.0,
      'p_north': 11.0,
      'p_east': 107.0,
      'p_limit': 50,
    });
  });

  test('claims through the atomic FreePick command', () async {
    String? functionName;
    Map<String, dynamic>? sentParams;
    final service = FreePickService.test(
      invokeRpc: (name, params) async {
        functionName = name;
        sentParams = params;
        return const [
          {
            'order_id': 'order-1',
            'customer_id': 'customer-1',
            'tracking_code': 'GH-1001',
          },
        ];
      },
    );

    final result = await service.claimOrder('order-1');

    expect(functionName, 'claim_free_pick_order');
    expect(sentParams, {'p_order_id': 'order-1'});
    expect(result.orderId, 'order-1');
    expect(result.customerId, 'customer-1');
  });
}
