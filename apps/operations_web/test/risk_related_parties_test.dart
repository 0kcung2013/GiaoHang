import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operations_web/features/risk_reports/models/risk_report.dart';
import 'package:operations_web/features/risk_reports/widgets/risk_related_parties.dart';

RiskReport report(Map<String, dynamic> order) => RiskReport.fromJson({
  'id': 'report-1',
  'order_id': 'order-1',
  'reported_by': 'driver-1',
  'created_at': '2026-09-16T01:00:00Z',
  'updated_at': '2026-09-16T01:00:00Z',
  'reporter': {'full_name': 'Tài xế Bình', 'phone': '0901111111'},
  'orders': order,
});

void main() {
  test('order contacts survive report serialization', () {
    final original = report({
      'customer_id': 'customer-1',
      'driver_id': 'driver-1',
      'customer': {'full_name': 'Khách An', 'phone': '0902222222'},
      'driver': {'full_name': 'Tài xế Bình', 'phone': '0901111111'},
      'recipient_name': 'Người nhận Chi',
      'recipient_phone': '0903333333',
    });
    final restored = RiskReport.fromJson(original.toJson());
    expect(restored.order.customer?.name, 'Khách An');
    expect(restored.order.driver?.phone, '0901111111');
    expect(restored.order.recipientName, 'Người nhận Chi');
    expect(restored.order.recipientPhone, '0903333333');
  });

  testWidgets('separates customer driver and recipient at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: SingleChildScrollView(
              child: RiskRelatedParties(
                report: report({
                  'customer_id': 'customer-1',
                  'driver_id': 'driver-1',
                  'customer': {'full_name': 'Khách An', 'phone': '0902222222'},
                  'recipient_name': 'Người nhận Chi',
                  'recipient_phone': '0903333333',
                }),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Khách An'), findsOneWidget);
    expect(find.text('Tài xế Bình'), findsOneWidget);
    expect(find.text('Người nhận Chi'), findsOneWidget);
    expect(find.text('Người gửi báo cáo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing profiles do not identify reporter as customer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RiskRelatedParties(
              report: report({'customer_id': 'customer-1'}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Chưa phân công tài xế'), findsOneWidget);
    expect(find.text('Chưa có thông tin hồ sơ'), findsNWidgets(2));
    expect(find.text('Tài xế Bình'), findsNothing);
    expect(find.text('Người gửi báo cáo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
