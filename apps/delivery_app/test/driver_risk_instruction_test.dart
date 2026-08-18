import 'dart:async';

import 'package:delivery_app/core/models/order_model.dart';
import 'package:delivery_app/features/customer/screens/tracking/utils/tracking_map_phase.dart';
import 'package:delivery_app/features/driver/screens/home/utils/driver_home_formatters.dart';
import 'package:delivery_app/features/risk_reports/widgets/driver_risk_instruction_card.dart';
import 'package:delivery_app/features/risk_reports/data/risk_intervention_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  testWidgets('return instruction cannot use legacy custody confirmation', (
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
    expect(find.text('Đã hoàn tất hoàn trả'), findsNothing);
    expect(find.byKey(const Key('confirm-driver-custody')), findsNothing);
    expect(confirmed, isFalse);
  });

  testWidgets('released intervention blocks stale delivery controls', (
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
    expect(
      riskInterventionBlocksDelivery(
        _intervention(RiskInterventionState.released),
      ),
      isTrue,
    );
    expect(find.textContaining('CSKH yêu cầu'), findsNothing);
    expect(find.text('Chuyến giao đã kết thúc với bạn'), findsOneWidget);
  });

  test('pre-pickup hold blocks stale navigation actions', () {
    expect(
      riskInterventionBlocksDelivery(
        _intervention(RiskInterventionState.heldBeforePickup),
      ),
      isTrue,
    );
  });

  test('blocking intervention wins when an order has multiple reports', () {
    final selected = selectCurrentRiskInterventionForDriver([
      _intervention(RiskInterventionState.awaitingTriage),
      _intervention(RiskInterventionState.heldBeforePickup),
    ]);
    expect(selected?.state, RiskInterventionState.heldBeforePickup);

    final released = selectCurrentRiskInterventionForDriver([
      _intervention(RiskInterventionState.awaitingTriage),
      _intervention(RiskInterventionState.released),
    ]);
    expect(released?.state, RiskInterventionState.released);
  });

  testWidgets('driver actions stay available while realtime state is loading', (
    tester,
  ) async {
    final repository = _FakeInterventionRepository();
    addTearDown(repository.dispose);
    bool? blocked;

    await tester.pumpWidget(
      MaterialApp(
        home: DriverRiskInstructionRegion(
          orderId: 'order-1',
          repository: repository,
          builder: (_, value) {
            blocked = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(blocked, isFalse);
    expect(find.textContaining('Đang đồng bộ chỉ dẫn'), findsNothing);

    repository.emit(null);
    await tester.pump();
    expect(blocked, isFalse);
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

class _FakeInterventionRepository implements RiskInterventionRepository {
  final _controller = StreamController<RiskIntervention?>();

  void emit(RiskIntervention? intervention) => _controller.add(intervention);
  Future<void> dispose() => _controller.close();

  @override
  Future<void> confirmCustodyResolved(String reportId, {String? note}) async {}

  @override
  Future<RiskIntervention?> fetchForOrder(String orderId) async => null;

  @override
  Stream<RiskIntervention?> watchForOrder(String orderId) => _controller.stream;
}
