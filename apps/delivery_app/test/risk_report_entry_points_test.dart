import 'dart:io';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/customer/screens/order/dialogs/widgets/order_risk_report_section.dart';
import 'package:delivery_app/features/order_help/data/customer_support_ticket_repository.dart';
import 'package:delivery_app/features/order_help/order_help_strings.dart';
import 'package:delivery_app/features/risk_reports/data/participant_risk_report_query_repository.dart';
import 'package:delivery_app/features/risk_reports/models/participant_risk_report_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

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

  testWidgets('customer gets labeled help actions in detail and tracking', (
    tester,
  ) async {
    expect(customerSection.existsSync(), isTrue);
    expect(orderDetail, contains('OrderRiskReportSection('));
    expect(tracking, contains('CustomerTrackingRiskAction(order: order)'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderRiskReportSection(
            order: _customerOrder,
            supportRepository: _EmptySupportRepository(),
            riskRepository: _EmptyRiskRepository(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(OrderHelpStrings.entryLabel), findsOneWidget);
    expect(find.byKey(const Key('open-order-help')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

class _EmptySupportRepository implements CustomerSupportTicketRepository {
  const _EmptySupportRepository();

  @override
  Future<SupportTicket> create(SupportTicketDraft draft) =>
      throw UnsupportedError('Not used by this test.');

  @override
  Future<List<SupportTicket>> fetchForOrder(String orderId) async => const [];

  @override
  Stream<List<SupportTicket>> watchForOrder(String orderId) =>
      const Stream.empty();
}

class _EmptyRiskRepository implements ParticipantRiskReportQueryRepository {
  const _EmptyRiskRepository();

  @override
  Future<List<ParticipantRiskReportSummary>> fetchForOrder(
    String orderId,
  ) async => const [];

  @override
  Stream<List<ParticipantRiskReportSummary>> watchForOrder(String orderId) =>
      const Stream.empty();

  @override
  Future<ParticipantRiskReportSummary?> findActive(
    String orderId,
    RiskCategory category,
  ) async => null;

  @override
  Future<List<RiskReportEvent>> fetchEvents(String reportId) async => const [];
}

final _customerOrder = OrderModel(
  id: 'order-risk-entry',
  customerId: 'customer-1',
  status: 'delivering',
  pickupAddress: 'Điểm lấy hàng',
  pickupLat: 10.7,
  pickupLng: 106.6,
  deliveryAddress: 'Điểm giao hàng',
  deliveryLat: 10.8,
  deliveryLng: 106.7,
  createdAt: DateTime(2026),
  trackingCode: 'GH-RISK-ENTRY',
  deliveryFee: 30000,
  serviceType: 'standard',
  paymentMethod: 'cash',
  updatedAt: DateTime(2026),
);
