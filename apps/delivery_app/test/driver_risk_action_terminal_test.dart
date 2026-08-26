import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/driver/screens/navigation/widgets/driver_risk_action.dart';
import 'package:delivery_app/features/risk_reports/widgets/risk_report_entry_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_design/giaohang_design.dart';

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

  testWidgets('dark map action uses an opaque high-contrast surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RiskReportEntryAction(dark: true, onPressed: () {}),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('risk-report-entry-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.bgDarkCard);
    expect(decoration.boxShadow, AppShadow.elevated);
  });
}

OrderModel _order(String status) => OrderModel.fromJson({
  'id': 'order-1',
  'customer_id': 'customer-1',
  'driver_id': 'driver-1',
  'status': status,
});
