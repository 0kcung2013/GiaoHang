import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final orderDetail = File(
    'lib/features/customer/screens/order/dialogs/order_detail_sheet.dart',
  ).readAsStringSync();
  final tracking = File(
    'lib/features/customer/screens/tracking/tracking_widgets.dart',
  ).readAsStringSync();
  final driverNavigation = File(
    'lib/features/driver/screens/navigation/widgets/driver_navigation_view.dart',
  ).readAsStringSync();
  final driverCard = File(
    'lib/features/driver/screens/home/widgets/driver_order_card.dart',
  ).readAsStringSync();
  final customerSection = File(
    'lib/features/customer/screens/order/dialogs/widgets/'
    'order_risk_report_section.dart',
  );
  final driverAction = File(
    'lib/features/driver/screens/navigation/widgets/driver_risk_action.dart',
  );

  test('customer gets labeled report actions in detail and tracking', () {
    expect(customerSection.existsSync(), isTrue);
    expect(orderDetail, contains('OrderRiskReportSection(order: order)'));
    expect(tracking, contains('CustomerTrackingRiskAction(order: order)'));
    final source = customerSection.readAsStringSync();
    expect(source, contains('RiskReporterRole.customer'));
    expect(source, contains("label: 'Báo cáo sự cố'"));
  });

  test('driver action stays separate from primary delivery progression', () {
    expect(driverAction.existsSync(), isTrue);
    expect(driverNavigation, contains('DriverRiskAction('));
    expect(driverNavigation, contains('order: order'));
    expect(driverCard, contains('DriverRiskAction(order: order)'));
    final source = driverAction.readAsStringSync();
    expect(source, contains('RiskReporterRole.driver'));
    expect(source, isNot(contains('onPrimaryAction')));
  });

  test('available unassigned orders do not expose driver reporting', () {
    expect(driverCard, contains('if (!canAccept'));
    expect(driverCard, contains('DriverRiskAction(order: order)'));
  });
}
