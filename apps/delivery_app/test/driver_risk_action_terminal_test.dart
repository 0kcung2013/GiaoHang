import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_risk_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides driver risk reporting after delivery succeeded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverRiskAction(order: _order('delivered'))),
      ),
    );

    expect(find.text('Báo cáo sự cố'), findsNothing);
  });

  testWidgets('keeps driver risk reporting while delivery is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DriverRiskAction(order: _order('delivering'))),
      ),
    );

    expect(find.text('Báo cáo sự cố'), findsOneWidget);
  });
}

OrderModel _order(String status) => OrderModel.fromJson({
  'id': 'order-1',
  'customer_id': 'customer-1',
  'driver_id': 'driver-1',
  'status': status,
});
