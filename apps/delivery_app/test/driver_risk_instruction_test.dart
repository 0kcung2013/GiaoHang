import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/customer/screens/tracking/utils/tracking_map_phase.dart';
import 'package:delivery_app/features/driver/screens/home/utils/driver_home_formatters.dart';
import 'package:delivery_app/features/risk_reports/widgets/driver_risk_instruction_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('return instruction blocks delivery until custody confirmation', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverRiskInstructionCard(
            intervention: _intervention(RiskInterventionState.returnRequired),
            onConfirmCustody: () async => confirmed = true,
          ),
        ),
      ),
    );

    expect(find.text('CSKH yêu cầu hoàn trả hàng'), findsOneWidget);
    expect(find.text('Hoàn hàng tại kho trung tâm.'), findsOneWidget);
    await tester.tap(find.text('Đã hoàn tất hoàn trả'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('released intervention hides blocking instruction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DriverRiskInstructionCard(
          intervention: _intervention(RiskInterventionState.released),
          onConfirmCustody: () async {},
        ),
      ),
    );
    expect(find.textContaining('CSKH yêu cầu'), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  test('risk_hold is explicit across order, tracking and driver labels', () {
    final order = OrderModel.fromJson({
      'id': 'order-1',
      'customer_id': 'customer-1',
      'status': 'risk_hold',
    });
    expect(order.isRiskHeld, isTrue);
    expect(statusLabel('risk_hold'), 'Tạm giữ xử lý sự cố');
    expect(TrackingMapPhase.fromStatus('risk_hold'), TrackingMapPhase.toPickup);
  });
}

RiskIntervention _intervention(RiskInterventionState state) => RiskIntervention(
  riskReportId: 'risk-1',
  orderId: 'order-1',
  state: state,
  driverId: 'driver-1',
  decisionDueAt: DateTime(2026),
  instruction: 'Hoàn hàng tại kho trung tâm.',
  driverReleasedAt: state == RiskInterventionState.released
      ? DateTime(2026)
      : null,
);
